import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:sake_brewing_app/services/csv_service.dart';
import 'package:sake_brewing_app/models/local_storage_service.dart';

// 工程の種類
enum ProcessType {
  moromi,    // 醪
  koji,      // 麹
  washing,   // 洗米
  pressing,  // 上槽
  other,     // その他（四段など）
}

// 工程の状態
enum ProcessStatus {
  pending,   // 予定
  active,    // 進行中
  completed, // 完了
}

// 醸造工程データモデル
class BrewingProcess {
  final int jungoId;           // 順号ID
  final String name;           // 工程名（モト麹、初掛けなど）
  final ProcessType type;      // 工程タイプ
  final DateTime washingDate;  // 洗米日（CSVから直接取得）
  final DateTime date;         // 作業日（上槽の場合はそのままの日付）
  final String riceType;       // 米の種類
  final int ricePct;           // 精米歩合
  final double amount;         // 量（kg）
  ProcessStatus status;        // 工程の状態
  
  // 追加記録データ
  String? memo;                 // メモ
  double? temperature;          // 温度
  double? waterAbsorption;      // 吸水率（洗米のみ）

  BrewingProcess({
    required this.jungoId,
    required this.name,
    required this.type,
    required this.washingDate,
    required this.date,
    required this.riceType,
    required this.ricePct,
    required this.amount,
    this.status = ProcessStatus.pending,
    this.memo,
    this.temperature,
    this.waterAbsorption,
  });
  
  // 引込み日を取得（洗米日の翌日）
  DateTime getHikomiDate() {
    if (type == ProcessType.koji) {
      return washingDate.add(const Duration(days: 1));
    }
    return washingDate;
  }
  
  // 盛り日を取得（洗米日の2日後）
  DateTime getMoriDate() {
    if (type == ProcessType.koji) {
      return washingDate.add(const Duration(days: 2));
    }
    return washingDate;
  }
  
  // 出麹日を取得（洗米日の3日後）
  DateTime getDekojiDate() {
    if (type == ProcessType.koji) {
      return washingDate.add(const Duration(days: 3));
    }
    return washingDate;
  }
  
  // 作業日を取得
  DateTime getWorkDate() {
    if (type == ProcessType.moromi) {
      return washingDate.add(const Duration(days: 1));
    } else if (type == ProcessType.koji) {
      // 麹の場合は使用目的に応じた日付
      return getDekojiDate().add(const Duration(days: 1));
    }
    return date;
  }
}

// 順号データモデル
class JungoData {
  final int jungoId;                   // 順号ID
  final String name;                   // 製品名
  final String category;               // 仕込区分
  final String type;                   // 製法区分
  final String tankNo;                  // タンク番号
  final DateTime startDate;            // 留日
  final DateTime endDate;              // 上槽予定日
  final int size;                      // 仕込規模
  final List<BrewingProcess> processes;// 工程リスト
  final List<TankRecord> records;      // 記録データ

  JungoData({
    required this.jungoId,
    required this.name,
    required this.category,
    required this.type,
    required this.tankNo,
    required this.startDate, 
    required this.endDate,
    required this.size,
    required this.processes,
    required this.records,
  });

  // 現在の日数を計算（正確な計算に修正）
  int get currentDayCount {
    final today = DateTime.now();
    
    // 留日がまだ来ていない場合
    if (today.isBefore(startDate)) {
      return 0;
    }
    
    // 既に上槽日を過ぎている場合
    if (today.isAfter(endDate)) {
      return totalDayCount;
    }
    
    // 醪期間中の場合
    return today.difference(startDate).inDays + 1;
  }

  // 全体の日数を計算
  int get totalDayCount {
    // データエラー対策
    if (endDate.isBefore(startDate)) {
      print('警告: 上槽日($endDate)が留日($startDate)より前になっています');
      return 1; // エラー時は1日間として扱う
    }
    
    return endDate.difference(startDate).inDays + 1;
  }

  // 進捗率を計算（%）
  double get progressPercent {
    final total = totalDayCount;
    if (total <= 0) return 0;
    
    final current = currentDayCount;
    if (current <= 0) return 0;
    if (current >= total) return 100;
    
    return (current / total) * 100;
  }
}

// タンク記録データモデル
class TankRecord {
  final DateTime date;        // 記録日
  final double? temperature;  // 温度
  final double? baume;        // ボーメ
  final String? memo;         // メモ

  TankRecord({
    required this.date,
    this.temperature,
    this.baume,
    this.memo,
  });
}

// データプロバイダー（アプリ全体で使うデータを管理）

