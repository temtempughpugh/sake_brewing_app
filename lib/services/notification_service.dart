import 'package:sake_brewing_app/models/brewing_data.dart';

// 簡易版の通知サービス（実際には通知を送信しません）
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  
  factory NotificationService() {
    return _instance;
  }
  
  NotificationService._internal();
  
  // 初期化（何もしません）
  Future<void> init() async {
    print('通知サービス: 初期化しました (ダミー)');
  }
  
  // 翌日の作業リマインダー（実装なし）
  Future<void> scheduleTomorrowReminder(List<BrewingProcess> processes) async {
    print('通知サービス: 翌日の作業リマインダー (${processes.length}件) (ダミー)');
  }
  
  // 当日の作業通知（実装なし）
  Future<void> scheduleTodayReminder(List<BrewingProcess> processes) async {
    print('通知サービス: 当日の作業通知 (${processes.length}件) (ダミー)');
  }
  
  // 重要なタスクの通知（実装なし）
  Future<void> scheduleImportantTaskReminder(BrewingProcess process) async {
    print('通知サービス: 重要な作業リマインダー (${process.name}) (ダミー)');
  }
  
  // 全ての通知をキャンセル（実装なし）
  Future<void> cancelAllNotifications() async {
    print('通知サービス: 全ての通知をキャンセルしました (ダミー)');
  }
}