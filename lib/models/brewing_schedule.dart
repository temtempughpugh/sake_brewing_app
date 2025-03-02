import 'package:sake_brewing_app/models/brewing_data.dart';
import 'package:intl/intl.dart';

class DailySchedule {
  // 麹工程
  List<BrewingProcess> hikomiProcesses = []; // 引込み
  List<BrewingProcess> moriProcesses = [];   // 盛り
  List<BrewingProcess> dekojiProcesses = []; // 出麹
  
  // 仕込み工程
  List<BrewingProcess> motoProcesses = [];   // モト仕込み
  List<BrewingProcess> yodanProcesses = [];  // 四段
  List<BrewingProcess> soeProcesses = [];    // 添仕込み
  List<BrewingProcess> nakaProcesses = [];   // 仲仕込み
  List<BrewingProcess> tomeProcesses = [];   // 留仕込み
  
  // その他の工程
  List<BrewingProcess> washingProcesses = []; // 洗米
  List<BrewingProcess> pressingProcesses = []; // 上槽
  
  // 空かどうかのチェック
  bool get isEmpty {
    return hikomiProcesses.isEmpty &&
           moriProcesses.isEmpty &&
           dekojiProcesses.isEmpty &&
           motoProcesses.isEmpty &&
           yodanProcesses.isEmpty &&
           soeProcesses.isEmpty &&
           nakaProcesses.isEmpty &&
           tomeProcesses.isEmpty &&
           washingProcesses.isEmpty &&
           pressingProcesses.isEmpty;
  }
}

extension BrewingDataScheduleExtension on BrewingDataProvider {
  // 指定した日付のスケジュールを生成
  DailySchedule getDailySchedule(DateTime date) {
    final schedule = DailySchedule();
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    // 全ての順号とプロセスをループ
    for (var jungo in jungoList) {
      for (var process in jungo.processes) {
        // 各工程の日付を計算し、該当する日のものを抽出
        
        // 1. 洗米工程（洗米日が当日）
        if (process.type == ProcessType.washing) {
          final washingDateStr = DateFormat('yyyy-MM-dd').format(process.washingDate);
          if (washingDateStr == dateStr) {
            schedule.washingProcesses.add(process);
            continue;
          }
        }
        
        // 2. 麹工程
        if (process.type == ProcessType.koji) {
          // 引込み日が当日
          final hikomiDate = process.getHikomiDate();
          final hikomiDateStr = DateFormat('yyyy-MM-dd').format(hikomiDate);
          if (hikomiDateStr == dateStr) {
            schedule.hikomiProcesses.add(process);
            continue;
          }
          
          // 盛り日が当日
          final moriDate = process.getMoriDate();
          final moriDateStr = DateFormat('yyyy-MM-dd').format(moriDate);
          if (moriDateStr == dateStr) {
            schedule.moriProcesses.add(process);
            continue;
          }
          
          // 出麹日が当日
          final dekojiDate = process.getDekojiDate();
          final dekojiDateStr = DateFormat('yyyy-MM-dd').format(dekojiDate);
          if (dekojiDateStr == dateStr) {
            schedule.dekojiProcesses.add(process);
            continue;
          }
        }
        
        // 3. 醪工程（仕込み）
        if (process.type == ProcessType.moromi) {
          final workDate = process.getWorkDate();
          final workDateStr = DateFormat('yyyy-MM-dd').format(workDate);
          
          if (workDateStr == dateStr) {
            // 仕込み工程をさらに分類
            if (process.name.contains('モト')) {
              schedule.motoProcesses.add(process);
            } else if (process.name.contains('四段')) {
              schedule.yodanProcesses.add(process);
            } else if (process.name.contains('初')) {
              schedule.soeProcesses.add(process);
            } else if (process.name.contains('仲')) {
              schedule.nakaProcesses.add(process);
            } else if (process.name.contains('留')) {
              schedule.tomeProcesses.add(process);
            } else {
              // その他の場合はデフォルトでモト扱い
              schedule.motoProcesses.add(process);
            }
            continue;
          }
        }
        
        // 4. 上槽工程
        if (process.type == ProcessType.pressing) {
          final pressDateStr = DateFormat('yyyy-MM-dd').format(process.date);
          if (pressDateStr == dateStr) {
            schedule.pressingProcesses.add(process);
            continue;
          }
        }
      }
    }
    
    return schedule;
  }
}