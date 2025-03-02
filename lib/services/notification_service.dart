import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  
  static final NotificationService _instance = NotificationService._internal();
  
  factory NotificationService() {
    return _instance;
  }
  
  NotificationService._internal();
  
  Future<void> init() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }
  
  // 翌日の作業をリマインドする通知を設定
  Future<void> scheduleTomorrowReminder(List<BrewingProcess> processes) async {
    if (processes.isEmpty) return;
    
    final tomorrow = tz.TZDateTime.now(tz.local).add(const Duration(days: 1));
    final scheduledTime = tz.TZDateTime(
      tz.local,
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      20, // 夜8時に通知
      0,
    );
    
    // プロセスの種類によって通知メッセージを調整
    String title = '明日の作業リマインダー';
    String processTypeStr = '';
    
    int kojiCount = 0;
    int moromiCount = 0;
    int washingCount = 0;
    int pressingCount = 0;
    int otherCount = 0;
    
    for (var process in processes) {
      switch (process.type) {
        case ProcessType.koji:
          kojiCount++;
          break;
        case ProcessType.moromi:
          moromiCount++;
          break;
        case ProcessType.washing:
          washingCount++;
          break;
        case ProcessType.pressing:
          pressingCount++;
          break;
        case ProcessType.other:
          otherCount++;
          break;
      }
    }
    
    List<String> processStrings = [];
    if (kojiCount > 0) {
      processStrings.add('麹作業 $kojiCount件');
    }
    if (moromiCount > 0) {
      processStrings.add('醪作業 $moromiCount件');
    }
    if (washingCount > 0) {
      processStrings.add('洗米作業 $washingCount件');
    }
    if (pressingCount > 0) {
      processStrings.add('上槽作業 $pressingCount件');
    }
    if (otherCount > 0) {
      processStrings.add('その他 $otherCount件');
    }
    
    String body = '明日の予定作業: ${processStrings.join('、')}';
    
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      title,
      body,
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          '作業リマインダー',
          channelDescription: '翌日の作業をお知らせします',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
  
  // 当日の作業通知（朝に送信）
  Future<void> scheduleTodayReminder(List<BrewingProcess> processes) async {
    if (processes.isEmpty) return;
    
    final today = tz.TZDateTime.now(tz.local);
    final scheduledTime = tz.TZDateTime(
      tz.local,
      today.year,
      today.month,
      today.day,
      7, // 朝7時に通知
      0,
    );
    
    // 現在時刻が既に7時を過ぎている場合は通知をスキップ
    if (today.hour >= 7) return;
    
    String title = '本日の作業があります';
    
    int kojiCount = 0;
    int moromiCount = 0;
    int washingCount = 0;
    int pressingCount = 0;
    int otherCount = 0;
    
    for (var process in processes) {
      switch (process.type) {
        case ProcessType.koji:
          kojiCount++;
          break;
        case ProcessType.moromi:
          moromiCount++;
          break;
        case ProcessType.washing:
          washingCount++;
          break;
        case ProcessType.pressing:
          pressingCount++;
          break;
        case ProcessType.other:
          otherCount++;
          break;
      }
    }
    
    List<String> processStrings = [];
    if (kojiCount > 0) {
      processStrings.add('麹作業 $kojiCount件');
    }
    if (moromiCount > 0) {
      processStrings.add('醪作業 $moromiCount件');
    }
    if (washingCount > 0) {
      processStrings.add('洗米作業 $washingCount件');
    }
    if (pressingCount > 0) {
      processStrings.add('上槽作業 $pressingCount件');
    }
    if (otherCount > 0) {
      processStrings.add('その他 $otherCount件');
    }
    
    String body = '本日の作業: ${processStrings.join('、')}';
    
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      1,
      title,
      body,
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'today_reminder',
          '今日の作業',
          channelDescription: '本日の作業をお知らせします',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
  
  // 重要なタスクの通知（例：上槽直前のリマインド）
  Future<void> scheduleImportantTaskReminder(BrewingProcess process) async {
    // 上槽予定の1時間前に通知
    if (process.type == ProcessType.pressing) {
      final pressTime = tz.TZDateTime.from(process.date, tz.local);
      final reminderTime = pressTime.subtract(const Duration(hours: 1));
      
      // 既に時間が過ぎていたら通知しない
      if (reminderTime.isBefore(tz.TZDateTime.now(tz.local))) {
        return;
      }
      
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        process.jungoId * 100 + 2, // ユニークなID
        '上槽作業が近づいています',
        '順号${process.jungoId}の上槽作業が1時間後に予定されています',
        reminderTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'important_task',
            '重要作業リマインダー',
            channelDescription: '重要な作業をお知らせします',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
  
  // 全ての通知をキャンセル
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
}