// lib/models/rice_data_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sake_brewing_app/models/rice_data.dart';
import 'package:sake_brewing_app/models/washing_record.dart';

class RiceDataProvider with ChangeNotifier {
  List<RiceData> _riceLots = [];
  List<WashingRecord> _washingRecords = [];
  bool _isLoading = false;

  // ゲッター
  List<RiceData> get riceLots => _riceLots;
  List<WashingRecord> get washingRecords => _washingRecords;
  bool get isLoading => _isLoading;

  // 品種リスト
  static const List<String> riceTypes = [
    '山田錦',
    '八反錦',
    '雄町',
    '千本錦',
    '加工用米',
    '八反35号',
    '未希米',
    'こいもみじ',
    'こいおまち',
    '萌いぶき',
    '中生新千本',
    '白鶴錦',
    '愛山',
    '朝日米',
  ];

  // 産地リスト
  static const List<String> origins = [
    '兵庫県産',
    '広島県産',
    '岡山県産',
  ];

  // コンストラクタ
  RiceDataProvider() {
    loadData();
  }

  // データをロード
  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 白米ロットデータの読み込み
      final riceLotsJson = prefs.getString('rice_lots');
      if (riceLotsJson != null) {
        final List<dynamic> jsonList = jsonDecode(riceLotsJson);
        _riceLots = jsonList.map<RiceData>((json) => RiceData.fromJson(json)).toList();
      }
      
      // 洗米記録データの読み込み
      final washingRecordsJson = prefs.getString('washing_records');
      if (washingRecordsJson != null) {
        final List<dynamic> jsonList = jsonDecode(washingRecordsJson);
        _washingRecords = jsonList.map<WashingRecord>((json) => WashingRecord.fromJson(json)).toList();
      }
    } catch (e) {
      print('白米データロードエラー: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // データを保存
  Future<void> saveData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 白米ロットデータの保存
      final riceLotsJson = jsonEncode(_riceLots.map((lot) => lot.toJson()).toList());
      await prefs.setString('rice_lots', riceLotsJson);
      
      // 洗米記録データの保存
      final washingRecordsJson = jsonEncode(_washingRecords.map((record) => record.toJson()).toList());
      await prefs.setString('washing_records', washingRecordsJson);
    } catch (e) {
      print('白米データ保存エラー: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 白米ロットの追加
  Future<void> addRiceLot(RiceData riceLot) async {
    _riceLots.add(riceLot);
    notifyListeners();
    await saveData();
  }

  // 白米ロットの更新
  Future<void> updateRiceLot(RiceData updatedLot) async {
    final index = _riceLots.indexWhere((lot) => lot.lotId == updatedLot.lotId);
    if (index != -1) {
      _riceLots[index] = updatedLot;
      notifyListeners();
      await saveData();
    }
  }

  // 白米ロットの削除
  Future<void> deleteRiceLot(String lotId) async {
    _riceLots.removeWhere((lot) => lot.lotId == lotId);
    notifyListeners();
    await saveData();
  }

  // 洗米記録の追加
  Future<void> addWashingRecord(WashingRecord record) async {
    _washingRecords.add(record);
    notifyListeners();
    await saveData();
  }

  // 洗米記録の更新
  Future<void> updateWashingRecord(WashingRecord updatedRecord) async {
    final index = _washingRecords.indexWhere(
      (record) => record.date.isAtSameMomentAs(updatedRecord.date) &&
                 record.riceLotIds.toString() == updatedRecord.riceLotIds.toString()
    );
    
    if (index != -1) {
      _washingRecords[index] = updatedRecord;
      notifyListeners();
      await saveData();
    }
  }

  // 洗米記録の削除
  Future<void> deleteWashingRecord(WashingRecord record) async {
    _washingRecords.removeWhere(
      (r) => r.date.isAtSameMomentAs(record.date) &&
             r.riceLotIds.toString() == record.riceLotIds.toString()
    );
    notifyListeners();
    await saveData();
  }

  // IDによる白米ロット取得
  RiceData? getRiceLotById(String lotId) {
    try {
      return _riceLots.firstWhere((lot) => lot.lotId == lotId);
    } catch (e) {
      return null;
    }
  }

  // 日付による洗米記録の取得
  List<WashingRecord> getWashingRecordsByDate(DateTime date) {
    return _washingRecords.where((record) {
      return record.date.year == date.year &&
             record.date.month == date.month &&
             record.date.day == date.day;
    }).toList();
  }

  // 次の白米ロットIDを生成
  String generateNextLotId() {
    if (_riceLots.isEmpty) {
      return "R001";
    }
    
    // 現在の最大IDを取得
    final sortedLots = List<RiceData>.from(_riceLots)
      ..sort((a, b) => a.lotId.compareTo(b.lotId));
    
    final lastLotId = sortedLots.last.lotId;
    
    if (lastLotId.startsWith('R')) {
      final number = int.parse(lastLotId.substring(1));
      return 'R${(number + 1).toString().padLeft(3, '0')}';
    } else {
      return "R001";
    }
  }
}