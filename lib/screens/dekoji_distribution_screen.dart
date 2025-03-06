import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';
import 'package:sake_brewing_app/services/koji_service.dart';

class DekojiDistributionScreen extends StatefulWidget {
  final DateTime? selectedDate;

  const DekojiDistributionScreen({
    Key? key,
    this.selectedDate,
  }) : super(key: key);

  @override
  State<DekojiDistributionScreen> createState() => _DekojiDistributionScreenState();
}

class _DekojiDistributionScreenState extends State<DekojiDistributionScreen> {
  late DateTime _selectedDate;
  final TextEditingController _estimatedKojiRateController = TextEditingController(text: '122.0');
  final TextEditingController _finalWeightController = TextEditingController();
  
  List<BrewingProcess> _dekojiProcesses = [];
  Map<String, double> _distribution = {};
  double? _actualKojiRate;
  bool _hasCalculated = false;
  
  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? DateTime.now();
    _loadDekojiProcesses();
  }
  
  @override
  void dispose() {
    _estimatedKojiRateController.dispose();
    _finalWeightController.dispose();
    super.dispose();
  }
  
  void _loadDekojiProcesses() {
    final kojiService = Provider.of<KojiService>(context, listen: false);
    _dekojiProcesses = kojiService.getDekojiProcesses(_selectedDate);
    setState(() {});
  }
  
  // 棚配分の結果
  Map<String, dynamic>? _shelfDistribution;
  
  void _calculateDistribution() {
    if (_dekojiProcesses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('出麹予定が見つかりません')),
      );
      return;
    }
    
    final kojiRate = double.tryParse(_estimatedKojiRateController.text);
    if (kojiRate == null || kojiRate <= 0 || kojiRate > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('有効な出麹歩合を入力してください（0〜100%）')),
      );
      return;
    }
    
    final kojiService = Provider.of<KojiService>(context, listen: false);
    
    // 1. 基本的な配分計算
    final distribution = kojiService.calculateDistribution(_dekojiProcesses, kojiRate);
    
    // 2. 詳細な棚配分計算
    final shelfDistribution = kojiService.calculateShelfDistribution(_dekojiProcesses, kojiRate);
    
    setState(() {
      _distribution = distribution;
      _shelfDistribution = shelfDistribution;
      _hasCalculated = true;
      
      // エラーがある場合はスナックバーで表示
      if (shelfDistribution.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(shelfDistribution['error']),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }
  
  void _recordKojiRate() {
    if (!_hasCalculated || _dekojiProcesses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('まず配分を計算してください')),
      );
      return;
    }
    
    final lastSheetWeight = double.tryParse(_finalWeightController.text);
    if (lastSheetWeight == null || lastSheetWeight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('有効な最後の1枚の重量を入力してください')),
      );
      return;
    }
    
    final kojiService = Provider.of<KojiService>(context, listen: false);
    final totalOriginalWeight = _dekojiProcesses.fold<double>(
      0, (sum, process) => sum + process.amount);
    
    // 真の出麹歩合計算ロジック
    // 1. 最後の1枚を除いた乾燥重量を計算
    final lastDrySheetWeight = 10.0; // 最後の1枚の乾燥重量 (kg)
    final remainingDryWeight = totalOriginalWeight - lastDrySheetWeight;
    
    // 2. 最後の1枚を除いた部分に予想歩合を適用
    final estimatedRate = double.parse(_estimatedKojiRateController.text);
    final remainingKojiWeight = remainingDryWeight * estimatedRate / 100;
    
    // 3. 最後の1枚の実測値を加えて総出麹重量を計算
    final totalKojiWeight = remainingKojiWeight + lastSheetWeight;
    
    // 4. 真の出麹歩合を計算
    final actualRate = (totalKojiWeight / totalOriginalWeight) * 100;
    
    // 最終重量を計算（棚配分のためにtotalKojiWeightを使用）
    final finalTotalWeight = totalKojiWeight;
    
    // 各プロセスの実際の出麹歩合を更新
    kojiService.updateKojiRates(_dekojiProcesses, finalTotalWeight);
    
    setState(() {
      _actualKojiRate = actualRate;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('真の出麹歩合を記録しました: ${actualRate.toStringAsFixed(1)}%'),
        backgroundColor: Colors.green,
      ),
    );
  }
  }
  
  @override
  Widget build(BuildContext context) {
    final totalOriginalWeight = _dekojiProcesses.fold<double>(
      0, (sum, process) => sum + process.amount);
      
    // 用途ごとの合計重量を計算
    final usageWeights = <String, double>{};
    for (var process in _dekojiProcesses) {
      final usage = _determineUsage(process.name);
      usageWeights[usage] = (usageWeights[usage] ?? 0) + process.amount;
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('出麹配分'),
        actions: [
          // 日付選択ボタン
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                locale: const Locale('ja'),
              );
              if (date != null) {
                setState(() {
                  _selectedDate = date;
                  _hasCalculated = false;
                  _distribution.clear();
                  _actualKojiRate = null;
                });
                _loadDekojiProcesses();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日付表示
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.today, color: Colors.amber),
                    const SizedBox(width: 12),
                    Text(
                      '${DateFormat('yyyy年MM月dd日 (E)', 'ja').format(_selectedDate)}の出麹',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 出麹予定表示セクション
            const Text(
              '本日の出麹予定',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            const Divider(color: Colors.deepOrange),
            
            if (_dekojiProcesses.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.grain_outlined,
                        size: 64,
                        color: Colors.grey.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'この日の出麹予定はありません',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _dekojiProcesses.length,
                        itemBuilder: (context, index) {
                          final process = _dekojiProcesses[index];
                          final usage = _determineUsage(process.name);
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getUsageColor(usage),
                              child: Text(
                                usage.substring(0, 1),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text('${process.name} (順号${process.jungoId})'),
                            subtitle: Text('${process.riceType} (${process.ricePct}%)'),
                            trailing: Text(
                              '${process.amount.toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const Divider(),
                      
                      // 合計表示
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '合計重量:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              '${totalOriginalWeight.toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // 用途別合計表示
                      if (usageWeights.isNotEmpty) ...[
                        const Divider(),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                          child: Text(
                            '用途別重量:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: usageWeights.entries.map((entry) {
                            return Chip(
                              avatar: CircleAvatar(
                                backgroundColor: _getUsageColor(entry.key),
                                child: Text(
                                  entry.key.substring(0, 1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              label: Text(
                                '${entry.key}: ${entry.value.toStringAsFixed(1)} kg',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: Colors.grey.shade100,
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
            const SizedBox(height: 32),
            
            // 配分計算セクション
            if (_dekojiProcesses.isNotEmpty) ...[
              const Text(
                '出麹配分計算',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const Divider(color: Colors.blue),
              
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 予想出麹歩合入力
                      TextField(
                        controller: _estimatedKojiRateController,
                        decoration: const InputDecoration(
                          labelText: '予想出麹歩合 (%)',
                          border: OutlineInputBorder(),
                          suffixText: '%',
                          helperText: '通常は100%以上になります',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        // 上下の矢印で1ずつ変更できるようにする
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                        ],
                      ),
                      
                      // 上下の矢印ボタン
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              final currentValue = double.tryParse(_estimatedKojiRateController.text) ?? 122.0;
                              setState(() {
                                _estimatedKojiRateController.text = (currentValue - 1.0).toStringAsFixed(1);
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(48, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Icon(Icons.remove),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () {
                              final currentValue = double.tryParse(_estimatedKojiRateController.text) ?? 122.0;
                              setState(() {
                                _estimatedKojiRateController.text = (currentValue + 1.0).toStringAsFixed(1);
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(48, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      
                      // 計算ボタン
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _calculateDistribution,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('配分計算'),
                        ),
                      ),
                      
                      // 計算結果表示
                      if (_hasCalculated && _distribution.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        
                        const Text(
                          '予想出麹重量',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // 総予想重量
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            children: [
                              const Text('予想総出麹重量'),
                              const SizedBox(height: 4),
                              Text(
                                '${(totalOriginalWeight * double.parse(_estimatedKojiRateController.text) / 100).toStringAsFixed(1)} kg',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                              Text(
                                '(元重量 ${totalOriginalWeight.toStringAsFixed(1)} kg × ${_estimatedKojiRateController.text}%)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // 配分結果テーブル
                        const Text(
                          '出麹順序と配分',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              // ヘッダー行
                              // ヘッダー行
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                  ),
                                ),
                                child: Row(
                                  children: const [
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        '順序',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '用途',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '元重量',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '出麹重量',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '1枚あたり',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // データ行
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _distribution.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final entry = _distribution.entries.elementAt(index);
                                  final usage = entry.key;
                                  final weight = entry.value;
                                  final originalWeight = usageWeights[usage] ?? 0;
                                  
                                  // 枚数と1枚あたりの重量を計算
                                  final sheets = (originalWeight / 10).ceil();
                                  final weightPerSheet = weight / sheets;
                                  
                                  return Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: CircleAvatar(
                                            radius: 14,
                                            backgroundColor: Colors.blue.shade700,
                                            child: Text(
                                              '${index + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 12,
                                                backgroundColor: _getUsageColor(usage),
                                                child: Text(
                                                  usage.substring(0, 1),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(usage),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            '${originalWeight.toStringAsFixed(1)} kg',
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            '${weight.toStringAsFixed(1)} kg',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            '${weightPerSheet.toStringAsFixed(1)} kg',
                                            style: const TextStyle(
                                              fontStyle: FontStyle.italic,
                                              color: Color.fromARGB(255, 24, 115, 205),
                                            ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        
                        // 棚配分の表示（エラーがなく計算が完了した場合）
                        if (_shelfDistribution != null && !_shelfDistribution!.containsKey('error')) ...[
                          const SizedBox(height: 24),
                          
                          const Text(
                            '棚配分',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '棚配置図',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // 棚の視覚表示
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        for (int colIndex = 0; colIndex < 4; colIndex++)
                                          Expanded(
                                            child: Column(
                                              children: [
                                                // 列ヘッダー
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  margin: const EdgeInsets.only(bottom: 8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade100,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    String.fromCharCode(65 + colIndex), // A, B, C, D
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                
                                                // 列の棚アイテム
                                                if (_shelfDistribution!['shelfView'] != null &&
                                                    _shelfDistribution!['shelfView'][colIndex] != null)
                                                  for (var item in _shelfDistribution!['shelfView'][colIndex])
                                                    Container(
                                                      width: double.infinity,
                                                      margin: const EdgeInsets.only(bottom: 8),
                                                      padding: const EdgeInsets.symmetric(
                                                        vertical: 10,
                                                        horizontal: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: _getUsageColor(item['usage']).withOpacity(0.3),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(
                                                          color: _getUsageColor(item['usage']),
                                                        ),
                                                      ),
                                                      child: Column(
                                                        children: [
                                                          Text(
                                                            item['usage'],
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 12,
                                                            ),
                                                            textAlign: TextAlign.center,
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            '${item['count']}枚',
                                                            style: const TextStyle(fontSize: 12),
                                                            textAlign: TextAlign.center,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // 棚の詳細説明
                                  if (_shelfDistribution!['lots'] != null) ...[
                                    const Text(
                                      '詳細情報',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 8),
                                    
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: _shelfDistribution!['lots'].length,
                                        separatorBuilder: (_, __) => const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final lot = _shelfDistribution!['lots'][index];
                                          return Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      lot['type'],
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: _getUsageColor(lot['type']),
                                                      ),
                                                    ),
                                                    Text(
                                                      '元重量: ${lot['originalWeight'].toStringAsFixed(1)} kg',
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text('枚数: ${lot['sheets']}枚'),
                                                    Text('列数: ${lot['columns']}列'),
                                                  ],
                                                ),
                                                if (lot['distribution'] != null) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '配置: ${(lot['distribution'] as List).map((i) => '$i枚').join(', ')}',
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 実績記録セクション
              if (_hasCalculated) ...[
                const Text(
                  '実績記録',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const Divider(color: Colors.green),
                
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '実際の最終出麹重量を入力して記録します',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // 最終重量入力
                        TextField(
                          controller: _finalWeightController,
                          decoration: const InputDecoration(
                            labelText: '最終出麹重量 (kg)',
                            hintText: '重量を入力',
                            border: OutlineInputBorder(),
                            suffixText: 'kg',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // 記録ボタン
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _recordKojiRate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('出麹歩合を計算・記録'),
                          ),
                        ),
                        
                        // 記録結果表示
                       // 記録結果表示
                        if (_actualKojiRate != null) ...[
                          const SizedBox(height: 24),
                          
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              children: [
                                const Text('実際の出麹歩合'),
                                const SizedBox(height: 4),
                                Text(
                                  '${_actualKojiRate!.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                                // 計算方法の説明
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    '乾燥重量: ${totalOriginalWeight.toStringAsFixed(1)} kg',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Text(
                                    '最後の1枚: ${_finalWeightController.text} kg',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 8),
                                
                                // 予想との差異
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('予想との差異: '),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${(_actualKojiRate! - double.parse(_estimatedKojiRateController.text)).toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _actualKojiRate! >= double.parse(_estimatedKojiRateController.text)
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
  
  // プロセス名から用途を決定するヘルパーメソッド
  String _determineUsage(String processName) {
    final name = processName.toLowerCase();
    
    if (name.contains('モト')) {
      return '酒母';
    } else if (name.contains('添') || name.contains('初')) {
      return '添';
    } else if (name.contains('仲')) {
      return '仲';
    } else if (name.contains('留')) {
      return '留';
    } else if (name.contains('四段')) {
      return '四段';
    } else {
      return 'その他';
    }
  }
  
  // 用途に応じた色を返すヘルパーメソッド
  Color _getUsageColor(String usage) {
    switch (usage) {
      case '酒母':
        return Colors.purple;
      case '添':
        return Colors.blue;
      case '仲':
        return Colors.teal;
      case '留':
        return Colors.amber.shade800;
      case '四段':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}