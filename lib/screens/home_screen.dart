import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';
import 'package:sake_brewing_app/screens/daily_schedule_screen.dart';
import 'package:sake_brewing_app/screens/jungo_detail_screen.dart';
import 'package:sake_brewing_app/screens/jungo_list_screen.dart';
import 'package:sake_brewing_app/screens/koji_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sake_brewing_app/services/csv_service.dart';
import 'package:sake_brewing_app/screens/csv_input_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import 'dart:convert';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  ProcessType? _selectedFilter;
  
  Future<void> _loadSampleCsv() async {
  try {
    final String csvString = await rootBundle.loadString('assets/data/sample_brewing.csv');
    final brewingDataProvider = Provider.of<BrewingDataProvider>(context, listen: false);
    await brewingDataProvider.loadFromCsv(csvString);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('サンプルCSVデータを読み込みました')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('エラーが発生しました: $e')),
    );
  }
}
  @override
void initState() {
  super.initState();
  // ローカルストレージからデータを読み込む
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final provider = Provider.of<BrewingDataProvider>(context, listen: false);
    
    // ローカルストレージからデータを読み込む
    await provider.loadFromLocalStorage();
    
    // データがなければサンプルデータを生成
    if (provider.jungoList.isEmpty) {
      provider.generateSampleData();
      // サンプルデータを保存
      await provider.saveToLocalStorage();
    }
  });
}
  
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BrewingDataProvider>(context);
    final todayProcesses = provider.getTodayProcesses();
    
    // フィルタリング
    final filteredProcesses = _selectedFilter == null
        ? todayProcesses
        : todayProcesses.where((p) => p.type == _selectedFilter).toList();
    
    // 日付フォーマッター
    final dateFormat = DateFormat('yyyy年MM月dd日 (E)', 'ja');
    final today = DateTime.now();
    
    return Scaffold(
    appBar: AppBar(
  title: const Text('日本酒醸造管理'),
  actions: [
    // CSVテキスト入力画面へ遷移
    IconButton(
      icon: const Icon(Icons.text_fields),
      onPressed: () {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => const CsvInputScreen()),
        );
      },
      tooltip: 'CSVテキスト入力',
    ),
    // 既存のボタン群
    IconButton(
      icon: const Icon(Icons.storage),
      onPressed: _checkStoredData,
      tooltip: '保存データを確認',
    ),
    IconButton(
      icon: const Icon(Icons.file_upload),
      onPressed: _importCsvFile,
      tooltip: 'CSVをインポート',
    ),
  ],
),
      body: Column(
        children: [
          // 上部フィルター
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dateFormat.format(today),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: const Text('日別スケジュール'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DailyScheduleScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(null, '全て'),
                      const SizedBox(width: 8),
                      _buildFilterChip(ProcessType.moromi, '仕込み'),
                      const SizedBox(width: 8),
                      _buildFilterChip(ProcessType.koji, '麹'),
                      const SizedBox(width: 8),
                      _buildFilterChip(ProcessType.washing, '洗米'),
                      const SizedBox(width: 8),
                      _buildFilterChip(ProcessType.pressing, '上槽'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 作業リスト
          Expanded(
            child: filteredProcesses.isEmpty
                ? const Center(
                    child: Text('本日の作業はありません'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: filteredProcesses.length,
                    itemBuilder: (context, index) {
                      final process = filteredProcesses[index];
                      return _buildProcessCard(context, process);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '本日の作業',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: '順号一覧',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grain),
            label: '麹管理',
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(ProcessType? type, String label) {
    final isSelected = _selectedFilter == type;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? type : null;
        });
      },
      showCheckmark: false,
      backgroundColor: Colors.white,
      selectedColor: _getColorForType(type),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
  
  Widget _buildProcessCard(BuildContext context, BrewingProcess process) {
    final jungoData = Provider.of<BrewingDataProvider>(context, listen: false)
        .getJungoById(process.jungoId);
        
    if (jungoData == null) return const SizedBox.shrink();
    
    Color borderColor = _getColorForType(process.type);
    
    String statusText;
    switch (process.status) {
      case ProcessStatus.pending:
        statusText = '予定';
        break;
      case ProcessStatus.active:
        statusText = '進行中';
        break;
      case ProcessStatus.completed:
        statusText = '完了';
        break;
    }
    
    // 適切な作業日を取得
    String workDateStr;
    if (process.type == ProcessType.koji) {
      // 麹工程の場合は現在のステージに応じた日付
      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);
      
      final hikomiDateStr = DateFormat('yyyy-MM-dd').format(process.getHikomiDate());
      final moriDateStr = DateFormat('yyyy-MM-dd').format(process.getMoriDate());
      final dekojiDateStr = DateFormat('yyyy-MM-dd').format(process.getDekojiDate());
      
      if (hikomiDateStr == todayStr) {
        workDateStr = '引込み日';
      } else if (moriDateStr == todayStr) {
        workDateStr = '盛り日';
      } else if (dekojiDateStr == todayStr) {
        workDateStr = '出麹日';
      } else {
        workDateStr = '洗米日: ${_formatDate(process.washingDate)}';
      }
    } else if (process.type == ProcessType.washing) {
      workDateStr = '洗米日';
    } else if (process.type == ProcessType.moromi) {
      workDateStr = '仕込み日: ${_formatDate(process.getWorkDate())}';
    } else {
      workDateStr = _formatDate(process.date);
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JungoDetailScreen(jungoId: jungoData.jungoId),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: borderColor, width: 8.0),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_getProcessTypeLabel(process.type)}（順号${process.jungoId}）',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: borderColor,
                      ),
                    ),
                    Chip(
                      label: Text(
                        statusText,
                        style: TextStyle(
                          color: process.status == ProcessStatus.completed
                              ? Colors.white
                              : Colors.black87,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: process.status == ProcessStatus.completed
                          ? Colors.green
                          : process.status == ProcessStatus.active
                              ? Colors.amber
                              : Colors.grey.shade200,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${jungoData.name} / タンク: ${jungoData.tankNo}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '$workDateStr / 作業: ${process.name}',
                  style: const TextStyle(fontSize: 14),
                ),
                if (process.type != ProcessType.pressing)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '${process.riceType} / ${process.amount}kg',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  String _getProcessTypeLabel(ProcessType type) {
  switch (type) {
    case ProcessType.moromi:
      return '本日の仕込み';
    case ProcessType.koji:
      return '麹作業';
    case ProcessType.washing:
      return '洗米予定';
    case ProcessType.pressing:
      return '上槽予定';
    case ProcessType.other:  // この行を追加
      return 'その他作業';  // この行を追加
  }
}
  
  Color _getColorForType(ProcessType? type) {
    switch (type) {
      case ProcessType.moromi:
        return Colors.blue;
      case ProcessType.koji:
        return Colors.amber;
      case ProcessType.washing:
        return Colors.lightBlue;
      case ProcessType.pressing:
        return Colors.purple;
      case ProcessType.other:
        return Colors.teal;
      default:
        return Colors.blue;
    }
  }
  
  String _formatDate(DateTime date) {
    return DateFormat('MM月dd日').format(date);
  }
  
  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    
    setState(() {
      _selectedIndex = index;
    });
    
    switch (index) {
      case 0:
        // 現在のホーム画面
        break;
      case 1:
        // 順号一覧画面に遷移
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const JungoListScreen(),
          ),
        ).then((_) {
          setState(() {
            _selectedIndex = 0;
          });
        });
        break;
      case 2:
        // 麹管理画面に遷移
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const KojiScreen(),
          ),
        ).then((_) {
          setState(() {
            _selectedIndex = 0;
          });
        });
        break;
    }
  }
  
  // CSVファイルのインポート
  // _importCsvFileメソッドを修正
Future<void> _importCsvFile() async {
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      // ファイルの内容を読み込む
      final fileBytes = result.files.first.bytes;
      if (fileBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ファイルの読み込みに失敗しました')),
        );
        return;
      }
      
      final csvString = utf8.decode(fileBytes);
      final brewingDataProvider = Provider.of<BrewingDataProvider>(context, listen: false);
      
      // CSVデータを解析
      await brewingDataProvider.loadFromCsv(csvString);
      
      // 重要：明示的にデータを保存（この行を追加）
      await brewingDataProvider.saveToLocalStorage();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('データをインポートしました。データは保存されました。')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('エラーが発生しました: $e')),
    );
  }
}


// メソッドを追加
void _checkStoredData() async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys();
  
  String allData = '';
  for (String key in keys) {
    final value = prefs.get(key);
    String valueStr = value.toString();
    if (valueStr.length > 100) {
      valueStr = valueStr.substring(0, 100) + '...';
    }
    allData += '$key: $valueStr\n\n';
  }
  
  if (allData.isEmpty) {
    allData = 'データがありません';
  }
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('保存データ確認'),
      content: SingleChildScrollView(
        child: Text(allData),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    ),
  );
}
}