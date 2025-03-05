import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';

class CsvService {
  // 追加: CSVから抽出した品種の一覧を保持する変数
  static Set<String> extractedRiceTypes = {};

  // CSVファイルを解析してJungoDataのリストに変換
  static Future<List<JungoData>> parseBrewingCsv(String csvString) async {
    try {
      // デバッグ出力
      print('CSV解析を開始します');
      
      // CSVファイルを解析
      List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter()
          .convert(csvString, eol: '\n');
      
      // データチェック
      if (rowsAsListOfValues.isEmpty) {
        print('CSVデータが空です');
        return [];
      }
      
      // ヘッダー行をデバッグ表示
      print('CSVヘッダー: ${rowsAsListOfValues[0].join(", ")}');
      
      // ヘッダー行を除く
      if (rowsAsListOfValues.length > 1) {
        rowsAsListOfValues = rowsAsListOfValues.sublist(1);
      } else {
        print('データ行がありません');
        return [];
      }
      
      List<JungoData> jungoList = [];
      
      // 各行を処理
      for (final row in rowsAsListOfValues) {
        if (row.length < 7) {
          print('行のデータが不足しています: ${row.length}列');
          continue;
        }
        
        try {
          // 基本情報の取得
          // 基本情報の取得部分を修正
          final jungoId = int.tryParse(row[0].toString()) ?? 0;  // 数値でない場合は0を使用
          final size = int.tryParse(row[1].toString()) ?? 0;
          final startDateStr = row[2].toString();
          final category = row[3].toString();
          final type = row[4].toString();
          final endDateStr = row[5].toString();
          // タンク番号を文字列として処理（これが重要）
          final tankNo = row[6].toString();  // 数値の場合も文字列の場合も対応
          
          // 日付の解析（デバッグ出力付き）
          print('日付文字列: 留日=$startDateStr, 上槽予定=$endDateStr');
          DateTime startDate = _parseStandardDate(startDateStr);
          DateTime endDate = _parseStandardDate(endDateStr);
          print('解析後日付: 留日=$startDate, 上槽予定=$endDate');
          
          // 工程データの処理
          List<BrewingProcess> processes = [];
          
          // 各工程は6列ずつでグループ化（最大9工程）
          for (int i = 0; i < 9; i++) {
            // 工程データの開始インデックス: 7 + i * 6
            int startIdx = 7 + i * 6;
            
            // データが十分にあるか確認
            if (row.length <= startIdx + 5) continue;
            
            // 工程データの取得
            int processJungoId = row[startIdx] as int? ?? jungoId;
            String processType = row[startIdx + 1] as String? ?? '';
            String processDateStr = row[startIdx + 2] as String? ?? '';
            String riceType = row[startIdx + 3] as String? ?? '';
            int ricePct = row[startIdx + 4] as int? ?? 0;
            double amount = (row[startIdx + 5] as num?)?.toDouble() ?? 0.0;
            
            // 空の工程はスキップ
            if (processType.isEmpty || processDateStr.isEmpty) continue;

            // 追加: CSVから品種情報を抽出して保存
            if (riceType.isNotEmpty) {
              extractedRiceTypes.add(riceType);
            }
            
            // 工程日付の解析
            DateTime processDate = _parseStandardDate(processDateStr);
            
            // ProcessTypeの判定
            ProcessType processCategory;
            if (processType.contains('麹')) {
              processCategory = ProcessType.koji;
            } else if (processType.contains('掛')) {
              processCategory = ProcessType.moromi;
            } else if (processType == '洗米') {
              processCategory = ProcessType.washing;
            } else if (processType == '上槽') {
              processCategory = ProcessType.pressing;
            } else if (processType == '四段') {
              processCategory = ProcessType.other;
            } else {
              // デフォルト
              processCategory = ProcessType.other;
            }
            
            // 工程のステータス決定
            DateTime now = DateTime.now();
            ProcessStatus status;
            if (now.isAfter(processDate.add(const Duration(days: 1)))) {
              status = ProcessStatus.completed;
            } else if (now.year == processDate.year && 
                      now.month == processDate.month && 
                      now.day == processDate.day) {
              status = ProcessStatus.active;
            } else {
              status = ProcessStatus.pending;
            }
            
            // 工程オブジェクトの作成
            BrewingProcess process = BrewingProcess(
              jungoId: processJungoId,
              name: processType,
              type: processCategory,
              date: processDate,
              washingDate: processDate,  // 修正: CSVの日付をそのまま洗米日として設定
              riceType: riceType,
              ricePct: ricePct,
              amount: amount,
              status: status,
            );
            
            processes.add(process);
          }
          
          // 製品名の生成（製法区分＋精米歩合）
          String name = type;
          if (category.isNotEmpty) {
            name = '$name $category';
          }
          
          // JungoDataオブジェクトの作成
          final jungoData = JungoData(
            jungoId: jungoId,
            name: name,
            category: category,
            type: type,
            tankNo: tankNo,
            startDate: startDate,
            endDate: endDate,
            size: size,
            processes: processes,
            records: [], // 空のレコードリストで初期化
          );
          
          // データのログ出力
          print('順号$jungoId: $name, タンク$tankNo, 工程数:${processes.length}');
          
          jungoList.add(jungoData);
        } catch (e) {
          print('行の処理でエラー: $e');
          continue;
        }
      }
      
      print('CSV解析完了: ${jungoList.length}件の順号データを取得');
      print('抽出された品種数: ${extractedRiceTypes.length}');
      return jungoList;
    } catch (e) {
      print('CSV解析でエラー: $e');
      return [];
    }
  }
  
  // 標準的な日付形式（yyyy/MM/dd）を解析
  static DateTime _parseStandardDate(String dateStr) {
    try {
      // yyyy/MM/dd 形式
      try {
        return DateFormat('yyyy/MM/dd').parse(dateStr);
      } catch (e) {
        // 次の形式を試す
      }
      
      // yyyy-MM-dd 形式
      try {
        return DateFormat('yyyy-MM-dd').parse(dateStr);
      } catch (e) {
        // 次の形式を試す
      }
      
      // yyyy/M/d 形式（月日が1桁の場合）
      try {
        return DateFormat('yyyy/M/d').parse(dateStr);
      } catch (e) {
        // 次の形式を試す
      }
      
      // MM/dd 形式（年が省略された場合）
      RegExp shortDatePattern = RegExp(r'(\d{1,2})/(\d{1,2})');
      var match = shortDatePattern.firstMatch(dateStr);
      if (match != null) {
        int year = DateTime.now().year; // 現在の年を使用
        int month = int.parse(match.group(1)!);
        int day = int.parse(match.group(2)!);
        return DateTime(year, month, day);
      }
      
      // MM月dd日 形式
      RegExp jpDatePattern = RegExp(r'(\d{1,2})月(\d{1,2})日');
      match = jpDatePattern.firstMatch(dateStr);
      if (match != null) {
        int year = DateTime.now().year; // 現在の年を使用
        int month = int.parse(match.group(1)!);
        int day = int.parse(match.group(2)!);
        return DateTime(year, month, day);
      }
      
      // 解析失敗時は現在日付を返す
      print('日付解析に失敗: $dateStr');
      return DateTime.now();
    } catch (e) {
      print('日付解析エラー: $e, 日付文字列: $dateStr');
      return DateTime.now();
    }
  }

  // 追加: 抽出した品種リストを取得するメソッド
  static List<String> getExtractedRiceTypes() {
    final types = extractedRiceTypes.toList();
    types.sort(); // アルファベット順に並べ替え
    return types;
  }
}