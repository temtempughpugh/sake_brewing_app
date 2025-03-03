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
      
      // ステータスフィルター部分の修正

      // ステータスフィルター（新しい正確なルールに基づく）
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
            hasMoto = true;
            motoWorkDate = process.getWorkDate();
          }
          if (process.name.contains('添') && process.type == ProcessType.washing) {
            hasSoe = true;
            soeWashingDate = process.washingDate;
          } else if (process.name.contains('添') && process.type == ProcessType.moromi) {
            hasSoe = true;
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
        backgroundColor: const Color(0xFF1A1A2E), // 深い紺色
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A1A2E),
              const Color(0xFF16213E),
              Colors.black.withOpacity(0.8),
            ],
          ),
        ),
        child: Column(
          children: [
            // 検索バー
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: '順号検索...',
                  hintStyle: TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF16213E).withOpacity(0.7),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
                style: const TextStyle(color: Colors.white),
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
                    // 新規作成ボタン（実装はしていません）
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F3460),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
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
            ),
            
            const SizedBox(height: 8),
            
            // 順号リスト
            Expanded(
              child: filteredList.isEmpty
                  ? Center(
                      child: Text(
                        '一致する順号がありません',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
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
      ),
    );
  }
  
  // フィルターチップを構築するメソッド
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    
    Color chipColor;
    Color textColor = isSelected ? Colors.white : Colors.white70;
    
    // フィルタの種類に応じた色
    switch (value) {
      case 'shubo':
        chipColor = isSelected ? const Color(0xFFF1C40F) : const Color(0xFF16213E);
        break;
      case 'brewing':
        chipColor = isSelected ? const Color(0xFFE67E22) : const Color(0xFF16213E);
        break;
      case 'moromi':
        chipColor = isSelected ? const Color(0xFF3498DB) : const Color(0xFF16213E);
        break;
      case 'completed':
        chipColor = isSelected ? const Color(0xFF2ECC71) : const Color(0xFF16213E);
        break;
      default: // 'all'
        chipColor = isSelected ? Colors.white : const Color(0xFF16213E);
        textColor = isSelected ? const Color(0xFF16213E) : Colors.white70;
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
      backgroundColor: const Color(0xFF16213E),
      selectedColor: chipColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? chipColor : Colors.transparent,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
  
  Widget _buildJungoCard(BuildContext context, JungoData jungo) {
    final now = DateTime.now();
    
    // 状態判定
    bool isCompleted = now.isAfter(jungo.endDate);
    bool isMoromi = now.isAfter(jungo.startDate) && now.isBefore(jungo.endDate);
    
    // 酒母状態の判定
    bool isShubo = false;
    DateTime? motoDate;
    DateTime? soeWashingDate;
    
    for (var process in jungo.processes) {
      if (process.name.contains('モト') && process.type == ProcessType.moromi) {
        motoDate = process.getWorkDate();
      }
      if (process.name.contains('添') && process.type == ProcessType.moromi) {
        soeWashingDate = process.washingDate;
      }
    }
    
    if (motoDate != null && soeWashingDate != null) {
      isShubo = now.isAfter(motoDate) && now.isBefore(soeWashingDate);
    }
    
    // 仕込み状態の判定
    bool isBrewing = false;
    if (soeWashingDate != null) {
      isBrewing = now.isAfter(soeWashingDate) && now.isBefore(jungo.startDate);
    }
    
    // カードの色設定
    Color cardColor;
    Color borderColor;
    Color statusColor;
    String statusText;
    
    if (isCompleted) {
      statusText = "完了";
      cardColor = const Color(0xFF2C3333);
      borderColor = const Color(0xFF2ECC71);
      statusColor = const Color(0xFF2ECC71);
    } else if (isMoromi) {
      statusText = "醪";
      cardColor = const Color(0xFF0A2647);
      borderColor = const Color(0xFF3498DB);
      statusColor = const Color(0xFF3498DB);
    } else if (isBrewing) {
      statusText = "仕込中";
      cardColor = const Color(0xFF331D2C);
      borderColor = const Color(0xFFE67E22);
      statusColor = const Color(0xFFE67E22);
    } else if (isShubo) {
      statusText = "酒母";
      cardColor = const Color(0xFF2C3333);
      borderColor = const Color(0xFFF1C40F);
      statusColor = const Color(0xFFF1C40F);
    } else {
      statusText = "予定";
      cardColor = const Color(0xFF1F1D36);
      borderColor = Colors.grey;
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
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.4),
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
        splashColor: borderColor.withOpacity(0.1),
        highlightColor: borderColor.withOpacity(0.2),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: borderColor, width: 6.0),
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
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            jungo.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '留日: $startDateStr ($startDateDisplay)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'タンク: ${jungo.tankNo} / 上槽予定: $endDateStr',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: jungo.progressPercent / 100,
                        minHeight: 6,
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '醪日数: ${jungo.currentDayCount}日目 / ${jungo.totalDayCount}日間',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
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
                        color: statusColor.withOpacity(0.2),
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
                            color: Colors.black.withOpacity(0.3),
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