// lib/models/rice_data.dart
import 'dart:convert';

// 白米ロットモデル
class RiceData {
  final String lotId;       // 自動生成のロットID
  final String riceType;    // 品種
  final String origin;      // 産地
  final DateTime? arrivalDate; // 入荷日（任意）
  final String? polishingNo;   // 精米ナンバー（任意）
  final double moisture;    // 白米水分（%）
  final bool isNew;         // 新米か古米か（デフォルトは新米=true）
  final List<RiceWashingData> washingRecords; // このロットの洗米記録リスト
  
  // コンストラクタ
  RiceData({
    required this.lotId,
    required this.riceType,
    required this.origin,
    this.arrivalDate,
    this.polishingNo,
    required this.moisture,
    this.isNew = true,
    required this.washingRecords,
  });
  
  // JSON変換メソッド
  Map<String, dynamic> toJson() {
    return {
      'lotId': lotId,
      'riceType': riceType,
      'origin': origin,
      'arrivalDate': arrivalDate?.millisecondsSinceEpoch,
      'polishingNo': polishingNo,
      'moisture': moisture,
      'isNew': isNew,
      'washingRecords': washingRecords.map((r) => r.toJson()).toList(),
    };
  }
  
  // JSONからオブジェクトを作成
  factory RiceData.fromJson(Map<String, dynamic> json) {
    return RiceData(
      lotId: json['lotId'],
      riceType: json['riceType'],
      origin: json['origin'],
      arrivalDate: json['arrivalDate'] != null ? 
        DateTime.fromMillisecondsSinceEpoch(json['arrivalDate']) : null,
      polishingNo: json['polishingNo'],
      moisture: json['moisture'],
      isNew: json['isNew'],
      washingRecords: (json['washingRecords'] as List)
        .map((r) => RiceWashingData.fromJson(r))
        .toList(),
    );
  }
}

// 洗米詳細データモデル
class RiceWashingData {
  final DateTime date;       // 洗米日
  final int minutes;         // 分
  final int seconds;         // 秒
  final double absorptionRate; // 吸水率（%）
  final double batchWeight;  // 1バッチ重量(kg)
  final int batchMode;       // バッチ送りモード（1-4）
  
  // コンストラクタ
  RiceWashingData({
    required this.date,
    required this.minutes,
    required this.seconds,
    required this.absorptionRate,
    required this.batchWeight,
    required this.batchMode,
  });
  
  // JSON変換メソッド
  Map<String, dynamic> toJson() {
    return {
      'date': date.millisecondsSinceEpoch,
      'minutes': minutes,
      'seconds': seconds,
      'absorptionRate': absorptionRate,
      'batchWeight': batchWeight,
      'batchMode': batchMode,
    };
  }
  
  // JSONからオブジェクトを作成
  factory RiceWashingData.fromJson(Map<String, dynamic> json) {
    return RiceWashingData(
      date: DateTime.fromMillisecondsSinceEpoch(json['date']),
      minutes: json['minutes'],
      seconds: json['seconds'],
      absorptionRate: json['absorptionRate'],
      batchWeight: json['batchWeight'],
      batchMode: json['batchMode'],
    );
  }
}