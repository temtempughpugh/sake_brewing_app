import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';

/// 麹関連の機能を提供するサービスクラス
class KojiService extends ChangeNotifier {
  final BrewingDataProvider _brewingDataProvider;
  
  KojiService(this._brewingDataProvider);
  
  /// 指定日の出麹プロセスを取得
  List<BrewingProcess> getDekojiProcesses(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    return _brewingDataProvider.jungoList.expand((jungo) => jungo.processes).where((process) {
      // 麹工程で、出麹日が指定日と一致するもの
      if (process.type == ProcessType.koji) {
        final dekojiDate = process.getDekojiDate();
        return DateFormat('yyyy-MM-dd').format(dekojiDate) == dateStr;
      }
      return false;
    }).toList();
  }
  
  /// 出麹配分を計算
  Map<String, double> calculateDistribution(
    List<BrewingProcess> processes, 
    double estimatedKojiRate
  ) {
    // 用途ごとにプロセスをグループ化
    final usageGroups = <String, List<BrewingProcess>>{};
    
    for (var process in processes) {
      final usage = _determineUsage(process.name);
      if (usageGroups.containsKey(usage)) {
        usageGroups[usage]!.add(process);
      } else {
        usageGroups[usage] = [process];
      }
    }
    
    // 用途ごとの合計重量を計算
    final usageWeights = <String, double>{};
    for (var entry in usageGroups.entries) {
      usageWeights[entry.key] = entry.value.fold<double>(
        0, (sum, process) => sum + process.amount);
    }
    
    // 出麹順序を決定
    final order = ['酒母', '添', '仲', '留', '四段', 'その他'];
    final sortedUsages = usageWeights.keys.toList()
      ..sort((a, b) => order.indexOf(a) - order.indexOf(b));
    
    // 各用途の予想出麹重量を計算
    final distribution = <String, double>{};
    for (var usage in sortedUsages) {
      final originalWeight = usageWeights[usage]!;
      final expectedKojiWeight = originalWeight * estimatedKojiRate / 100;
      distribution[usage] = expectedKojiWeight;
    }
    
    return distribution;
  }
  
