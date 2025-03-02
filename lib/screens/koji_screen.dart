import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';

class KojiScreen extends StatefulWidget {
  const KojiScreen({super.key});

  @override
  State<KojiScreen> createState() => _KojiScreenState();
}

class _KojiScreenState extends State<KojiScreen> {
  DateTime _selectedDate = DateTime.now();
  
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BrewingDataProvider>(context);
    final jungoList = provider.jungoList;
    
    // 選択された日付の麹工程を取得
    final kojiProcesses = _getKojiProcessesForDate(jungoList, _selectedDate);
    
    // 日付フォーマッター
    final dateFormat = DateFormat('yyyy年MM月dd日 (E)', 'ja');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('麹工程管理'),
      ),
      body: Column(
        children: [
          // 日付選択部分
          Card(
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
          ),
          
          // 麹工程リスト
          Expanded(
            child: kojiProcesses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.grain,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '選択した日の麹作業はありません',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildKojiProcessList(kojiProcesses),
          ),
        ],
      ),
    );
  }
  
  Widget _buildKojiProcessList(List<KojiProcessItem> kojiProcesses) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDE7),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: const Color(0xFFFFF9C4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '本日の麹作業',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFBC02D),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: kojiProcesses.length,
              itemBuilder: (context, index) {
                return _buildKojiProcessItem(kojiProcesses[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildKojiProcessItem(KojiProcessItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 8.0,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.all(8.0),
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              color: Color(0xFFF39C12),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 12.0,
              ),
              child: Text(
                '${item.processName}（順号${item.jungoId}）: ${item.riceType}',
                style: const TextStyle(
                  color: Color(0xFFE65100),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              '${item.amount}kg',
              style: const TextStyle(
                color: Color(0xFFE65100),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (item.status != ProcessStatus.completed)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () => _markAsCompleted(item),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('完了'),
              ),
            ),
        ],
      ),
    );
  }
  
  // 日付選択ダイアログを表示
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
  
  // 指定された日付の麹工程を取得
  List<KojiProcessItem> _getKojiProcessesForDate(List<JungoData> jungoList, DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    List<KojiProcessItem> result = [];
    
    for (var jungo in jungoList) {
      for (var process in jungo.processes) {
        if (process.type == ProcessType.koji && 
            DateFormat('yyyy-MM-dd').format(process.date) == dateStr) {
          result.add(KojiProcessItem(
            jungoId: jungo.jungoId,
            processName: process.name,
            riceType: process.riceType,
            amount: process.amount,
            status: process.status,
            process: process,
          ));
        }
      }
    }
    
    return result;
  }
  
  // 工程を完了としてマーク
  void _markAsCompleted(KojiProcessItem item) {
    final provider = Provider.of<BrewingDataProvider>(context, listen: false);
    provider.updateProcessStatus(item.jungoId, item.processName, ProcessStatus.completed);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「${item.processName}」を完了しました')),
    );
  }
}

// 麹工程表示用のデータクラス
class KojiProcessItem {
  final int jungoId;
  final String processName;
  final String riceType;
  final double amount;
  final ProcessStatus status;
  final BrewingProcess process;
  
  KojiProcessItem({
    required this.jungoId,
    required this.processName,
    required this.riceType,
    required this.amount,
    required this.status,
    required this.process,
  });
}