class BrewingDataProvider with ChangeNotifier {
  List<JungoData> _jungoList = [];
  DateTime _selectedDate = DateTime.now();
  final LocalStorageService _storageService = LocalStorageService();
  bool _isLoading = false;

  // 新しいゲッター
  List<JungoData> get jungoList => _jungoList;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  
Future<void> loadFromLocalStorage() async {
  _isLoading = true;
  notifyListeners();
  
  try {
    final jungoList = await _storageService.loadJungoData();
    if (jungoList.isNotEmpty) {
      _jungoList = jungoList;
      notifyListeners();
    }
  } catch (e) {
    print('ローカルストレージからのデータロードエラー: $e');
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

Future<void> saveToLocalStorage() async {
  _isLoading = true;
  notifyListeners();
  
  try {
    for (var jungo in _jungoList) {
      await _storageService.saveJungoData(jungo);
    }
  } catch (e) {
    print('ローカルストレージへのデータ保存エラー: $e');
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

Future<void> loadFromCsv(String csvData) async {
  try {
    final jungoList = await CsvService.parseBrewingCsv(csvData);
    if (jungoList.isNotEmpty) {
      // 既存のコード：
      _jungoList = jungoList;
      notifyListeners();
      
      // 追加する行：UIをすぐに更新するための遅延処理
      Future.delayed(Duration.zero, () {
        notifyListeners();
      });
      
      // ローカルストレージに保存
      await saveToLocalStorage();
    }
  } catch (e) {
    print('CSVデータ読み込みエラー: $e');
  }
}
  
  // 日付を変更
  void changeDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  // 今日の作業リストを取得
  List<BrewingProcess> getTodayProcesses() {
    final today = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd');
    final todayStr = formatter.format(today);
    
    List<BrewingProcess> processes = [];
    
    for (var jungo in _jungoList) {
      for (var process in jungo.processes) {
        // 上槽工程の場合は日付を直接比較
        if (process.type == ProcessType.pressing) {
          if (formatter.format(process.date) == todayStr) {
            processes.add(process);
          }
          continue;
        }
        
        // 麹工程の場合は各ステージの日付をチェック
        if (process.type == ProcessType.koji) {
          final hikomiDate = process.getHikomiDate();
          final moriDate = process.getMoriDate();
          final dekojiDate = process.getDekojiDate();
          
          if (formatter.format(hikomiDate) == todayStr ||
              formatter.format(moriDate) == todayStr ||
              formatter.format(dekojiDate) == todayStr) {
            processes.add(process);
            continue;
          }
        }
        
        // 洗米工程の場合は洗米日を比較
        if (process.type == ProcessType.washing) {
          if (formatter.format(process.washingDate) == todayStr) {
            processes.add(process);
            continue;
          }
        }
        
        // 醪工程の場合は仕込み日（洗米の翌日）を比較
        if (process.type == ProcessType.moromi) {
          final workDate = process.getWorkDate();
          if (formatter.format(workDate) == todayStr) {
            processes.add(process);
            continue;
          }
        }
      }
    }
    
    // 工程タイプでソート
    processes.sort((a, b) => a.type.index.compareTo(b.type.index));
    
    return processes;
  }

  // 順号IDからデータを取得
  JungoData? getJungoById(int id) {
    try {
      return _jungoList.firstWhere((jungo) => jungo.jungoId == id);
    } catch (e) {
      return null;
    }
  }
  
  // 順号IDと工程名からプロセスを取得
  BrewingProcess? getProcessByJungoAndName(int jungoId, String processName) {
    try {
      final jungo = getJungoById(jungoId);
      if (jungo == null) return null;
      
      return jungo.processes.firstWhere(
        (process) => process.name == processName
      );
    } catch (e) {
      return null;
    }
  }

  // タンク記録を追加
  void addTankRecord(int jungoId, TankRecord record) {
    final index = _jungoList.indexWhere((jungo) => jungo.jungoId == jungoId);
    if (index != -1) {
      _jungoList[index].records.add(record);
      notifyListeners();
    }
  }

  // 工程の状態を更新
  void updateProcessStatus(int jungoId, String processName, ProcessStatus status) {
    final jungoIndex = _jungoList.indexWhere((jungo) => jungo.jungoId == jungoId);
    if (jungoIndex != -1) {
      final processIndex = _jungoList[jungoIndex].processes.indexWhere(
        (process) => process.name == processName
      );
      if (processIndex != -1) {
        _jungoList[jungoIndex].processes[processIndex].status = status;
        notifyListeners();
      }
    }
  }
  
  // 工程データを更新
  void updateProcessData(
    int jungoId,
    String processName, {
    String? memo,
    double? temperature,
    double? waterAbsorption,
  }) {
    final jungoIndex = _jungoList.indexWhere((jungo) => jungo.jungoId == jungoId);
    if (jungoIndex != -1) {
      final processIndex = _jungoList[jungoIndex].processes.indexWhere(
        (process) => process.name == processName
      );
      if (processIndex != -1) {
        // メモの更新
        if (memo != null) {
          _jungoList[jungoIndex].processes[processIndex].memo = memo;
        }
        
        // 温度の更新
        if (temperature != null) {
          _jungoList[jungoIndex].processes[processIndex].temperature = temperature;
        }
        
        // 吸水率の更新（洗米のみ）
        if (waterAbsorption != null && 
            _jungoList[jungoIndex].processes[processIndex].type == ProcessType.washing) {
          _jungoList[jungoIndex].processes[processIndex].waterAbsorption = waterAbsorption;
        }
        
        notifyListeners();
      }
    }
  }

  // サンプルデータを生成（テスト用）
  void generateSampleData() {
    final now = DateTime.now();
    
    // 順号1のデータ
    final jungo1Processes = [
      BrewingProcess(
        jungoId: 1,
        name: 'モト麹',
        type: ProcessType.koji,
        washingDate: now.subtract(const Duration(days: 20)),
        date: now.subtract(const Duration(days: 20)),
        riceType: '乾燥麹70',
        ricePct: 70,
        amount: 25,
        status: ProcessStatus.completed,
      ),
      BrewingProcess(
        jungoId: 1,
        name: 'モト掛',
        type: ProcessType.moromi,
        washingDate: now.subtract(const Duration(days: 17)),
        date: now.subtract(const Duration(days: 17)),
        riceType: 'こいもみじ70',
        ricePct: 70,
        amount: 45,
        status: ProcessStatus.completed,
      ),
      BrewingProcess(
        jungoId: 1,
        name: '初麹',
        type: ProcessType.koji,
        washingDate: now.subtract(const Duration(days: 7)),
        date: now.subtract(const Duration(days: 7)),
        riceType: '乾燥麹70',
        ricePct: 70,
        amount: 55,
        status: ProcessStatus.completed,
      ),
      BrewingProcess(
        jungoId: 1,
        name: '初掛',
        type: ProcessType.moromi,
        washingDate: now.subtract(const Duration(days: 4)),
        date: now.subtract(const Duration(days: 4)),
        riceType: 'こいもみじ70',
        ricePct: 70,
        amount: 125,
        status: ProcessStatus.completed,
      ),
      BrewingProcess(
        jungoId: 1,
        name: '仲麹',
        type: ProcessType.koji,
        washingDate: now.subtract(const Duration(days: 5)),
        date: now.subtract(const Duration(days: 5)),
        riceType: '乾燥麹70',
        ricePct: 70,
        amount: 75,
        status: ProcessStatus.completed,
      ),
      BrewingProcess(
        jungoId: 1,
        name: '仲掛',
        type: ProcessType.moromi,
        washingDate: now.subtract(const Duration(days: 2)),
        date: now.subtract(const Duration(days: 2)),
        riceType: 'こいもみじ70',
        ricePct: 70,
        amount: 285,
        status: ProcessStatus.completed,
      ),
      BrewingProcess(
        jungoId: 1,
        name: '留麹',
        type: ProcessType.koji,
        washingDate: now.subtract(const Duration(days: 1)),
        date: now.subtract(const Duration(days: 1)),
        riceType: 'こいもみじ70',
        ricePct: 70,
        amount: 110,
        status: ProcessStatus.completed,
      ),
      BrewingProcess(
        jungoId: 1,
        name: '留掛',
        type: ProcessType.moromi,
        washingDate: now.subtract(const Duration(days: 1)),
        date: now.subtract(const Duration(days: 1)),
        riceType: 'こいもみじ70',
        ricePct: 70,
        amount: 415,
        status: ProcessStatus.active,
      ),
      // 四段（今日の作業）
      BrewingProcess(
        jungoId: 1,
        name: '四段',
        type: ProcessType.other,
        washingDate: now,
        date: now,
        riceType: 'こいもみじ70',
        ricePct: 70,
        amount: 50,
        status: ProcessStatus.pending,
      ),
    ];
    
    // 順号1のタンク記録
    final jungo1Records = [
      TankRecord(
        date: now.subtract(const Duration(days: 17)),
        temperature: 12.0,
        baume: 13.0,
      ),
      TankRecord(
        date: now.subtract(const Duration(days: 16)),
        temperature: 14.0,
        baume: 12.5,
      ),
      TankRecord(
        date: now.subtract(const Duration(days: 15)),
        temperature: 16.0,
        baume: 12.0,
      ),
      TankRecord(
        date: now.subtract(const Duration(days: 14)),
        temperature: 18.0,
        baume: 11.0,
      ),
      TankRecord(
        date: now.subtract(const Duration(days: 13)),
        temperature: 20.0,
        baume: 10.0,
      ),
      TankRecord(
        date: now.subtract(const Duration(days: 4)),
        temperature: 18.0,
        baume: 9.0,
      ),
      TankRecord(
        date: now.subtract(const Duration(days: 3)),
        temperature: 17.0,
        baume: 8.0,
      ),
      TankRecord(
        date: now.subtract(const Duration(days: 2)),
        temperature: 15.0,
        baume: 7.0,
      ),
      TankRecord(
        date: now.subtract(const Duration(days: 1)),
        temperature: 14.0,
        baume: 6.5,
      ),
      TankRecord(
        date: now,
        temperature: 13.0,
        baume: 6.0,
      ),
    ];
    
    // 順号1
    final jungo1 = JungoData(
      jungoId: 1,
      name: 'にごり酒70',
      category: '普通酒',
      type: 'にごり酒',
      tankNo: "888",
      startDate: now.subtract(const Duration(days: 1)), // 留日（昨日）
      endDate: now.add(const Duration(days: 17)),      // 上槽予定日
      size: 720,
      processes: jungo1Processes,
      records: jungo1Records,
    );
    
    // 順号2のプロセス（明日の仕込み用）
    final jungo2Processes = [
      // 今日の洗米
      BrewingProcess(
        jungoId: 2,
        name: '洗米',
        type: ProcessType.washing,
        washingDate: now,
        date: now,
        riceType: 'こいもみじ70',
        ricePct: 70,
        amount: 300,
        status: ProcessStatus.pending,
      ),
      // 明日の仕込み
      BrewingProcess(
        jungoId: 2,
        name: '留掛',
        type: ProcessType.moromi,
        washingDate: now,
        date: now.add(const Duration(days: 1)),
        riceType: 'こいもみじ70',
        ricePct: 70,
        amount: 300,
        status: ProcessStatus.pending,
      ),
    ];
    
    final jungo2 = JungoData(
      jungoId: 2,
      name: 'にごり酒70',
      category: '普通酒',
      type: 'にごり酒',
      tankNo: "288",
      startDate: now.add(const Duration(days: 1)),
      endDate: now.add(const Duration(days: 18)),
      size: 720,
      processes: jungo2Processes,
      records: [],
    );
    
    // 順号3のプロセス
    final jungo3Processes = [
      // 今日の麹作業（引込み）
      BrewingProcess(
        jungoId: 3,
        name: '初麹',
        type: ProcessType.koji,
        washingDate: now.subtract(const Duration(days: 1)),
        date: now.subtract(const Duration(days: 1)),
        riceType: '乾燥麹70',
        ricePct: 70,
        amount: 46,
        status: ProcessStatus.active,
      ),
      // 明後日の仕込み
      BrewingProcess(
        jungoId: 3,
        name: '初掛',
        type: ProcessType.moromi,
        washingDate: now.add(const Duration(days: 1)),
        date: now.add(const Duration(days: 2)),
        riceType: 'こいもみじ70',
        ricePct: 70,
        amount: 300,
        status: ProcessStatus.pending,
      ),
    ];
    
    final jungo3 = JungoData(
      jungoId: 3,
      name: 'にごり酒70',
      category: '普通酒',
      type: 'にごり酒',
      tankNo: "263",
      startDate: now.add(const Duration(days: 2)),
      endDate: now.add(const Duration(days: 19)),
      size: 720,
      processes: jungo3Processes,
      records: [],
    );
    
    // 上槽予定の醪
    final jungo4Processes = [
      // 今日の上槽作業
      BrewingProcess(
        jungoId: 4,
        name: '上槽',
        type: ProcessType.pressing,
        washingDate: now,
        date: now,
        riceType: '山田錦',
        ricePct: 60,
        amount: 500,
        status: ProcessStatus.pending,
      ),
    ];
    
    final jungo4 = JungoData(
      jungoId: -2, // マイナス値で過去の順号を表現
      name: '純米吟醸',
      category: '純米吟醸',
      type: '純米吟醸',
      tankNo: "115",
      startDate: now.subtract(const Duration(days: 24)),
      endDate: now,
      size: 720,
      processes: jungo4Processes,
      records: [],
    );
    
    _jungoList = [jungo1, jungo2, jungo3, jungo4];
    notifyListeners();
  }
}