import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';
import 'package:fl_chart/fl_chart.dart';

class TankManagementScreen extends StatefulWidget {
  final int jungoId;

  const TankManagementScreen({
    super.key, 
    required this.jungoId,
  });

  @override
  State<TankManagementScreen> createState() => _TankManagementScreenState();
}

class _TankManagementScreenState extends State<TankManagementScreen> {
  final _temperatureController = TextEditingController();
  final _baumeController = TextEditingController();
  final _memoController = TextEditingController();
  
  @override
  void dispose() {
    _temperatureController.dispose();
    _baumeController.dispose();
    _memoController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BrewingDataProvider>(context);
    final jungoData = provider.getJungoById(widget.jungoId);
    
    if (jungoData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('タンク管理'),
        ),
        body: const Center(
          child: Text('データが見つかりません'),
        ),
      );
    }
    
    // レコードを日付順にソート
    final sortedRecords = List<TankRecord>.from(jungoData.records)
      ..sort((a, b) => b.date.compareTo(a.date)); // 新しい順
      
    return Scaffold(
      appBar: AppBar(
        title: Text('醪・タンク管理 (${jungoData.tankNo})'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 温度・ボーメグラフ
              _buildTempBaumeChart(jungoData),
              
              const SizedBox(height: 24),
              
              // タンク情報カード
              _buildTankInfoCard(jungoData),
              
              const SizedBox(height: 24),
              
              // 作業記録フォーム
              _buildRecordForm(jungoData),
              
              const SizedBox(height: 24),
              
              // 記録履歴
              const Text(
                '記録履歴',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              sortedRecords.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('記録がありません'),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sortedRecords.length,
                      itemBuilder: (context, index) {
                        return _buildRecordItem(sortedRecords[index]);
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTempBaumeChart(JungoData jungo) {
    // 日付フォーマッター
    final dateFormat = DateFormat('M/d');
    
    // ソートしたレコード
    final sortedRecords = List<TankRecord>.from(jungo.records)
      ..sort((a, b) => a.date.compareTo(b.date));
      
    if (sortedRecords.isEmpty) {
      return Card(
        child: Container(
          height: 200,
          alignment: Alignment.center,
          child: const Text('データがありません'),
        ),
      );
    }
    
    // 温度データポイント
    final tempSpots = <FlSpot>[];
    // ボーメデータポイント
    final baumeSpots = <FlSpot>[];
    
    // X軸のラベル用日付リスト
    final dates = <DateTime>[];
    
    // データポイントの作成
    for (int i = 0; i < sortedRecords.length; i++) {
      final record = sortedRecords[i];
      
      if (record.temperature != null) {
        tempSpots.add(FlSpot(i.toDouble(), record.temperature!));
      }
      
      if (record.baume != null) {
        baumeSpots.add(FlSpot(i.toDouble(), record.baume!));
      }
      
      dates.add(record.date);
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '醪温度・ボーメ推移',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 5,
                    verticalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= dates.length) {
                            return const Text('');
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              dateFormat.format(dates[index]),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                            ),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                            ),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  minX: 0,
                  maxX: dates.length.toDouble() - 1,
                  minY: 0,
                  maxY: 40, // 温度とボーメの最大値に応じて調整
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.white.withOpacity(0.8),
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((LineBarSpot touchedSpot) {
                          final index = touchedSpot.x.toInt();
                          
                          if (touchedSpot.barIndex == 0) { // 温度
                            return LineTooltipItem(
                              '${dateFormat.format(dates[index])}\n温度: ${touchedSpot.y.toStringAsFixed(1)}℃',
                              const TextStyle(color: Colors.red),
                            );
                          } else { // ボーメ
                            return LineTooltipItem(
                              'ボーメ: ${touchedSpot.y.toStringAsFixed(1)}',
                              const TextStyle(color: Colors.blue),
                            );
                          }
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    // 温度のライン
                    LineChartBarData(
                      spots: tempSpots,
                      isCurved: true,
                      color: Colors.red,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.red,
                            strokeWidth: 1,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(show: false),
                    ),
                    // ボーメのライン
                    LineChartBarData(
                      spots: baumeSpots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.blue,
                            strokeWidth: 1,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('温度', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('ボーメ', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTankInfoCard(JungoData jungo) {
    final startDate = jungo.startDate;
    final endDate = jungo.endDate;
    final currentDayCount = jungo.currentDayCount;
    final totalDayCount = jungo.totalDayCount;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'タンク状況',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(1.2),
              },
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
              children: [
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('開始日'),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('現在日数'),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('予定終了日'),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(DateFormat('MM月dd日').format(startDate)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('$currentDayCount日目 / $totalDayCount日間'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(DateFormat('MM月dd日').format(endDate)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecordForm(JungoData jungo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '作業記録',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _temperatureController,
              decoration: const InputDecoration(
                labelText: '温度 (℃)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _baumeController,
              decoration: const InputDecoration(
                labelText: 'ボーメ度',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: '作業メモ',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('保存'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: () => _saveRecord(jungo),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecordItem(TankRecord record) {
    final dateStr = DateFormat('yyyy年MM月dd日 HH:mm').format(record.date);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateStr,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (record.temperature != null) ...[
                  const Icon(Icons.thermostat, size: 16, color: Colors.red),
                  const SizedBox(width: 4),
                  Text('${record.temperature!.toStringAsFixed(1)}℃'),
                  const SizedBox(width: 16),
                ],
                if (record.baume != null) ...[
                  const Icon(Icons.opacity, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text('${record.baume!.toStringAsFixed(1)}度'),
                ],
              ],
            ),
            if (record.memo != null && record.memo!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(record.memo!),
            ],
          ],
        ),
      ),
    );
  }
  
  void _saveRecord(JungoData jungo) {
    // 入力値を取得
    final tempText = _temperatureController.text.trim();
    final baumeText = _baumeController.text.trim();
    final memo = _memoController.text.trim();
    
    // 温度かボーメはどちらか必須
    if (tempText.isEmpty && baumeText.isEmpty && memo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('温度またはボーメを入力してください')),
      );
      return;
    }
    
    // 値を変換
    double? temperature;
    double? baume;
    
    if (tempText.isNotEmpty) {
      try {
        temperature = double.parse(tempText);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('温度の値が不正です')),
        );
        return;
      }
    }
    
    if (baumeText.isNotEmpty) {
      try {
        baume = double.parse(baumeText);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ボーメの値が不正です')),
        );
        return;
      }
    }
    
    // 記録を追加
    final record = TankRecord(
      date: DateTime.now(),
      temperature: temperature,
      baume: baume,
      memo: memo.isEmpty ? null : memo,
    );
    
    Provider.of<BrewingDataProvider>(context, listen: false)
        .addTankRecord(jungo.jungoId, record);
    
    // フォームをクリア
    _temperatureController.clear();
    _baumeController.clear();
    _memoController.clear();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('記録を保存しました')),
    );
  }
}