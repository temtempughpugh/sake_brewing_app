import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';

/// 麹関連の機能を提供するサービスクラス
class KojiService extends ChangeNotifier {
  final BrewingDataProvider _brewingDataProvider;
  
  KojiService(this._brewingDataProvider);
  
  /// 指定日の出麹プロセスを取得
  List<BrewingProcess> getDekojiProcesses(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    return _brewingDataProvider.jungoList.expand((jungo) => jungo.processes).where((process) {
      // 麹工程で、出麹日が指定日と一致するもの
      if (process.type == ProcessType.koji) {
        final dekojiDate = process.getDekojiDate();
        return DateFormat('yyyy-MM-dd').format(dekojiDate) == dateStr;
      }
      return false;
    }).toList();
  }
  
  /// 出麹配分を計算
  Map<String, double> calculateDistribution(
    List<BrewingProcess> processes, 
    double estimatedKojiRate
  ) {
    // 用途ごとにプロセスをグループ化
    final usageGroups = <String, List<BrewingProcess>>{};
    
    for (var process in processes) {
      final usage = _determineUsage(process.name);
      if (usageGroups.containsKey(usage)) {
        usageGroups[usage]!.add(process);
      } else {
        usageGroups[usage] = [process];
      }
    }
    
    // 用途ごとの合計重量を計算
    final usageWeights = <String, double>{};
    for (var entry in usageGroups.entries) {
      usageWeights[entry.key] = entry.value.fold<double>(
        0, (sum, process) => sum + process.amount);
    }
    
    // 出麹順序を決定
    final order = ['酒母', '添', '仲', '留', '四段', 'その他'];
    final sortedUsages = usageWeights.keys.toList()
      ..sort((a, b) => order.indexOf(a) - order.indexOf(b));
    
    // 各用途の予想出麹重量を計算
    final distribution = <String, double>{};
    for (var usage in sortedUsages) {
      final originalWeight = usageWeights[usage]!;
      final expectedKojiWeight = originalWeight * estimatedKojiRate / 100;
      distribution[usage] = expectedKojiWeight;
    }
    
    return distribution;
  }
  
  /// 出麹歩合を計算して更新
  void updateKojiRates(List<BrewingProcess> processes, double finalWeight) {
    // 合計の元重量を計算
    final totalOriginalWeight = processes.fold<double>(
      0, (sum, process) => sum + process.amount);
    
    // 実際の出麹歩合を計算
    final actualRate = (finalWeight / totalOriginalWeight) * 100;
    
    // 用途ごとの分類
    final usageGroups = <String, List<BrewingProcess>>{};
    for (var process in processes) {
      final usage = _determineUsage(process.name);
      if (usageGroups.containsKey(usage)) {
        usageGroups[usage]!.add(process);
      } else {
        usageGroups[usage] = [process];
      }
    }
    
    // 用途ごとの合計重量を計算
    final usageWeights = <String, double>{};
    for (var entry in usageGroups.entries) {
      usageWeights[entry.key] = entry.value.fold<double>(
        0, (sum, process) => sum + process.amount);
    }
    
    // 用途ごとの比率に基づいて最終重量を配分
    final usageDistribution = <String, double>{};
    for (var entry in usageWeights.entries) {
      usageDistribution[entry.key] = (entry.value / totalOriginalWeight) * finalWeight;
    }
    
    // 各プロセスの出麹歩合と最終重量を更新
    for (var process in processes) {
      // プロセスのデータを更新
      _brewingDataProvider.updateProcessKojiData(
        process.jungoId,
        process.name,
        actualKojiRate: actualRate,
        finalKojiWeight: (process.amount / totalOriginalWeight) * finalWeight,
      );
    }
    
    notifyListeners();
  }
  
  // プロセス名から用途を決定するヘルパーメソッド
  String _determineUsage(String processName) {
    final name = processName.toLowerCase();
    
    if (name.contains('モト')) {
      return '酒母';
    } else if (name.contains('添') || name.contains('初')) {
      return '添';
    } else if (name.contains('仲')) {
      return '仲';
    } else if (name.contains('留')) {
      return '留';
    } else if (name.contains('四段')) {
      return '四段';
    } else {
      return 'その他';
    }
    }
    }