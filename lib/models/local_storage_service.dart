import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';

class LocalStorageService {
  static const String _jungoListKey = 'jungo_list';

  // データを保存
  Future<void> saveJungoData(JungoData jungo) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // 既存のデータを取得
    List<JungoData> jungoList = await loadJungoData();
    
    // デバッグ出力
    print('保存前の順号リスト数: ${jungoList.length}');
    
    // 既存のデータから同じIDのものを削除し、新しいデータを追加
    jungoList.removeWhere((item) => item.jungoId == jungo.jungoId);
    jungoList.add(jungo);
    
    // JSONに変換
    final jsonList = jungoList.map((jungo) => _jungoToJson(jungo)).toList();
    final jsonString = jsonEncode(jsonList);
    
    // デバッグ出力
    print('保存するJSONデータサイズ: ${jsonString.length}文字');
    
    // 保存
    final result = await prefs.setString(_jungoListKey, jsonString);
    print('保存結果: $result');
    
    // 保存後に読み込んで確認
    final checkString = prefs.getString(_jungoListKey);
    print('保存後の確認: ${checkString != null ? 'データあり(${checkString.length}文字)' : 'データなし'}');
    
  } catch (e) {
    print('ローカルストレージ保存エラー: $e');
    rethrow;
  }
}

  // データを読み込む
  Future<List<JungoData>> loadJungoData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 保存されたJSONを取得
      final jsonString = prefs.getString(_jungoListKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      // JSONをパース
      final List<dynamic> jsonList = jsonDecode(jsonString);
      
      // JungoDataオブジェクトに変換
      return jsonList.map<JungoData>((json) => _jsonToJungo(json)).toList();
    } catch (e) {
      print('ローカルストレージ読み込みエラー: $e');
      return [];
    }
  }

  // JungoDataをJSONに変換
  Map<String, dynamic> _jungoToJson(JungoData jungo) {
    return {
      'jungoId': jungo.jungoId,
      'name': jungo.name,
      'category': jungo.category,
      'type': jungo.type,
      'tankNo': jungo.tankNo,
      'startDate': jungo.startDate.millisecondsSinceEpoch,
      'endDate': jungo.endDate.millisecondsSinceEpoch,
      'size': jungo.size,
      'processes': jungo.processes.map((process) => _processToJson(process)).toList(),
      'records': jungo.records.map((record) => _recordToJson(record)).toList(),
    };
  }

  // JSONからJungoDataを作成
  JungoData _jsonToJungo(Map<String, dynamic> json) {
    return JungoData(
      jungoId: json['jungoId'],
      name: json['name'],
      category: json['category'],
      type: json['type'],
      tankNo: json['tankNo'],
      startDate: DateTime.fromMillisecondsSinceEpoch(json['startDate']),
      endDate: DateTime.fromMillisecondsSinceEpoch(json['endDate']),
      size: json['size'],
      processes: (json['processes'] as List)
          .map<BrewingProcess>((processJson) => _jsonToProcess(processJson))
          .toList(),
      records: (json['records'] as List)
          .map<TankRecord>((recordJson) => _jsonToRecord(recordJson))
          .toList(),
    );
  }

// TankRecordをJSONに変換するメソッド
Map<String, dynamic> _recordToJson(TankRecord record) {
  return {
    'date': record.date.millisecondsSinceEpoch,
    'temperature': record.temperature,
    'baume': record.baume,
    'memo': record.memo,
  };
}

  // BrewingProcessをJSONに変換
  Map<String, dynamic> _processToJson(BrewingProcess process) {
    return {
      'jungoId': process.jungoId,
      'name': process.name,
      'type': process.type.index,
      'date': process.date.millisecondsSinceEpoch,
      'washingDate': process.washingDate.millisecondsSinceEpoch,
      'riceType': process.riceType,
      'ricePct': process.ricePct,
      'amount': process.amount,
      'status': process.status.index,
      'memo': process.memo,
      'temperature': process.temperature,
      'waterAbsorption': process.waterAbsorption,
    };
  }

  // JSONからBrewingProcessを作成
  BrewingProcess _jsonToProcess(Map<String, dynamic> json) {
    return BrewingProcess(
      jungoId: json['jungoId'],
      name: json['name'],
      type: ProcessType.values[json['type']],
      date: DateTime.fromMillisecondsSinceEpoch(json['date']),
      washingDate: DateTime.fromMillisecondsSinceEpoch(json['washingDate']),
      riceType: json['riceType'],
      ricePct: json['ricePct'],
      amount: json['amount'].toDouble(),
      status: ProcessStatus.values[json['status']],
      memo: json['memo'],
      temperature: json['temperature']?.toDouble(),
      waterAbsorption: json['waterAbsorption']?.toDouble(),
    );
  }


  // JSONからTankRecordを作成
  TankRecord _jsonToRecord(Map<String, dynamic> json) {
    return TankRecord(
      date: DateTime.fromMillisecondsSinceEpoch(json['date']),
      temperature: json['temperature']?.toDouble(),
      baume: json['baume']?.toDouble(),
      memo: json['memo'],
    );
  }
}