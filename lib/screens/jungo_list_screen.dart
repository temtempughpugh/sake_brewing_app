import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';
import 'package:sake_brewing_app/screens/jungo_detail_screen.dart';

class JungoListScreen extends StatefulWidget {
  const JungoListScreen({super.key});

  @override
  State<JungoListScreen> createState() => _JungoListScreenState();
}

class _JungoListScreenState extends State<JungoListScreen> {
  String _searchQuery = '';
  String _filterStatus = 'all'; // 'all', 'active', 'completed'
  
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BrewingDataProvider>(context);
    final jungoList = provider.jungoList;
    
    // 検索とフィルタリング
    final filteredList = jungoList.where((jungo) {
      // 検索条件
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!jungo.name.toLowerCase().contains(query) &&
            !jungo.jungoId.toString().contains(query) &&
            !jungo.tankNo.toString().contains(query)) {
          return false;
        }
      }
      
      // ステータスフィルター
      if (_filterStatus == 'active') {
        final today = DateTime.now();
        return today.isAfter(jungo.startDate) && 
               today.isBefore(jungo.endDate);
      } else if (_filterStatus == 'completed') {
        final today = DateTime.now();
        return today.isAfter(jungo.endDate);
      }
      
      return true;
    }).toList();
    
    // 順号でソート
    filteredList.sort((a, b) => a.jungoId.compareTo(b.jungoId));
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('順号一覧'),
      ),
      body: Column(
        children: [
          // 検索バー
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: '順号検索...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade200,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // フィルターチップ
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildFilterChip('全て', 'all'),
                const SizedBox(width: 10),
                _buildFilterChip('進行中', 'active'),
                const SizedBox(width: 10),
                _buildFilterChip('完了', 'completed'),
                const Spacer(),
                // 新規作成ボタン（実装はしていません）
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('新規作成機能は実装されていません')),
                      );
                    },
                    tooltip: '新規作成',
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 順号リスト
          Expanded(
            child: filteredList.isEmpty
                ? const Center(
                    child: Text('一致する順号がありません'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final jungo = filteredList[index];
                      return _buildJungoCard(context, jungo);
                    },
                  ),
          ),
        ],
      ),
    );
  }
  // フィルターチップを構築するメソッド
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = selected ? value : 'all';
        });
      },
      backgroundColor: Colors.grey.shade200,
      selectedColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
      ),
    );
  }
  
  Widget _buildJungoCard(BuildContext context, JungoData jungo) {
    final now = DateTime.now();
    final isActive = now.isAfter(jungo.startDate) && now.isBefore(jungo.endDate);
    final isCompleted = now.isAfter(jungo.endDate);
    
    Color cardColor;
    Color statusColor;
    
    if (isCompleted) {
      cardColor = Colors.grey.shade100;
      statusColor = Colors.grey;
    } else if (isActive) {
      // 仕込み初期（温め）
      if (jungo.currentDayCount < jungo.totalDayCount / 3) {
        cardColor = const Color(0xFFfff8e1); // 薄い黄色
        statusColor = const Color(0xFFf39c12); // オレンジ
      } 
      // 仕込み中盤（クール）
      else if (jungo.currentDayCount < jungo.totalDayCount * 2 / 3) {
        cardColor = const Color(0xFFe1f5fe); // 薄い青
        statusColor = const Color(0xFF03a9f4); // 水色
      } 
      // 仕込み終盤（グリーン）
      else {
        cardColor = const Color(0xFFe8f5e9); // 薄い緑
        statusColor = const Color(0xFF4caf50); // 緑
      }
    } else {
      cardColor = Colors.grey.shade100;
      statusColor = Colors.grey;
    }
    
    // 年を含む日付フォーマット
    final dateFormat = DateFormat('yyyy年MM月dd日');
    final startDateStr = dateFormat.format(jungo.startDate);
    final endDateStr = dateFormat.format(jungo.endDate);
    
    // 留日の表示（今日、明日、日付）
    String startDateDisplay;
    if (now.year == jungo.startDate.year && 
        now.month == jungo.startDate.month && 
        now.day == jungo.startDate.day) {
      startDateDisplay = '本日';
    } else if (now.year == jungo.startDate.year && 
              now.month == jungo.startDate.month && 
              now.day + 1 == jungo.startDate.day) {
      startDateDisplay = '明日';
    } else if (now.year == jungo.startDate.year && 
              now.month == jungo.startDate.month && 
              now.day + 2 == jungo.startDate.day) {
      startDateDisplay = '明後日';
    } else if (jungo.startDate.isAfter(now)) {
      final days = jungo.startDate.difference(now).inDays;
      startDateDisplay = '$days日後';
    } else {
      startDateDisplay = startDateStr;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      color: cardColor,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JungoDetailScreen(jungoId: jungo.jungoId),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: statusColor, width: 8.0),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: 16.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '順号${jungo.jungoId}: ${jungo.name}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '留日: $startDateStr ($startDateDisplay)',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'タンク: ${jungo.tankNo} / 上槽予定: $endDateStr',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '醪日数: ${jungo.currentDayCount}日目 / ${jungo.totalDayCount}日間',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                
                // 順号バッジ
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${jungo.jungoId}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}