import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';
import 'package:sake_brewing_app/models/rice_data_provider.dart';
import 'package:sake_brewing_app/models/washing_record.dart';
import 'package:sake_brewing_app/models/rice_data.dart';

class WashingRecordScreen extends StatefulWidget {
  const WashingRecordScreen({Key? key}) : super(key: key);

  @override
  State<WashingRecordScreen> createState() => _WashingRecordScreenState();
}

class _WashingRecordScreenState extends State<WashingRecordScreen> {
  DateTime _selectedDate = DateTime.now();
  final _absorptionRateController = TextEditingController();
  final _memoController = TextEditingController();
  RiceEvaluation _riceEvaluation = RiceEvaluation.unknown;
  RiceEvaluation _steamedEvaluation = RiceEvaluation.unknown;
  
  // 選択された白米ロットID
  List<String> _selectedRiceLotIds = [];
  
  @override
  void dispose() {
    _absorptionRateController.dispose();
    _memoController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final brewingProvider = Provider.of<BrewingDataProvider>(context);
    final riceProvider = Provider.of<RiceDataProvider>(context);
    
    // 選択された日付の洗米工程を取得
    final washingProcesses = _getWashingProcessesForDate(brewingProvider.jungoList, _selectedDate);
    
    // 麹用と掛米用に分離
    final kojiProcesses = washingProcesses.where((p) => 
      p.name.toLowerCase().contains('麹') || 
      brewingProvider.getJungoById(p.jungoId)?.processes.any((proc) => 
        proc.name.toLowerCase().contains('麹')
      ) == true
    ).toList();
    
    final kakemaiProcesses = washingProcesses.where((p) => 
      !p.name.toLowerCase().contains('麹') && 
      brewingProvider.getJungoById(p.jungoId)?.processes.any((proc) => 
        proc.name.toLowerCase().contains('麹')
      ) != true
    ).toList();
    
    // 品種ごとにグループ化
    final kojiGroups = _groupProcessesByRiceType(kojiProcesses);
    final kakemaiGroups = _groupProcessesByRiceType(kakemaiProcesses);
    
    // 選択日の既存洗米記録を取得
    final existingRecords = riceProvider.getWashingRecordsByDate(_selectedDate);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('洗米記録'),
      ),
      body: Column(
        children: [
          // 日付選択部分
          _buildDateSelector(),
          
          // 洗米記録表示部分
          Expanded(
            child: washingProcesses.isEmpty
                ? Center(
                    child: Text(
                      'この日の洗米記録はありません',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 麹米グループ
                        if (kojiGroups.isNotEmpty) ...[
                          Text(
                            '麹米',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...kojiGroups.entries.map((entry) => 
                            _buildRiceGroup(entry.key, entry.value, existingRecords)
                          ).toList(),
                          const SizedBox(height: 16),
                        ],
                        
                        // 掛米グループ
                        if (kakemaiGroups.isNotEmpty) ...[
                          Text(
                            '掛米',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...kakemaiGroups.entries.map((entry) => 
                            _buildRiceGroup(entry.key, entry.value, existingRecords)
                          ).toList(),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  
  // 工程を品種でグループ化
  Map<String, List<BrewingProcess>> _groupProcessesByRiceType(List<BrewingProcess> processes) {
    final Map<String, List<BrewingProcess>> groups = {};
    
    for (var process in processes) {
      if (groups.containsKey(process.riceType)) {
        groups[process.riceType]!.add(process);
      } else {
        groups[process.riceType] = [process];
      }
    }
    
    return groups;
  }
  
  // 白米グループウィジェットを構築
  Widget _buildRiceGroup(String riceType, List<BrewingProcess> processes, List<WashingRecord> existingRecords) {
    // 品種に対応する既存の洗米記録を検索
    // 現状では簡易的なマッチングを行う
    WashingRecord? existingRecord;
    for (var record in existingRecords) {
      // ロットIDと品種のマッチングはより複雑になる可能性がある
      // 現段階では暫定的な実装
      if (record.riceLotIds.isNotEmpty) {
        final riceLot = Provider.of<RiceDataProvider>(context, listen: false)
            .getRiceLotById(record.riceLotIds.first);
        
        if (riceLot != null && riceLot.riceType == riceType) {
          existingRecord = record;
          break;
        }
      }
    }
    
    // 総重量を計算
    final totalWeight = processes.fold<double>(0, (sum, p) => sum + p.amount);
    
    // 関連する白米ロットを取得
    final relatedLots = Provider.of<RiceDataProvider>(context)
        .riceLots
        .where((lot) => lot.riceType == riceType)
        .toList();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$riceType (${processes.first.ricePct}%)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '合計: ${totalWeight.toStringAsFixed(1)}kg',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            
            const Divider(),
            
            // 工程リスト
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: processes.length,
              itemBuilder: (context, index) {
                final process = processes[index];
                return ListTile(
                  dense: true,
                  title: Text('${process.name} (順号${process.jungoId})'),
                  subtitle: Text('${process.amount}kg'),
                );
              },
            ),
            
            const Divider(),
            
            // 洗米記録部分
            const Text(
              '洗米記録',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            
            // 白米ロット選択（ドロップダウン）
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '白米ロット',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              value: existingRecord?.riceLotIds.isNotEmpty == true ? existingRecord!.riceLotIds.first : null,
              items: [
                ...relatedLots.map((lot) => DropdownMenuItem(
                  value: lot.lotId,
                  child: Text('${lot.lotId} - ${lot.riceType} (${lot.origin})'),
                )),
                if (relatedLots.isEmpty)
                  const DropdownMenuItem(
                    value: null,
                    child: Text('ロットを追加してください'),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedRiceLotIds = [value];
                  });
                }
              },
            ),
            
            const SizedBox(height: 12),
            
            // 吸水率入力
            TextField(
              controller: _absorptionRateController,
              decoration: const InputDecoration(
                labelText: '吸水率 (%)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            
            const SizedBox(height: 12),
            
            // 評価
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<RiceEvaluation>(
                    decoration: const InputDecoration(
                      labelText: '白米評価',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: existingRecord?.riceEvaluation ?? RiceEvaluation.unknown,
                    items: RiceEvaluation.values.map((eval) => DropdownMenuItem(
                      value: eval,
                      child: Text(eval.toDisplayString()),
                    )).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _riceEvaluation = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<RiceEvaluation>(
                    decoration: const InputDecoration(
                      labelText: '蒸米評価',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: existingRecord?.steamedEvaluation ?? RiceEvaluation.unknown,
                    items: RiceEvaluation.values.map((eval) => DropdownMenuItem(
                      value: eval,
                      child: Text(eval.toDisplayString()),
                    )).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _steamedEvaluation = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // メモ入力
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: 'メモ',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              maxLines: 3,
            ),
            
            const SizedBox(height: 16),
            
            // 保存ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _saveRecord(riceType, processes),
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 日付選択部分
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
  
  // 記録保存処理
  void _saveRecord(String riceType, List<BrewingProcess> processes) {
    // ロットIDのチェック
    if (_selectedRiceLotIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('白米ロットを選択してください')),
      );
      return;
    }
    
    // 吸水率の解析
    double? absorptionRate;
    try {
      if (_absorptionRateController.text.isNotEmpty) {
        absorptionRate = double.parse(_absorptionRateController.text);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('吸水率の値が不正です')),
      );
      return;
    }
    
    // 吸水率のチェック
    if (absorptionRate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('吸水率を入力してください')),
      );
      return;
    }
    
    // 洗米記録オブジェクトの作成
    final record = WashingRecord(
      date: _selectedDate,
      riceLotIds: _selectedRiceLotIds,
      absorptionRate: absorptionRate,
      memo: _memoController.text.isEmpty ? null : _memoController.text,
      riceEvaluation: _riceEvaluation,
      steamedEvaluation: _steamedEvaluation,
    );
    
    // 既存記録の検索
    final riceProvider = Provider.of<RiceDataProvider>(context, listen: false);
    final existingRecords = riceProvider.getWashingRecordsByDate(_selectedDate);
    bool isUpdate = false;
    
    for (var existingRecord in existingRecords) {
      // より厳密なマッチング条件が必要かもしれない
      if (existingRecord.riceLotIds.isNotEmpty) {
        final riceLot = riceProvider.getRiceLotById(existingRecord.riceLotIds.first);
        if (riceLot != null && riceLot.riceType == riceType) {
          riceProvider.updateWashingRecord(record);
          isUpdate = true;
          break;
        }
      }
    }
    
    // 新規記録の場合
    if (!isUpdate) {
      riceProvider.addWashingRecord(record);
    }
    
    // 工程の情報も更新（吸水率の反映）
    for (var process in processes) {
      Provider.of<BrewingDataProvider>(context, listen: false)
          .updateProcessData(
            process.jungoId, 
            process.name, 
            waterAbsorption: absorptionRate,
          );
    }
    
    // フォームをクリア
    _absorptionRateController.clear();
    _memoController.clear();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('洗米記録を保存しました')),
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
  
  // 指定日の洗米工程を取得
  List<BrewingProcess> _getWashingProcessesForDate(List<JungoData> jungoList, DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    return jungoList.expand((jungo) => jungo.processes).where((process) => 
      (process.type == ProcessType.washing || 
       process.type == ProcessType.koji || 
       process.type == ProcessType.moromi) && 
      DateFormat('yyyy-MM-dd').format(process.washingDate) == dateStr
    ).toList();
  }
}