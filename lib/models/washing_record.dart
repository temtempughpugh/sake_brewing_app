// lib/models/washing_record.dart
import 'dart:convert';

class WashingRecord {
  final DateTime date;           // 記録日
  final List<String> riceLotIds; // 使用した白米ロットID（最大3つ）
  final double absorptionRate;   // 吸水率（%）
  final String? memo;            // メモ
  final RiceEvaluation riceEvaluation;    // 米評価
  final RiceEvaluation steamedEvaluation; // 蒸米評価
  
  // コンストラクタ
  WashingRecord({
    required this.date,
    required this.riceLotIds,
    required this.absorptionRate,
    this.memo,
    required this.riceEvaluation,
    required this.steamedEvaluation,
  });
  
  // JSON変換メソッド
  Map<String, dynamic> toJson() {
    return {
      'date': date.millisecondsSinceEpoch,
      'riceLotIds': riceLotIds,
      'absorptionRate': absorptionRate,
      'memo': memo,
      'riceEvaluation': riceEvaluation.index,
      'steamedEvaluation': steamedEvaluation.index,
    };
  }
  
  // JSONからオブジェクトを作成
  factory WashingRecord.fromJson(Map<String, dynamic> json) {
    return WashingRecord(
      date: DateTime.fromMillisecondsSinceEpoch(json['date']),
      riceLotIds: List<String>.from(json['riceLotIds']),
      absorptionRate: json['absorptionRate'],
      memo: json['memo'],
      riceEvaluation: RiceEvaluation.values[json['riceEvaluation']],
      steamedEvaluation: RiceEvaluation.values[json['steamedEvaluation']],
    );
  }
}

// 評価用の列挙型
enum RiceEvaluation {
  excellent, // ◎
  good,      // ◯
  fair,      // △
  poor,      // ×
  unknown    // ？
}

// 評価を文字列に変換するための拡張メソッド
extension RiceEvaluationExtension on RiceEvaluation {
  String toDisplayString() {
    switch (this) {
      case RiceEvaluation.excellent: return '◎';
      case RiceEvaluation.good: return '◯';
      case RiceEvaluation.fair: return '△';
      case RiceEvaluation.poor: return '×';
      case RiceEvaluation.unknown: return '？';
    }
  }
  
  // 表示文字列から評価を取得するための静的メソッド
  static RiceEvaluation fromDisplayString(String displayString) {
    switch (displayString) {
      case '◎': return RiceEvaluation.excellent;
      case '◯': return RiceEvaluation.good;
      case '△': return RiceEvaluation.fair;
      case '×': return RiceEvaluation.poor;
      case '？': return RiceEvaluation.unknown;
      default: return RiceEvaluation.unknown;
    }
  }
}