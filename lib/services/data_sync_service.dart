import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';
import 'package:sake_brewing_app/services/firebase_service.dart';

class DataSyncService {
  static final DataSyncService _instance = DataSyncService._internal();
  
  factory DataSyncService() {
    return _instance;
  }
  
  DataSyncService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 最後の同期時刻
  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;
  
  // 同期状態
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  
  // 順号データをFirestoreに同期
  // lib/services/data_sync_service.dart のsyncJungoDataToFirestore部分を修正

Future<bool> syncJungoDataToFirestore(JungoData jungo) async {
  if (_firebaseService.currentUser == null) {
    debugPrint('ユーザーがログインしていません');
    return false;
  }
  
  _isSyncing = true;
  
  try {
    // Firestoreのリファレンスを取得する前にネットワーク接続を確認
    final isConnected = await _firebaseService.isConnected();
    if (!isConnected) {
      debugPrint('ネットワーク接続がありません');
      _isSyncing = false;
      return false;
    }
    
    final userDoc = _firestore.collection('users').doc(_firebaseService.currentUser!.uid);
    final jungoDoc = userDoc.collection('jungo_data').doc(jungo.jungoId.toString());
    
    // JungoDataをMap形式に変換
    final Map<String, dynamic> jungoMap = {
      'jungoId': jungo.jungoId,
      'name': jungo.name,
      'category': jungo.category,
      'type': jungo.type,
      'tankNo': jungo.tankNo,
      'startDate': Timestamp.fromDate(jungo.startDate),
      'endDate': Timestamp.fromDate(jungo.endDate),
      'size': jungo.size,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    
    // プロセスデータも保存
    final List<Map<String, dynamic>> processMaps = jungo.processes.map((process) {
      return {
        'jungoId': process.jungoId,
        'name': process.name,
        'type': process.type.index,
        'washingDate': Timestamp.fromDate(process.washingDate),
        'date': Timestamp.fromDate(process.date),
        'riceType': process.riceType,
        'ricePct': process.ricePct,
        'amount': process.amount,
        'status': process.status.index,
        'memo': process.memo,
        'temperature': process.temperature,
        'waterAbsorption': process.waterAbsorption,
        'actualKojiRate': process.actualKojiRate,
        'finalKojiWeight': process.finalKojiWeight,
      };
    }).toList();
    
    jungoMap['processes'] = processMaps;
    
    // タンク記録データも保存
    final List<Map<String, dynamic>> recordMaps = jungo.records.map((record) {
      return {
        'date': Timestamp.fromDate(record.date),
        'temperature': record.temperature,
        'baume': record.baume,
        'memo': record.memo,
      };
    }).toList();
    
    jungoMap['records'] = recordMaps;
    
    // Firestoreに保存
    await jungoDoc.set(jungoMap, SetOptions(merge: true));
    
    _lastSyncTime = DateTime.now();
    _isSyncing = false;
    return true;
  } catch (e) {
    debugPrint('Firestore同期エラー: $e');
    _isSyncing = false;
    return false;
  }
}
  
  // すべての順号データを同期
  Future<bool> syncAllJungoData(List<JungoData> jungoList) async {
    if (_firebaseService.currentUser == null) {
      debugPrint('ユーザーがログインしていません');
      return false;
    }
    
    _isSyncing = true;
    bool success = true;
    
    try {
      for (var jungo in jungoList) {
        final result = await syncJungoDataToFirestore(jungo);
        if (!result) {
          success = false;
        }
      }
      
      _lastSyncTime = DateTime.now();
      return success;
    } catch (e) {
      debugPrint('一括同期エラー: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }
  
  // Firestoreから順号データを取得
  Future<List<JungoData>> fetchJungoDataFromFirestore() async {
    if (_firebaseService.currentUser == null) {
      debugPrint('ユーザーがログインしていません');
      return [];
    }
    
    _isSyncing = true;
    
    try {
      final userDoc = _firestore.collection('users').doc(_firebaseService.currentUser!.uid);
      final jungoSnapshot = await userDoc.collection('jungo_data').get();
      
      final List<JungoData> jungoList = [];
      
      for (var doc in jungoSnapshot.docs) {
        final data = doc.data();
        
        // プロセスデータの変換
        final List<BrewingProcess> processes = [];
        if (data['processes'] != null) {
          for (var processMap in data['processes']) {
            processes.add(BrewingProcess(
              jungoId: processMap['jungoId'],
              name: processMap['name'],
              type: ProcessType.values[processMap['type']],
              washingDate: (processMap['washingDate'] as Timestamp).toDate(),
              date: (processMap['date'] as Timestamp).toDate(),
              riceType: processMap['riceType'],
              ricePct: processMap['ricePct'],
              amount: processMap['amount'].toDouble(),
              status: ProcessStatus.values[processMap['status']],
              memo: processMap['memo'],
              temperature: processMap['temperature']?.toDouble(),
              waterAbsorption: processMap['waterAbsorption']?.toDouble(),
              actualKojiRate: processMap['actualKojiRate']?.toDouble(),
              finalKojiWeight: processMap['finalKojiWeight']?.toDouble(),
            ));
          }
        }
        
        // タンク記録データの変換
        final List<TankRecord> records = [];
        if (data['records'] != null) {
          for (var recordMap in data['records']) {
            records.add(TankRecord(
              date: (recordMap['date'] as Timestamp).toDate(),
              temperature: recordMap['temperature']?.toDouble(),
              baume: recordMap['baume']?.toDouble(),
              memo: recordMap['memo'],
            ));
          }
        }
        
        // JungoDataオブジェクトの作成
        jungoList.add(JungoData(
          jungoId: data['jungoId'],
          name: data['name'],
          category: data['category'],
          type: data['type'],
          tankNo: data['tankNo'],
          startDate: (data['startDate'] as Timestamp).toDate(),
          endDate: (data['endDate'] as Timestamp).toDate(),
          size: data['size'],
          processes: processes,
          records: records,
        ));
      }
      
      _lastSyncTime = DateTime.now();
      _isSyncing = false;
      return jungoList;
    } catch (e) {
      debugPrint('Firestoreからのデータ取得エラー: $e');
      _isSyncing = false;
      return [];
    }
  }
}