  /// 詳細な棚配分計算
  Map<String, dynamic> calculateShelfDistribution(
    List<BrewingProcess> processes,
    double estimatedKojiRate
  ) {
    // 用途ごとにプロセスをグループ化
    final usageGroups = <String, List<BrewingProcess>>{};
    
    for (var process in processes) {
      final usage = _determineUsage(process.name);
      if (usageGroups.containsKey(usage)) {
        usageGroups[usage]!.add(process);
      } else {
        usageGroups[usage] = [process];
      }
    }
    
    // 用途ごとの合計重量を計算
    final usageWeights = <String, double>{};
    for (var entry in usageGroups.entries) {
      usageWeights[entry.key] = entry.value.fold<double>(
        0, (sum, process) => sum + process.amount);
    }
    
    // 各用途を「ロット」として扱い、配分計算の入力形式に変換
    final lots = <Map<String, dynamic>>[];
    for (var entry in usageWeights.entries) {
      if (entry.value > 0) {
        lots.add({
          'type': entry.key,
          'weight': entry.value * estimatedKojiRate / 100,
          'originalWeight': entry.value,
          'lotIndex': 0,
        });
      }
    }
    
    // ロットが少なすぎる場合はエラー
    if (lots.isEmpty) {
      return {'error': '出麹するロットがありません'};
    }
    
    if (lots.length == 1 && lots[0]['weight'] <= 30) {
      if (lots[0]['weight'] == 30) {
        return {'error': '単一用途かつ単一ロットで30kgの場合は計算できません'};
      } else {
        return {'error': '単一用途かつ単一ロットで30kg以下の場合は計算しません'};
      }
    }
    
    try {
      // 1. 各ロットの枚数と列数を計算
      for (var lot in lots) {
        lot['sheets'] = (lot['weight'] / 10).ceil();
        lot['columns'] = ((lot['weight'] / 10).ceil() / 5).ceil();
      }
      
      // 2. 各ロットの行数を計算
      for (var lot in lots) {
        lot['rows'] = (lot['sheets'] / lot['columns']).ceil();
      }
      
      // 3. 総列数をチェックし、必要に応じて調整
      int totalColumns = lots.fold<int>(0, (sum, lot) => sum + lot['columns'] as int);
      if (totalColumns > 4) {
        return {'error': '必要な列数が4を超えています (${totalColumns}列)'};
      }
      
      // 列数が不足している場合、最も行数の多いロットの列数を増やす
      while (totalColumns < 4) {
        var maxRowLot = lots.reduce((a, b) => a['rows'] > b['rows'] ? a : b);
        maxRowLot['columns'] = maxRowLot['columns'] + 1;
        maxRowLot['rows'] = (maxRowLot['sheets'] / maxRowLot['columns']).ceil();
        totalColumns++;
      }
      
      // 4. 各ロットの枚数分布を計算
      for (var lot in lots) {
        int sheetsPerColumn = (lot['sheets'] / lot['columns']).floor();
        int remainder = lot['sheets'] % lot['columns'];
        List<int> distribution = List.filled(lot['columns'], sheetsPerColumn);
        for (int i = 0; i < remainder; i++) {
          distribution[i]++;
        }
        lot['distribution'] = distribution;
      }
      
      // 5. 列の割り当て
      final columns = ['A', 'B', 'C', 'D'];
      final usedColumns = <String>{};
      final result = <String, List<String>>{};
      
      // 優先ロット（最大5枚/列のもの）を抽出
      final priorityLots = lots.where((lot) => 
        (lot['distribution'] as List<int>).reduce((a, b) => a > b ? a : b) == 5
      ).toList();
      
      // 通常ロット
      final normalLots = lots.where((lot) => 
        (lot['distribution'] as List<int>).reduce((a, b) => a > b ? a : b) != 5
      ).toList();
      
      // 用途の優先順位
      final order = ['酒母', '留', '仲', '添', '四段', 'その他'];
      
      // 優先ロットをソート（用途順、枚数の多い順）
      priorityLots.sort((a, b) {
        if (a['type'] != b['type']) {
          return order.indexOf(a['type'].toString()) - order.indexOf(b['type'].toString());
        }
        return (b['sheets'] as int) - (a['sheets'] as int);
      });
      
      // 通常ロットをソート
      normalLots.sort((a, b) {
        if (a['type'] != b['type']) {
          return order.indexOf(a['type'].toString()) - order.indexOf(b['type'].toString());
        }
        return (b['sheets'] as int) - (a['sheets'] as int);
      });
      
      // 優先ロットに列を割り当て
      for (var lot in priorityLots) {
        final lotColumns = columns
            .where((col) => !usedColumns.contains(col))
            .take(lot['columns'] as int)
            .toList();
        
        if (lotColumns.length < lot['columns']) {
          return {'error': '${lot['type']}の配置に必要な列が足りません'};
        }
        
        lotColumns.forEach((col) => usedColumns.add(col));
        final lotKey = '${lot['type']}';
        
        final distribution = lot['distribution'] as List<int>;
        result[lotKey] = [];
        
        for (int i = 0; i < lotColumns.length; i++) {
          result[lotKey]!.add('${lotColumns[i]}${distribution[i]}');
        }
      }
      
      // 通常ロットに列を割り当て
      for (var lot in normalLots) {
        List<String> lotColumns;
        
        if (lot['type'] == '酒母') {
          // 酒母は右端から配置
          lotColumns = columns
              .where((col) => !usedColumns.contains(col))
              .toList()
              .reversed
              .take(lot['columns'] as int)
              .toList();
        } else {
          // その他は左から配置
          lotColumns = columns
              .where((col) => !usedColumns.contains(col))
              .take(lot['columns'] as int)
              .toList();
        }
        
        if (lotColumns.length < lot['columns']) {
          return {'error': '${lot['type']}の配置に必要な列が足りません'};
        }
        
        lotColumns.forEach((col) => usedColumns.add(col));
        final lotKey = '${lot['type']}';
        
        final distribution = lot['distribution'] as List<int>;
        result[lotKey] = [];
        
        for (int i = 0; i < lotColumns.length; i++) {
          result[lotKey]!.add('${lotColumns[i]}${distribution[i]}');
        }
      }
      
      // 結果を整形
      final shelfView = [[], [], [], []];
      
      result.forEach((key, value) {
        for (var item in value) {
          final column = item[0];
          final count = item.substring(1);
          final index = columns.indexOf(column);
          
          (shelfView[index] as List).add({
            'usage': key,
            'count': int.parse(count),
          });
        }
      });
      
      // 棚配分の返却
      return {
        'shelfAssignment': result,
        'shelfView': shelfView,
        'lots': lots,
      };
      
    } catch (e) {
      return {'error': '計算中にエラーが発生しました: $e'};
    }
  }
  
  /// 出麹歩合を計算して更新
  void updateKojiRates(List<BrewingProcess> processes, double finalWeight) {
    // 合計の元重量を計算
    final totalOriginalWeight = processes.fold<double>(
      0, (sum, process) => sum + process.amount);
    
    // 実際の出麹歩合を計算
    final actualRate = (finalWeight / totalOriginalWeight) * 100;
    
    // 用途ごとの分類
    final usageGroups = <String, List<BrewingProcess>>{};
    for (var process in processes) {
      final usage = _determineUsage(process.name);
      if (usageGroups.containsKey(usage)) {
        usageGroups[usage]!.add(process);
      } else {
        usageGroups[usage] = [process];
      }
    }
    
    // 用途ごとの合計重量を計算
    final usageWeights = <String, double>{};
    for (var entry in usageGroups.entries) {
      usageWeights[entry.key] = entry.value.fold<double>(
        0, (sum, process) => sum + process.amount);
    }
    
    // 用途ごとの比率に基づいて最終重量を配分
    final usageDistribution = <String, double>{};
    for (var entry in usageWeights.entries) {
      usageDistribution[entry.key] = (entry.value / totalOriginalWeight) * finalWeight;
    }
    
    // 各プロセスの出麹歩合と最終重量を更新
    for (var process in processes) {
      // プロセスのデータを更新
      _brewingDataProvider.updateProcessKojiData(
        process.jungoId,
        process.name,
        actualKojiRate: actualRate,
        finalKojiWeight: (process.amount / totalOriginalWeight) * finalWeight,
      );
    }
    
    notifyListeners();
  }
  
  // プロセス名から用途を決定するヘルパーメソッド
  String _determineUsage(String processName) {
    final name = processName.toLowerCase();
    
    if (name.contains('モト')) {
      return '酒母';
    } else if (name.contains('添') || name.contains('初')) {
      return '添';
    } else if (name.contains('仲')) {
      return '仲';
    } else if (name.contains('留')) {
      return '留';
    } else if (name.contains('四段')) {
      return '四段';
    } else {
      return 'その他';
    }
    }
    }