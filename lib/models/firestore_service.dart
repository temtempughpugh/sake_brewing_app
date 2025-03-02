// models/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 順号データを保存
  Future<void> saveJungoData(JungoData jungo) async {
    try {
      // 基本情報を保存
      await _firestore.collection('jungos').doc(jungo.jungoId.toString()).set({
        'jungoId': jungo.jungoId,
        'name': jungo.name,
        'category': jungo.category,
        'type': jungo.type,
        'tankNo': jungo.tankNo,
        'startDate': Timestamp.fromDate(jungo.startDate),
        'endDate': Timestamp.fromDate(jungo.endDate),
        'size': jungo.size,
      });

      // 工程データを保存
      for (var process in jungo.processes) {
        await _firestore
          .collection('jungos')
          .doc(jungo.jungoId.toString())
          .collection('processes')
          .doc('${process.name}_${process.date.millisecondsSinceEpoch}')
          .set({
            'jungoId': process.jungoId,
            'name': process.name,
            'type': process.type.index,
            'date': Timestamp.fromDate(process.date),
            'washingDate': Timestamp.fromDate(process.washingDate),
            'riceType': process.riceType,
            'ricePct': process.ricePct,
            'amount': process.amount,
            'status': process.status.index,
            'memo': process.memo,
            'temperature': process.temperature,
            'waterAbsorption': process.waterAbsorption,
          });
      }

      // レコードデータを保存
      for (var record in jungo.records) {
        await _firestore
          .collection('jungos')
          .doc(jungo.jungoId.toString())
          .collection('records')
          .doc(record.date.millisecondsSinceEpoch.toString())
          .set({
            'date': Timestamp.fromDate(record.date),
            'temperature': record.temperature,
            'baume': record.baume,
            'memo': record.memo,
          });
      }
    } catch (e) {
      print('Firestore保存エラー: $e');
      rethrow;
    }
  }

  // データを読み込む
  Future<List<JungoData>> loadJungoData() async {
    try {
      final jungosSnapshot = await _firestore.collection('jungos').get();
      List<JungoData> jungoList = [];

      for (var doc in jungosSnapshot.docs) {
        final jungoId = doc.data()['jungoId'] as int;
        
        // 工程データの取得
        final processesSnapshot = await _firestore
          .collection('jungos')
          .doc(doc.id)
          .collection('processes')
          .get();
        
        List<BrewingProcess> processes = [];
        for (var processDoc in processesSnapshot.docs) {
          final data = processDoc.data();
          processes.add(BrewingProcess(
            jungoId: data['jungoId'] as int,
            name: data['name'] as String,
            type: ProcessType.values[data['type'] as int],
            date: (data['date'] as Timestamp).toDate(),
            washingDate: (data['washingDate'] as Timestamp).toDate(),
            riceType: data['riceType'] as String,
            ricePct: data['ricePct'] as int,
            amount: (data['amount'] as num).toDouble(),
            status: ProcessStatus.values[data['status'] as int],
            memo: data['memo'] as String?,
            temperature: data['temperature'] as double?,
            waterAbsorption: data['waterAbsorption'] as double?,
          ));
        }
        
        // レコードデータの取得
        final recordsSnapshot = await _firestore
          .collection('jungos')
          .doc(doc.id)
          .collection('records')
          .get();
        
        List<TankRecord> records = [];
        for (var recordDoc in recordsSnapshot.docs) {
          final data = recordDoc.data();
          records.add(TankRecord(
            date: (data['date'] as Timestamp).toDate(),
            temperature: data['temperature'] as double?,
            baume: data['baume'] as double?,
            memo: data['memo'] as String?,
          ));
        }
        
        // JungoDataオブジェクトの作成
        jungoList.add(JungoData(
          jungoId: jungoId,
          name: doc.data()['name'] as String,
          category: doc.data()['category'] as String,
          type: doc.data()['type'] as String,
          tankNo: doc.data()['tankNo'] as int,
          startDate: (doc.data()['startDate'] as Timestamp).toDate(),
          endDate: (doc.data()['endDate'] as Timestamp).toDate(),
          size: doc.data()['size'] as int,
          processes: processes,
          records: records,
        ));
      }
      
      return jungoList;
    } catch (e) {
      print('Firestore読み込みエラー: $e');
      return [];
    }
  }
}