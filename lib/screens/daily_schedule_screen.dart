import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';
import 'package:sake_brewing_app/models/brewing_schedule.dart'; // 拡張メソッドのインポートを追加
import 'package:sake_brewing_app/screens/process_detail_screen.dart';
import 'package:sake_brewing_app/screens/jungo_detail_screen.dart';

class DailyScheduleScreen extends StatefulWidget {
  const DailyScheduleScreen({super.key});

  @override
  State<DailyScheduleScreen> createState() => _DailyScheduleScreenState();
}

class _DailyScheduleScreenState extends State<DailyScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日別醸造スケジュール'),
      ),
      body: Column(
        children: [
          // 日付選択部分
          _buildDateSelector(),
          
          // スケジュール表示部分
          Expanded(
            child: _buildScheduleList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDateSelector() {
    final dateFormat = DateFormat('yyyy年MM月dd日 (E)', 'ja');
    
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: () {
                setState(() {
                  _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                });
              },
            ),
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Text(
                dateFormat.format(_selectedDate),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: () {
                setState(() {
                  _selectedDate = _selectedDate.add(const Duration(days: 1));
                });
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildScheduleList() {
    final provider = Provider.of<BrewingDataProvider>(context);
    
    // 選択日のスケジュールを取得
    final daySchedule = provider.getDailySchedule(_selectedDate);
    
    if (daySchedule.isEmpty) {
      return const Center(
        child: Text('この日の作業予定はありません'),
      );
    }
    
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // 麹工程（盛り）
        if (daySchedule.moriProcesses.isNotEmpty)
          _buildProcessGroup(
            '盛り', 
            daySchedule.moriProcesses.length, 
            daySchedule.moriProcesses,
            Colors.amber,
          ),
          
        // 麹工程（引込み）
        if (daySchedule.hikomiProcesses.isNotEmpty)
          _buildProcessGroup(
            '引込み', 
            daySchedule.hikomiProcesses.length, 
            daySchedule.hikomiProcesses,
            Colors.orange,
          ),
        
        // 麹工程（出麹）
        if (daySchedule.dekojiProcesses.isNotEmpty)
          _buildProcessGroup(
            '出麹', 
            daySchedule.dekojiProcesses.length, 
            daySchedule.dekojiProcesses,
            Colors.deepOrange,
          ),
        
        // 仕込み工程（モト→四段→添→仲→留の順）
        if (daySchedule.motoProcesses.isNotEmpty)
          _buildProcessGroup(
            'モト仕込み', 
            daySchedule.motoProcesses.length, 
            daySchedule.motoProcesses,
            Colors.blue,
          ),
          
        if (daySchedule.yodanProcesses.isNotEmpty)
          _buildProcessGroup(
            '四段', 
            daySchedule.yodanProcesses.length, 
            daySchedule.yodanProcesses,
            Colors.purple,
          ),
          
        if (daySchedule.soeProcesses.isNotEmpty)
          _buildProcessGroup(
            '添仕込み', 
            daySchedule.soeProcesses.length, 
            daySchedule.soeProcesses,
            Colors.blue.shade300,
          ),
          
        if (daySchedule.nakaProcesses.isNotEmpty)
          _buildProcessGroup(
            '仲仕込み', 
            daySchedule.nakaProcesses.length, 
            daySchedule.nakaProcesses,
            Colors.blue.shade700,
          ),
          
        if (daySchedule.tomeProcesses.isNotEmpty)
          _buildProcessGroup(
            '留仕込み', 
            daySchedule.tomeProcesses.length, 
            daySchedule.tomeProcesses,
            Colors.indigo,
          ),
        
        // 洗米工程
        if (daySchedule.washingProcesses.isNotEmpty)
          _buildProcessGroup(
            '洗米', 
            daySchedule.washingProcesses.length, 
            daySchedule.washingProcesses,
            Colors.lightBlue,
          ),
        
        // 上槽工程
        if (daySchedule.pressingProcesses.isNotEmpty)
          _buildProcessGroup(
            '上槽', 
            daySchedule.pressingProcesses.length, 
            daySchedule.pressingProcesses,
            Colors.deepPurple,
          ),
      ],
    );
  }
  
  Widget _buildProcessGroup(String title, int count, List<BrewingProcess> processes, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー部分
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: color.withOpacity(0.8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12.0),
                topRight: Radius.circular(12.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Text(
                    '$count件',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // プロセスリスト
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: processes.length,
            itemBuilder: (context, index) {
              final process = processes[index];
              return _buildProcessItem(process, color);
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildProcessItem(BrewingProcess process, Color color) {
  final provider = Provider.of<BrewingDataProvider>(context, listen: false);
  final jungo = provider.getJungoById(process.jungoId);
  
  if (jungo == null) {
    return const SizedBox.shrink();
  }
  
  // ロット番号生成
  String lotNumber = 'Lot-${jungo.jungoId}-${process.name}-${DateFormat('yyyyMMdd').format(process.date)}';
  
  return ListTile(
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 16.0,
      vertical: 8.0,
    ),
    title: Text(
      '${process.name} (順号${process.jungoId})',
      style: const TextStyle(fontWeight: FontWeight.bold),
      overflow: TextOverflow.ellipsis, // Add overflow handling
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                '${jungo.name} / タンク: ${jungo.tankNo}',
                overflow: TextOverflow.ellipsis, // Add overflow handling
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                '日付: ${DateFormat('yyyy年MM月dd日').format(process.date)}',
                overflow: TextOverflow.ellipsis, // Add overflow handling
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                '${process.riceType} (${process.ricePct}%) / ${process.amount}kg',
                overflow: TextOverflow.ellipsis, // Add overflow handling
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                'ロット番号: $lotNumber', 
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis, // Add overflow handling
              ),
            ),
          ],
        ),
        if (process.memo != null && process.memo!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'メモ: ${process.memo}',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis, // Add overflow handling
                    maxLines: 2, // Limit to 2 lines
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min, // Important!
      children: [
        // 完了/未完了ボタン
        IconButton(
          icon: Icon(
            process.status == ProcessStatus.completed 
                ? Icons.check_circle 
                : Icons.check_circle_outline,
            color: process.status == ProcessStatus.completed 
                ? Colors.green 
                : Colors.grey,
          ),
          onPressed: () {
            final newStatus = process.status == ProcessStatus.completed 
                ? ProcessStatus.pending 
                : ProcessStatus.completed;
            provider.updateProcessStatus(process.jungoId, process.name, newStatus);
          },
          tooltip: process.status == ProcessStatus.completed ? '完了済み' : '完了にする',
        ),
        // 詳細ボタン
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 16),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => JungoDetailScreen(jungoId: process.jungoId),
              ),
            );
          },
        ),
      ],
    ),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => JungoDetailScreen(jungoId: process.jungoId),
        ),
      );
    },
  );
}
  
  // 日付選択ダイアログ
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ja'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
}