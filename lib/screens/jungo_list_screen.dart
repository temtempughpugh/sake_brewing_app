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
  String _filterStatus = 'all'; // 'all', 'shubo', 'brewing', 'moromi', 'completed'
  
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
            !jungo.tankNo.toLowerCase().contains(query)) {
          return false;
        }
      }
      
      final now = DateTime.now();
      
     // ステータスフィルター（正確なルールに基づく）
if (_filterStatus == 'moromi') {
  // 留日の翌日から上槽日までは醪状態
  return now.isAfter(jungo.startDate.add(const Duration(days: 1))) && 
         now.isBefore(jungo.endDate);
} else if (_filterStatus == 'shubo') {
  // 酒母状態の判定（モト掛の仕込み日から添掛の洗米日まで）
  bool hasMoto = false;
  DateTime? motoWorkDate;
  bool hasSoe = false;
  DateTime? soeWashingDate;
  
 for (var process in jungo.processes) {
  if (process.name.contains('モト') && process.type == ProcessType.moromi) {
    motoWorkDate = process.getWorkDate();
  }
  if (process.name.contains('添') && 
     (process.type == ProcessType.washing || process.type == ProcessType.moromi)) {
    soeWashingDate = process.washingDate;
  }
}
  
  if (hasMoto && hasSoe && motoWorkDate != null && soeWashingDate != null) {
    return now.isAfter(motoWorkDate) && now.isBefore(soeWashingDate);
  }
  return false;
} else if (_filterStatus == 'brewing') {
  // 仕込み状態の判定（添掛の仕込み日から留日まで）
  bool hasSoe = false;
  DateTime? soeWorkDate;
  
  for (var process in jungo.processes) {
    if (process.name.contains('添') && process.type == ProcessType.moromi) {
      hasSoe = true;
      soeWorkDate = process.getWorkDate();
    }
  }
  
  if (hasSoe && soeWorkDate != null) {
    return now.isAfter(soeWorkDate) && now.isBefore(jungo.startDate);
  }
  return false;
} else if (_filterStatus == 'completed') {
  // 完了の判定
  return now.isAfter(jungo.endDate);
}

return true; // 'all'の場合はすべて表示
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
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('全て', 'all'),
                  const SizedBox(width: 10),
                  _buildFilterChip('酒母', 'shubo'),
                  const SizedBox(width: 10),
                  _buildFilterChip('仕込中', 'brewing'),
                  const SizedBox(width: 10),
                  _buildFilterChip('醪', 'moromi'),
                  const SizedBox(width: 10),
                  _buildFilterChip('完了', 'completed'),
                  const SizedBox(width: 20),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 順号リスト
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Text(
                      '一致する順号がありません',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
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
    
    Color chipColor;
    Color textColor;
    
    // フィルタの種類に応じた色
    switch (value) {
      case 'shubo':
        chipColor = isSelected ? const Color(0xFFF1C40F) : Colors.grey.shade200;
        textColor = isSelected ? Colors.white : Colors.black87;
        break;
      case 'brewing':
        chipColor = isSelected ? const Color(0xFFE67E22) : Colors.grey.shade200;
        textColor = isSelected ? Colors.white : Colors.black87;
        break;
      case 'moromi':
        chipColor = isSelected ? const Color(0xFF3498DB) : Colors.grey.shade200;
        textColor = isSelected ? Colors.white : Colors.black87;
        break;
      case 'completed':
        chipColor = isSelected ? const Color(0xFF2ECC71) : Colors.grey.shade200;
        textColor = isSelected ? Colors.white : Colors.black87;
        break;
      default: // 'all'
        chipColor = isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade200;
        textColor = isSelected ? Colors.white : Colors.black87;
    }
    
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = selected ? value : 'all';
        });
      },
      backgroundColor: Colors.grey.shade200,
      selectedColor: chipColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
  
  Widget _buildJungoCard(BuildContext context, JungoData jungo) {
    final now = DateTime.now();
    
    // 状態判定
    bool isCompleted = now.isAfter(jungo.endDate);
    bool isMoromi = now.isAfter(jungo.startDate.add(const Duration(days: 1))) && now.isBefore(jungo.endDate);
    
    /// 酒母状態の判定
bool isShubo = false;
DateTime? motoWorkDate;
DateTime? soeWashingDate;
bool hasMoto = false;
bool hasSoe = false;

for (var process in jungo.processes) {
  if (process.name.contains('モト') && process.type == ProcessType.moromi) {
    hasMoto = true;
    motoWorkDate = process.getWorkDate();
  }
  if (process.name.contains('添') && 
     (process.type == ProcessType.washing || process.type == ProcessType.moromi)) {
    hasSoe = true;
    soeWashingDate = process.washingDate;
  }
}

if (hasMoto && hasSoe && motoWorkDate != null && soeWashingDate != null) {
  isShubo = now.isAfter(motoWorkDate) && now.isBefore(soeWashingDate);
}
    
    // 仕込み状態の判定
    bool isBrewing = false;
    DateTime? soeWorkDate;
    
    for (var process in jungo.processes) {
      if (process.name.contains('添') && process.type == ProcessType.moromi) {
        soeWorkDate = process.getWorkDate();
        break;
      }
    }
    
    if (soeWorkDate != null) {
      isBrewing = now.isAfter(soeWorkDate) && now.isBefore(jungo.startDate);
    }
    
    // カードの色設定
    Color cardColor = Colors.white;
    Color statusColor;
    String statusText;
    
    if (isCompleted) {
      statusText = "完了";
      statusColor = const Color(0xFF2ECC71);
    } else if (isMoromi) {
      statusText = "醪";
      statusColor = const Color(0xFF3498DB);
    } else if (isBrewing) {
      statusText = "仕込中";
      statusColor = const Color(0xFFE67E22);
    } else if (isShubo) {
      statusText = "酒母";
      statusColor = const Color(0xFFF1C40F);
    } else {
      statusText = "予定";
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor, width: 1.5),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JungoDetailScreen(jungoId: jungo.jungoId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: statusColor, width: 6.0),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 16.0,
              horizontal: 20.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '順号${jungo.jungoId}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            jungo.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '留日: $startDateStr ($startDateDisplay)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'タンク: ${jungo.tankNo} / 上槽予定: $endDateStr',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: jungo.progressPercent / 100,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '醪日数: ${jungo.currentDayCount}日目 / ${jungo.totalDayCount}日間',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ステータスバッジ
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 順号バッジ
                    Container(
                      width: 35,
                      height: 35,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}