import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';
import 'package:sake_brewing_app/screens/tank_management_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

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
              
              // 仕込み配合表
              _buildBrewingCompositionTable(jungoData),
              
              const SizedBox(height: 24),
              
              // 工程タイムライン
              Text(
                'タイムライン',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
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
                
                Text(
                  '醪温度・ボーメ推移',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                _buildTempBaumeChart(jungoData),
              ],
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBasicInfoCard(JungoData jungo, bool isToday) {
    final dayCount = jungo.currentDayCount;
    final totalDays = jungo.totalDayCount;
    final now = DateTime.now();
    
    // 各工程の日付特定
    DateTime? motoWorkDate;
    DateTime? firstProcessWashingDate;
    DateTime? soeDate;
    DateTime? nakiDate;
    DateTime? tomeDate;
    bool hasMoto = false;
    bool hasFirstProcess = false;
    
    // 状態の判定
    bool isShubo = false;
    bool isBrewing = false;
    bool isMoromi = now.isAfter(jungo.startDate.add(const Duration(days: 1))) && 
                   now.isBefore(jungo.endDate);
    bool isCompleted = now.isAfter(jungo.endDate);
    
    // 仕込み段階
    int brewingStage = 0;
    
    for (var process in jungo.processes) {
      // モト系工程の検出
      if (process.name.toLowerCase().contains('モト')) {
        hasMoto = true;
        if (process.type == ProcessType.moromi) {
          motoWorkDate = process.getWorkDate();
        }
      }
      
      // 初掛/添掛の検出
      if ((process.name.toLowerCase().contains('初') || 
           process.name.toLowerCase().contains('添')) && 
          process.type == ProcessType.moromi) {
        hasFirstProcess = true;
        firstProcessWashingDate = process.washingDate;
        soeDate = process.getWorkDate();
      }
      
      // 仲掛の検出
      if (process.name.toLowerCase().contains('仲') && 
          process.type == ProcessType.moromi) {
        nakiDate = process.getWorkDate();
      }
      
      // 留掛の検出
      if (process.name.toLowerCase().contains('留') && 
          process.type == ProcessType.moromi) {
        tomeDate = process.getWorkDate();
      }
    }
    
    // 酒母状態の判定
    if (hasMoto && hasFirstProcess && motoWorkDate != null && firstProcessWashingDate != null) {
      isShubo = now.isAfter(motoWorkDate) && now.isBefore(firstProcessWashingDate.add(const Duration(days: 1)));
    }
    
    // 仕込み中状態の判定
    if (soeDate != null && tomeDate != null) {
      isBrewing = now.isAfter(soeDate.subtract(const Duration(days: 1))) && 
                  now.isBefore(tomeDate.add(const Duration(days: 1)));
      
      // 仕込み段階の判定
      if (isBrewing) {
        final nowStr = DateFormat('yyyy-MM-dd').format(now);
        
        if (soeDate != null && DateFormat('yyyy-MM-dd').format(soeDate) == nowStr) {
          brewingStage = 1; // 添
        } else if (soeDate != null && 
                  DateFormat('yyyy-MM-dd').format(soeDate.add(const Duration(days: 1))) == nowStr) {
          brewingStage = 2; // 踊（添の翌日）
        } else if (nakiDate != null && DateFormat('yyyy-MM-dd').format(nakiDate) == nowStr) {
          brewingStage = 3; // 仲
        } else if (tomeDate != null && DateFormat('yyyy-MM-dd').format(tomeDate) == nowStr) {
          brewingStage = 4; // 留
        }
      }
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${jungo.name} / 順号${jungo.jungoId}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'タンク: ${jungo.tankNo}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem('製法区分', jungo.type),
                ),
                Expanded(
                  child: _buildInfoItem('仕込規模', '${jungo.size} kg'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    isShubo ? 'モト掛日' : '留日', 
                    isShubo && motoWorkDate != null 
                      ? _formatDate(motoWorkDate)
                      : _formatDate(jungo.startDate)
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    isShubo ? 'モト卸予定' : '上槽予定', 
                    isShubo && firstProcessWashingDate != null 
                      ? _formatDate(firstProcessWashingDate)
                      : _formatDate(jungo.endDate)
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 進捗バー
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isShubo && motoWorkDate != null && firstProcessWashingDate != null
                    ? '酒母進捗: ${now.difference(motoWorkDate).inDays}日目 / ${max(1, firstProcessWashingDate.difference(motoWorkDate).inDays + 1)}日間'
                    : isBrewing
                      ? '仕込み段階: ${brewingStage}/4'
                      : '進捗: ${dayCount}日目 / ${totalDays}日間',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                isBrewing 
                  // 仕込み中は4段階表示
                  ? Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  color: brewingStage >= 1 
                                    ? Theme.of(context).colorScheme.primary 
                                    : Colors.grey.shade200,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    bottomLeft: Radius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                height: 12,
                                color: brewingStage >= 2 
                                  ? Theme.of(context).colorScheme.primary.withOpacity(0.8) 
                                  : Colors.grey.shade200,
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                height: 12,
                                color: brewingStage >= 3 
                                  ? Theme.of(context).colorScheme.secondary.withOpacity(0.8) 
                                  : Colors.grey.shade200,
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  color: brewingStage >= 4 
                                    ? Theme.of(context).colorScheme.secondary 
                                    : Colors.grey.shade200,
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(6),
                                    bottomRight: Radius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('添', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                            Text('踊', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                            Text('仲', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                            Text('留', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          ],
                        ),
                      ],
                    )
                  : Stack(
                      children: [
                        Container(
                          height: 12,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: isShubo && motoWorkDate != null && firstProcessWashingDate != null
                            // 酒母期間はモト掛からモト卸までの進捗
                            ? (now.difference(motoWorkDate).inDays) / 
                               max(1, firstProcessWashingDate.difference(motoWorkDate).inDays + 1)
                            // 醪期間は留日から上槽日までの進捗
                            : dayCount / max(1, totalDays),
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.secondary,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
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
  
  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  // 仕込み配合表の作成
  Widget _buildBrewingCompositionTable(JungoData jungo) {
    // プロセスから配合情報を集計
    Map<String, double> kojiAmounts = {'モト': 0, '添': 0, '仲': 0, '留': 0, '四段': 0};
    Map<String, double> kakeAmounts = {'モト': 0, '添': 0, '仲': 0, '留': 0, '四段': 0};
    
    for (var process in jungo.processes) {
      String stage = '';
      
      if (process.name.contains('モト')) {
        stage = 'モト';
      } else if (process.name.contains('添') || process.name.contains('初掛') || process.name.contains('初麹')) {
        // 「添」または「初掛」または「初麹」を含む工程は全て「添」に分類
        stage = '添';
      } else if (process.name.contains('仲')) {
        stage = '仲';
      } else if (process.name.contains('留')) {
        stage = '留';
      } else if (process.name.contains('四段')) {
        stage = '四段';
      } else {
        // デバッグ出力を追加して、どの工程がスキップされているかを確認
        print('スキップされた工程: ${process.name} (タイプ: ${process.type})');
        continue; // 該当しない工程はスキップ
      }
        
        if (process.type == ProcessType.koji) {
          kojiAmounts[stage] = (kojiAmounts[stage] ?? 0) + process.amount;
        } else if (process.type == ProcessType.moromi || process.type == ProcessType.other) {
          kakeAmounts[stage] = (kakeAmounts[stage] ?? 0) + process.amount;
        }
      }
      
      // 合計計算
      final totalKoji = kojiAmounts.values.fold<double>(0, (sum, val) => sum + val);
      final totalKake = kakeAmounts.values.fold<double>(0, (sum, val) => sum + val);
      final totalRice = totalKoji + totalKake;
      
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '仕込み配合表 (kg)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  border: TableBorder.all(
                    color: Colors.grey.shade300,
                    width: 1,
                    style: BorderStyle.solid,
                  ),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: const {
                    0: FixedColumnWidth(80),
                    1: FixedColumnWidth(70),
                    2: FixedColumnWidth(70),
                    3: FixedColumnWidth(70),
                    4: FixedColumnWidth(70),
                    5: FixedColumnWidth(70),
                    6: FixedColumnWidth(70),
                  },
                  children: [
                    // ヘッダー行
                    TableRow(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      children: [
                        _buildTableHeader(''),
                        _buildTableHeader('モト'),
                        _buildTableHeader('添'),
                        _buildTableHeader('仲'),
                        _buildTableHeader('留'),
                        _buildTableHeader('四段'),
                        _buildTableHeader('合計'),
                      ],
                    ),
                    // 麹米行
                    TableRow(
                      children: [
                        _buildTableCell('麹米', isHeader: true),
                        _buildTableCell('${kojiAmounts['モト']!.toStringAsFixed(0)}'),
                        _buildTableCell('${kojiAmounts['添']!.toStringAsFixed(0)}'),
                        _buildTableCell('${kojiAmounts['仲']!.toStringAsFixed(0)}'),
                        _buildTableCell('${kojiAmounts['留']!.toStringAsFixed(0)}'),
                        _buildTableCell('${kojiAmounts['四段']!.toStringAsFixed(0)}'),
                        _buildTableCell('${totalKoji.toStringAsFixed(0)}', isBold: true),
                      ],
                    ),
                    // 掛米行
                    TableRow(
                      children: [
                        _buildTableCell('掛米', isHeader: true),
                        _buildTableCell('${kakeAmounts['モト']!.toStringAsFixed(0)}'),
                        _buildTableCell('${kakeAmounts['添']!.toStringAsFixed(0)}'),
                        _buildTableCell('${kakeAmounts['仲']!.toStringAsFixed(0)}'),
                        _buildTableCell('${kakeAmounts['留']!.toStringAsFixed(0)}'),
                        _buildTableCell('${kakeAmounts['四段']!.toStringAsFixed(0)}'),
                        _buildTableCell('${totalKake.toStringAsFixed(0)}', isBold: true),
                      ],
                    ),
                    // 総米行
                    TableRow(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      children: [
                        _buildTableCell('総米', isHeader: true, isBold: true),
                        _buildTableCell('${(kojiAmounts['モト']! + kakeAmounts['モト']!).toStringAsFixed(0)}', isBold: true),
                        _buildTableCell('${(kojiAmounts['添']! + kakeAmounts['添']!).toStringAsFixed(0)}', isBold: true),
                        _buildTableCell('${(kojiAmounts['仲']! + kakeAmounts['仲']!).toStringAsFixed(0)}', isBold: true),
                        _buildTableCell('${(kojiAmounts['留']! + kakeAmounts['留']!).toStringAsFixed(0)}', isBold: true),
                        _buildTableCell('${(kojiAmounts['四段']! + kakeAmounts['四段']!).toStringAsFixed(0)}', isBold: true),
                        _buildTableCell('${totalRice.toStringAsFixed(0)}', isBold: true, isHighlighted: true),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildTableHeader(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, bool isBold = false, bool isHighlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      color: isHighlighted ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : null,
      child: Text(
        text,
        textAlign: isHeader ? TextAlign.left : TextAlign.center,
        style: TextStyle(
          color: isHighlighted 
              ? Theme.of(context).colorScheme.primary
              : Colors.black87,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }
  
  Widget _buildTimelineItem(BuildContext context, BrewingProcess process, bool isFirst) {
  final today = DateTime.now();
  final isToday = DateFormat('yyyy-MM-dd').format(today) == 
                  DateFormat('yyyy-MM-dd').format(process.date);
  
  Color dotColor;
  double dotSize = 16;
  double lineWidth = 2;
  
  // 工程タイプに基づく色
  switch (process.type) {
    case ProcessType.koji:
      dotColor = const Color(0xFFF1C40F); // 金色
      break;
    case ProcessType.moromi:
      dotColor = Theme.of(context).colorScheme.primary; // メインカラー
      break;
    case ProcessType.washing:
      dotColor = const Color(0xFF1ABC9C); // 水色
      break;
    case ProcessType.pressing:
      dotColor = const Color(0xFF9B59B6); // 紫色
      break;
    case ProcessType.other:
      dotColor = const Color(0xFF2ECC71); // 緑色
      break;
  }
  
  // 当日の工程は強調表示
  if (isToday) {
    dotSize = 24;
    lineWidth = 3;
    dotColor = const Color(0xFFE74C3C); // 赤色
  }
  
  // 年を含む日付フォーマット
  final fullDateFormat = DateFormat('yyyy年MM月dd日');
  
  // 工程タイプに応じた日付ラベル
  String dateLabel;
  if (process.type == ProcessType.koji) {
    if (DateFormat('yyyy-MM-dd').format(process.getHikomiDate()) == DateFormat('yyyy-MM-dd').format(process.date)) {
      dateLabel = '引込み日: ${fullDateFormat.format(process.date)}';
    } else if (DateFormat('yyyy-MM-dd').format(process.getMoriDate()) == DateFormat('yyyy-MM-dd').format(process.date)) {
      dateLabel = '盛り日: ${fullDateFormat.format(process.date)}';
    } else if (DateFormat('yyyy-MM-dd').format(process.getDekojiDate()) == DateFormat('yyyy-MM-dd').format(process.date)) {
      dateLabel = '出麹日: ${fullDateFormat.format(process.date)}';
    } else {
      dateLabel = '洗米日: ${fullDateFormat.format(process.washingDate)}';
    }
  } else if (process.type == ProcessType.washing) {
    dateLabel = '洗米日: ${fullDateFormat.format(process.washingDate)}';
  } else if (process.type == ProcessType.moromi) {
    dateLabel = '仕込み日: ${fullDateFormat.format(process.getWorkDate())}';
  } else if (process.type == ProcessType.pressing) {
    dateLabel = '上槽日: ${fullDateFormat.format(process.date)}';
  } else {
    dateLabel = '作業日: ${fullDateFormat.format(process.date)}';
  }
  
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // 工程の情報カード
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: dotColor.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            process.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday ? dotColor : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isToday && process.status != ProcessStatus.completed)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('完了'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2ECC71),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () {
                              _markProcessAsCompleted(process);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${process.riceType} (${process.ricePct}%) / ${process.amount}kg',
                      style: const TextStyle(
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (process.memo != null && process.memo!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'メモ: ${process.memo}',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
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
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
  
  String _formatDate(DateTime date) {
    return DateFormat('yyyy年MM月dd日').format(date);
  }
  
  void _markProcessAsCompleted(BrewingProcess process) {
    final provider = Provider.of<BrewingDataProvider>(context, listen: false);
    provider.updateProcessStatus(process.jungoId, process.name, ProcessStatus.completed);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${process.name}を完了しました')),
    );
  }
}