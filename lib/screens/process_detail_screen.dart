import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';

class ProcessDetailScreen extends StatefulWidget {
  final int jungoId;
  final String processName;
  final DateTime date;

  const ProcessDetailScreen({
    super.key, 
    required this.jungoId,
    required this.processName, 
    required this.date,
  });

  @override
  State<ProcessDetailScreen> createState() => _ProcessDetailScreenState();
}

class _ProcessDetailScreenState extends State<ProcessDetailScreen> {
  final _memoController = TextEditingController();
  final _waterAbsorptionController = TextEditingController();
  final _temperatureController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    
    // 既存のデータがあれば読み込む
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingData();
    });
  }
  
  @override
  void dispose() {
    _memoController.dispose();
    _waterAbsorptionController.dispose();
    _temperatureController.dispose();
    super.dispose();
  }
  
  void _loadExistingData() {
    final provider = Provider.of<BrewingDataProvider>(context, listen: false);
    final process = provider.getProcessByJungoAndName(widget.jungoId, widget.processName);
    
    if (process != null) {
      // メモがあれば設定
      if (process.memo != null) {
        _memoController.text = process.memo!;
      }
      
      // 洗米の場合は吸水率データを設定
      if (process.type == ProcessType.washing && process.waterAbsorption != null) {
        _waterAbsorptionController.text = process.waterAbsorption!.toString();
      }
      
      // 温度データがあれば設定
      if (process.temperature != null) {
        _temperatureController.text = process.temperature!.toString();
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BrewingDataProvider>(context);
    final jungo = provider.getJungoById(widget.jungoId);
    final process = provider.getProcessByJungoAndName(widget.jungoId, widget.processName);
    
    if (jungo == null || process == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('工程詳細'),
        ),
        body: const Center(
          child: Text('データが見つかりません'),
        ),
      );
    }
    
    // ロット番号生成
    final lotNumber = 'Lot-${jungo.jungoId}-${process.name}';
    
    // 日付フォーマット
    final dateFormat = DateFormat('yyyy年MM月dd日', 'ja');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${process.name}の詳細・記録'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 基本情報カード
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${process.name} (順号${jungo.jungoId})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('製品: ${jungo.name}'),
                      const SizedBox(height: 4),
                      Text('タンク: ${jungo.tankNo}'),
                      const SizedBox(height: 4),
                      Text('仕込区分: ${jungo.category}'),
                      const SizedBox(height: 4),
                      Text('製法区分: ${jungo.type}'),
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text('米品種: ${process.riceType}'),
                      const SizedBox(height: 4),
                      Text('精米歩合: ${process.ricePct}%'),
                      const SizedBox(height: 4),
                      Text('使用量: ${process.amount}kg'),
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      // 工程によって表示を変える
                      if (process.type == ProcessType.koji) ...[
                        Text('洗米日: ${dateFormat.format(process.washingDate)}'),
                        const SizedBox(height: 4),
                        Text('引込日: ${dateFormat.format(process.getHikomiDate())}'),
                        const SizedBox(height: 4),
                        Text('盛日: ${dateFormat.format(process.getMoriDate())}'),
                        const SizedBox(height: 4),
                        Text('出麹日: ${dateFormat.format(process.getDekojiDate())}'),
                      ] else if (process.type == ProcessType.moromi) ...[
                        Text('洗米日: ${dateFormat.format(process.washingDate)}'),
                        const SizedBox(height: 4),
                        Text('仕込日: ${dateFormat.format(process.getWorkDate())}'),
                      ] else if (process.type == ProcessType.washing) ...[
                        Text('洗米日: ${dateFormat.format(process.washingDate)}'),
                      ] else if (process.type == ProcessType.pressing) ...[
                        Text('上槽日: ${dateFormat.format(process.date)}'),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'ロット番号: $lotNumber',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 記録フォーム
              const Text(
                '作業記録',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 温度記録（すべての工程）
              TextField(
                controller: _temperatureController,
                decoration: const InputDecoration(
                  labelText: '温度 (℃)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              
              const SizedBox(height: 16),
              
              // 洗米工程の場合は吸水率フィールドを表示
              if (process.type == ProcessType.washing) ...[
                TextField(
                  controller: _waterAbsorptionController,
                  decoration: const InputDecoration(
                    labelText: '吸水率 (%)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                
                const SizedBox(height: 16),
              ],
              
              // メモフィールド（すべての工程）
              TextField(
                controller: _memoController,
                decoration: const InputDecoration(
                  labelText: 'メモ',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                ),
                maxLines: 5,
              ),
              
              const SizedBox(height: 24),
              
              // 保存ボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveData,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  child: const Text('保存'),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 工程完了ボタン
              if (process.status != ProcessStatus.completed)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _markAsCompleted,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                    ),
                    child: const Text('工程を完了としてマーク'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  // データ保存処理
  void _saveData() {
    final memo = _memoController.text.trim();
    final temperatureText = _temperatureController.text.trim();
    final waterAbsorptionText = _waterAbsorptionController.text.trim();
    
    // 温度の解析
    double? temperature;
    if (temperatureText.isNotEmpty) {
      try {
        temperature = double.parse(temperatureText);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('温度の値が不正です')),
        );
        return;
      }
    }
    
    // 吸水率の解析
    double? waterAbsorption;
    if (waterAbsorptionText.isNotEmpty) {
      try {
        waterAbsorption = double.parse(waterAbsorptionText);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('吸水率の値が不正です')),
        );
        return;
      }
    }
    
    // データの更新
    final provider = Provider.of<BrewingDataProvider>(context, listen: false);
    provider.updateProcessData(
      widget.jungoId,
      widget.processName,
      memo: memo.isEmpty ? null : memo,
      temperature: temperature,
      waterAbsorption: waterAbsorption,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('データを保存しました')),
    );
  }
  
  // 工程を完了としてマーク
  void _markAsCompleted() {
    final provider = Provider.of<BrewingDataProvider>(context, listen: false);
    provider.updateProcessStatus(widget.jungoId, widget.processName, ProcessStatus.completed);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('工程を完了としてマークしました')),
    );
  }
}