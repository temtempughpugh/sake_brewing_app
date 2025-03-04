import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';
import 'package:sake_brewing_app/screens/jungo_detail_screen.dart';
import 'package:sake_brewing_app/screens/jungo_list_screen.dart';
import 'package:sake_brewing_app/screens/koji_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  DateTime _selectedDate = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    // ローカルストレージからデータを読み込む
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<BrewingDataProvider>(context, listen: false);
      
      // ローカルストレージからデータを読み込む
      await provider.loadFromLocalStorage();
      
      // ローカルストレージにデータがなければCSVファイルから読み込む
      if (provider.jungoList.isEmpty) {
        try {
          print('サンプルCSVを自動読み込みします');
          final String csvString = await DefaultAssetBundle.of(context)
              .loadString('assets/data/sample_brewing.csv');
          await provider.loadFromCsv(csvString);
          await provider.saveToLocalStorage();
          print('サンプルCSVの自動読み込みが完了しました');
        } catch (e) {
          print('サンプルCSV自動読み込みエラー: $e');
          // CSVが読み込めない場合はサンプルデータを生成
          provider.generateSampleData();
          await provider.saveToLocalStorage();
        }
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BrewingDataProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('日本酒醸造管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: _importCsvFile,
            tooltip: 'CSVをインポート',
          ),
        ],
      ),
      body: Column(
        children: [
          // 日付セレクター
          _buildDateSelector(),
          
          // 各作業カテゴリー
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 麹工程のカード
                    _buildKojiProcessCards(),
                    
                    const SizedBox(height: 24),
                    
                    // 醪工程のカード
                    _buildMoromiProcessCards(),
                    
                    const SizedBox(height: 24),
                    
                    // 上槽工程のカード
                    _buildPressingProcessCards(),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
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
            label: '醸造カレンダー',
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
  
  // 日付選択UI
  Widget _buildDateSelector() {
    final dateFormat = DateFormat('yyyy年MM月dd日 (E)', 'ja');
    
    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 4,
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
    );
  }
  
  // 麹工程カード (盛り、引込み、出麹)
  Widget _buildKojiProcessCards() {
    final provider = Provider.of<BrewingDataProvider>(context);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    // 盛り工程
    final moriProcesses = _getKojiProcessesForDate(provider.jungoList, _selectedDate, 'mori');
    // 引込み工程
    final hikomiProcesses = _getKojiProcessesForDate(provider.jungoList, _selectedDate, 'hikomi');
    // 出麹工程
    final dekojiProcesses = _getKojiProcessesForDate(provider.jungoList, _selectedDate, 'dekoji');
    
    // 各工程の総重量を計算
    final moriTotalWeight = moriProcesses.fold<double>(0, (sum, p) => sum + p.amount);
    final hikomiTotalWeight = hikomiProcesses.fold<double>(0, (sum, p) => sum + p.amount);
    final dekojiTotalWeight = dekojiProcesses.fold<double>(0, (sum, p) => sum + p.amount);
    
    // 麹工程が全くない場合
    if (moriProcesses.isEmpty && hikomiProcesses.isEmpty && dekojiProcesses.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // セクションタイトル
        const Text(
          '麹工程',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.brown,
          ),
        ),
        const Divider(color: Colors.brown),
        
        // 盛り工程
        if (moriProcesses.isNotEmpty)
          _buildProcessGroup('盛り', moriProcesses, moriTotalWeight, Colors.amber),
          
        // 引込み工程
        if (hikomiProcesses.isNotEmpty)
          _buildProcessGroup('引込み', hikomiProcesses, hikomiTotalWeight, Colors.orange),
        
        // 出麹工程
        if (dekojiProcesses.isNotEmpty)
          _buildProcessGroup('出麹', dekojiProcesses, dekojiTotalWeight, Colors.deepOrange),
      ],
    );
  }
  
  // 醪工程カード (添、仲、留、四段)
  Widget _buildMoromiProcessCards() {
    final provider = Provider.of<BrewingDataProvider>(context);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    // 添仕込み工程
    final soeProcesses = _getMoromiProcessesForDate(provider.jungoList, _selectedDate, '添');
    // 仲仕込み工程
    final nakaProcesses = _getMoromiProcessesForDate(provider.jungoList, _selectedDate, '仲');
    // 留仕込み工程
    final tomeProcesses = _getMoromiProcessesForDate(provider.jungoList, _selectedDate, '留');
    // 四段工程
    final yodanProcesses = _getMoromiProcessesForDate(provider.jungoList, _selectedDate, '四段');
    // モト仕込み工程
    final motoProcesses = _getMoromiProcessesForDate(provider.jungoList, _selectedDate, 'モト');
    
    // 醪工程が全くない場合
    if (soeProcesses.isEmpty && nakaProcesses.isEmpty && tomeProcesses.isEmpty && 
        yodanProcesses.isEmpty && motoProcesses.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // セクションタイトル
        const Text(
          '醪工程',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const Divider(color: Colors.blue),
        
        // モト仕込み
        if (motoProcesses.isNotEmpty)
          _buildProcessGroup('モト仕込み', motoProcesses, null, Colors.blue),
        
        // 添仕込み  
        if (soeProcesses.isNotEmpty)
          _buildProcessGroup('添仕込み', soeProcesses, null, Colors.lightBlue),
        
        // 仲仕込み
        if (nakaProcesses.isNotEmpty)
          _buildProcessGroup('仲仕込み', nakaProcesses, null, Colors.blue.shade700),
        
        // 留仕込み
        if (tomeProcesses.isNotEmpty)
          _buildProcessGroup('留仕込み', tomeProcesses, null, Colors.indigo),
        
        // 四段
        if (yodanProcesses.isNotEmpty)
          _buildProcessGroup('四段', yodanProcesses, null, Colors.purple),
      ],
    );
  }
  
  // 上槽工程カード
  Widget _buildPressingProcessCards() {
    final provider = Provider.of<BrewingDataProvider>(context);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    // 上槽工程
    final pressingProcesses = provider.jungoList
        .expand((jungo) => jungo.processes)
        .where((process) => 
            process.type == ProcessType.pressing && 
            DateFormat('yyyy-MM-dd').format(process.date) == dateStr)
        .toList();
    
    // 上槽工程がない場合
    if (pressingProcesses.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // セクションタイトル
        const Text(
          '上槽工程',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        const Divider(color: Colors.deepPurple),
        
        // 上槽工程一覧
        _buildProcessGroup('上槽', pressingProcesses, null, Colors.deepPurple),
      ],
    );
  }
  
  // 工程グループを構築
  Widget _buildProcessGroup(String title, List<BrewingProcess> processes, double? totalWeight, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                
                // 合計重量がある場合に表示
                if (totalWeight != null)
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
                      '合計: ${totalWeight.toStringAsFixed(1)}kg',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                
                // 工程数の表示
                if (totalWeight == null)
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
                      '${processes.length}件',
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
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text('${jungo.name} / タンク: ${jungo.tankNo}'),
          const SizedBox(height: 4),
          Text('${process.riceType} (${process.ricePct}%) / ${process.amount}kg'),
          const SizedBox(height: 4),
          Text('ロット番号: $lotNumber', 
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          if (process.memo != null && process.memo!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'メモ: ${process.memo}',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
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
  
List<BrewingProcess> _getMoromiProcessesForDate(List<JungoData> jungoList, DateTime date, String namePattern) {
  final dateStr = DateFormat('yyyy-MM-dd').format(date);
  
  return jungoList.expand((jungo) => jungo.processes).where((process) {
    // 醪工程または四段工程で、指定された工程と一致し、作業日が選択日と一致
    bool matchesPattern = false;
    
    if (namePattern == '添') {
      // 添仕込みの場合は「添」または「初」を含む工程を検索
      matchesPattern = process.name.contains('添') || process.name.contains('初');
    } else if (namePattern == '仲') {
      matchesPattern = process.name.contains('仲');
    } else if (namePattern == '留') {
      matchesPattern = process.name.contains('留');
    } else if (namePattern == '四段') {
      matchesPattern = process.name.contains('四段');
    } else if (namePattern == 'モト') {
      matchesPattern = process.name.contains('モト');
    } else {
      matchesPattern = process.name.contains(namePattern);
    }
    
    if ((process.type == ProcessType.moromi || process.type == ProcessType.other) && matchesPattern) {
      final workDate = process.getWorkDate();
      return DateFormat('yyyy-MM-dd').format(workDate) == dateStr;
    }
    return false;
  }).toList();
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
        
        // データを保存
        await brewingDataProvider.saveToLocalStorage();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('データをインポートしました')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }
}