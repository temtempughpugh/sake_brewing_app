import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';
import 'package:sake_brewing_app/screens/jungo_detail_screen.dart';
import 'package:sake_brewing_app/screens/dekoji_distribution_screen.dart';

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
    final moriProcesses = _getKojiProcessesForDate(jungoList, _selectedDate, 'mori');
    final hikomiProcesses = _getKojiProcessesForDate(jungoList, _selectedDate, 'hikomi');
    final dekojiProcesses = _getKojiProcessesForDate(jungoList, _selectedDate, 'dekoji');
    
    // 麹工程がない場合のフラグ
    final hasNoKojiProcesses = moriProcesses.isEmpty && hikomiProcesses.isEmpty && dekojiProcesses.isEmpty;
    
    // 全体の重量
    final moriTotalWeight = moriProcesses.fold<double>(0, (sum, p) => sum + p.amount);
    final hikomiTotalWeight = hikomiProcesses.fold<double>(0, (sum, p) => sum + p.amount);
    final dekojiTotalWeight = dekojiProcesses.fold<double>(0, (sum, p) => sum + p.amount);
    
    // 日付フォーマッター
    final dateFormat = DateFormat('yyyy年MM月dd日 (E)', 'ja');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('麹工程管理'),
        actions: [
          // 出麹配分画面へのボタンを追加
          if (dekojiProcesses.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.grain),
              tooltip: '出麹配分計算',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DekojiDistributionScreen(
                      selectedDate: _selectedDate,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // 日付選択部分
          Card(
            margin: const EdgeInsets.all(16.0),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
          if (dekojiProcesses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DekojiDistributionScreen(
                        selectedDate: _selectedDate,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: Colors.deepOrange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.grain,
                        color: Colors.deepOrange,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '出麹配分計算',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                          Text(
                            '本日の出麹 ${dekojiProcesses.length}件（${dekojiTotalWeight.toStringAsFixed(1)} kg）',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.deepOrange,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // 麹工程リスト
          Expanded(
            child: hasNoKojiProcesses
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.grain,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '選択した日の麹作業はありません',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 盛り作業
                          if (moriProcesses.isNotEmpty)
                            _buildKojiProcessGroup('盛り作業', moriProcesses, moriTotalWeight, Colors.amber),
                          
                          // 引込み作業  
                          if (hikomiProcesses.isNotEmpty)
                            _buildKojiProcessGroup('引込み作業', hikomiProcesses, hikomiTotalWeight, Colors.orange),
                              
                          // 出麹作業
                          if (dekojiProcesses.isNotEmpty)
                            _buildKojiProcessGroup('出麹作業', dekojiProcesses, dekojiTotalWeight, Colors.deepOrange),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildKojiProcessGroup(String title, List<BrewingProcess> processes, double totalWeight, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー部分
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: color.withOpacity(0.8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16.0),
                topRight: Radius.circular(16.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.grain,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 6.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '合計: ${totalWeight.toStringAsFixed(1)}kg',
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
              return _buildKojiProcessItem(process, color);
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildKojiProcessItem(BrewingProcess process, Color color) {
    final provider = Provider.of<BrewingDataProvider>(context, listen: false);
    final jungo = provider.getJungoById(process.jungoId);
    
    if (jungo == null) {
      return const SizedBox.shrink();
    }
    
    // 完了状態の判定
    final bool isCompleted = process.status == ProcessStatus.completed;
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JungoDetailScreen(jungoId: process.jungoId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // 左側の情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '順号${process.jungoId}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          jungo.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${process.riceType} (${process.ricePct}%)',
                          style: TextStyle(
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${process.amount}kg',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    if (process.memo != null && process.memo!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'メモ: ${process.memo}',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // 完了/未完了トグルスイッチ
              Column(
                children: [
                  Text(
                    isCompleted ? '完了' : '未完了',
                    style: TextStyle(
                      fontSize: 12,
                      color: isCompleted ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Switch(
                    value: isCompleted,
                    onChanged: (value) {
                      final newStatus = value ? ProcessStatus.completed : ProcessStatus.pending;
                      provider.updateProcessStatus(process.jungoId, process.name, newStatus);
                    },
                    activeColor: Colors.green,
                    activeTrackColor: Colors.green.withOpacity(0.3),
                  ),
                ],
              ),
              
              // 詳細アイコン
              IconButton(
                icon: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                ),
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
        ),
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
  
  // 麹工程を取得するヘルパーメソッド
  List<BrewingProcess> _getKojiProcessesForDate(List<JungoData> jungoList, DateTime date, String stage) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    return jungoList.expand((jungo) => jungo.processes).where((process) {
      if (process.type != ProcessType.koji) return false;
      
      if (stage == 'hikomi') {
        final hikomiDate = process.getHikomiDate();
        return DateFormat('yyyy-MM-dd').format(hikomiDate) == dateStr;
      } else if (stage == 'mori') {
        final moriDate = process.getMoriDate();
        return DateFormat('yyyy-MM-dd').format(moriDate) == dateStr;
      } else if (stage == 'dekoji') {
        final dekojiDate = process.getDekojiDate();
        return DateFormat('yyyy-MM-dd').format(dekojiDate) == dateStr;
      }
      
      return false;
    }).toList();
  }
}