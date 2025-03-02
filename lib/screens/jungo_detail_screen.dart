import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';
import 'package:sake_brewing_app/screens/tank_management_screen.dart';
import 'package:fl_chart/fl_chart.dart';

class JungoDetailScreen extends StatefulWidget {
  final int jungoId;

  const JungoDetailScreen({
    super.key, 
    required this.jungoId,
  });

  @override
  State<JungoDetailScreen> createState() => _JungoDetailScreenState();
}

class _JungoDetailScreenState extends State<JungoDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BrewingDataProvider>(context);
    final jungoData = provider.getJungoById(widget.jungoId);
    
    if (jungoData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('順号詳細'),
        ),
        body: const Center(
          child: Text('データが見つかりません'),
        ),
      );
    }
    
    final now = DateTime.now();
    final isToday = DateFormat('yyyy-MM-dd').format(now) == 
                    DateFormat('yyyy-MM-dd').format(jungoData.startDate);
    
    // プロセスを日付順にソート
    final sortedProcesses = List<BrewingProcess>.from(jungoData.processes)
      ..sort((a, b) => a.date.compareTo(b.date));
      
    return Scaffold(
      appBar: AppBar(
        title: Text('工程タイムライン (順号${jungoData.jungoId})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TankManagementScreen(jungoId: jungoData.jungoId),
                ),
              );
            },
            tooltip: 'タンク管理',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 基本情報カード
              _buildBasicInfoCard(jungoData, isToday),
              
              const SizedBox(height: 24),
              
              // 工程タイムライン
              const Text(
                'タイムライン',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // タイムライン
              ...sortedProcesses.map((process) => 
                _buildTimelineItem(context, process, sortedProcesses.indexOf(process) == 0)
              ).toList(),
              
              // データがあれば温度・ボーメ推移グラフを表示
              if (jungoData.records.isNotEmpty) ...[
                const SizedBox(height: 24),
                
                const Text(
                  '醪温度・ボーメ推移',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                _buildTempBaumeChart(jungoData),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBasicInfoCard(JungoData jungo, bool isToday) {
    final dayCount = jungo.currentDayCount;
    final totalDays = jungo.totalDayCount;
    
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${jungo.name} / 順号${jungo.jungoId}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'タンク: ${jungo.tankNo}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '製法区分: ${jungo.type}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '留日: ${_formatDate(jungo.startDate)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '上槽予定: ${_formatDate(jungo.endDate)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '総日数: $totalDays日間',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '仕込規模: ${jungo.size}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 進捗バー
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '進捗: ${dayCount}日目 / $totalDays日間',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: dayCount / totalDays,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTimelineItem(BuildContext context, BrewingProcess process, bool isFirst) {
    final today = DateTime.now();
    final isToday = DateFormat('yyyy-MM-dd').format(today) == 
                    DateFormat('yyyy-MM-dd').format(process.date);
    
    Color dotColor;
    Color cardColor;
    double dotSize;
    double lineWidth;
    
    // 工程タイプに基づく色
    switch (process.type) {
      case ProcessType.koji:
        dotColor = Colors.amber;
        cardColor = const Color(0xFFfef9e7);
        break;
      case ProcessType.moromi:
        dotColor = Colors.blue;
        cardColor = const Color(0xFFebf5fb);
        break;
      case ProcessType.washing:
        dotColor = Colors.cyan;
        cardColor = const Color(0xFFe0f7fa);
        break;
      case ProcessType.pressing:
        dotColor = Colors.purple;
        cardColor = const Color(0xFFf3e5f5);
        break;
      case ProcessType.other:
        dotColor = Colors.teal;
        cardColor = const Color(0xFFE0F2F1);
        break;
    }
    
    // 当日の工程は強調表示
    if (isToday) {
      dotSize = 24;
      lineWidth = 3;
      dotColor = Colors.red;
      cardColor = const Color(0xFFfadbd8);
    } else {
      dotSize = 16;
      lineWidth = 2;
    }
    
    // 年を含む日付フォーマット
    final fullDateFormat = DateFormat('yyyy年MM月dd日');
    
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイムラインの垂直線と丸印
          SizedBox(
            width: 50,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 最初の要素以外に上線を表示
                if (!isFirst)
                  Positioned(
                    top: 0,
                    bottom: dotSize / 2,
                    child: Container(
                      width: lineWidth,
                      color: Colors.grey.shade300,
                    ),
                  ),
                
                // 下線
                Positioned(
                  top: dotSize / 2,
                  bottom: 0,
                  child: Container(
                    width: lineWidth,
                    color: Colors.grey.shade300,
                  ),
                ),
                
                // 丸印
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: isToday 
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          
          // 工程の情報カード
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Card(
                color: cardColor,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${process.name} (${fullDateFormat.format(process.date)})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday ? Colors.red : Colors.black87,
                            ),
                          ),
                          if (isToday && process.status != ProcessStatus.completed)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('完了'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                _markProcessAsCompleted(process);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${process.riceType} (${process.ricePct}%) / ${process.amount}kg',
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (process.memo != null && process.memo!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'メモ: ${process.memo}',
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
      return const SizedBox.shrink();
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
    
    return SizedBox(
      height: 300,
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
    );
  }
  
  String _formatDate(DateTime date) {
    return DateFormat('MM月dd日').format(date);
  }
  
  void _markProcessAsCompleted(BrewingProcess process) {
    final provider = Provider.of<BrewingDataProvider>(context, listen: false);
    provider.updateProcessStatus(process.jungoId, process.name, ProcessStatus.completed);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${process.name}を完了しました')),
    );
  }
}