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
  double? _currentMoisture;
  
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
    
    // 麹用と掛米用に分離 - 工程タイプと名前の両方を考慮
    final kojiProcesses = washingProcesses.where((p) => 
      p.type == ProcessType.koji || // 工程タイプが麹
      p.name.toLowerCase().contains('麹') // または名前に「麹」が含まれる
    ).toList();
    
    final kakemaiProcesses = washingProcesses.where((p) => 
      p.type != ProcessType.koji && // 工程タイプが麹ではない
      !p.name.toLowerCase().contains('麹') // かつ名前に「麹」が含まれない
    ).toList();
    
    // 品種と用途でグループ化
    final kojiGroups = _groupProcessesByRiceTypeAndUsage(kojiProcesses);
    final kakemaiGroups = _groupProcessesByRiceTypeAndUsage(kakemaiProcesses);
    
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.grain, color: Colors.amber.shade800),
                                const SizedBox(width: 8),
                                Text(
                                  '麹米',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...kojiGroups.entries.map((entry) => 
                            _buildRiceGroup(
                              riceType: entry.key.split('|')[0],
                              usage: entry.key.split('|')[1],
                              processes: entry.value, 
                              existingRecords: existingRecords,
                              isKoji: true,
                            )
                          ).toList(),
                          const SizedBox(height: 16),
                        ],
                        
                        // 掛米グループ
                        if (kakemaiGroups.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.rice_bowl, color: Colors.blue.shade800),
                                const SizedBox(width: 8),
                                Text(
                                  '掛米',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...kakemaiGroups.entries.map((entry) => 
                            _buildRiceGroup(
                              riceType: entry.key.split('|')[0],
                              usage: entry.key.split('|')[1],
                              processes: entry.value, 
                              existingRecords: existingRecords,
                              isKoji: false,
                            )
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
  
  // 工程を品種と用途でグループ化（キーは "品種|用途" 形式）
  Map<String, List<BrewingProcess>> _groupProcessesByRiceTypeAndUsage(List<BrewingProcess> processes) {
    final Map<String, List<BrewingProcess>> groups = {};
    
    for (var process in processes) {
      // 用途を決定（プロセス名から）
      String usage = _determineUsage(process.name);
      
      // キーを作成（品種と用途の組み合わせ）
      String key = "${process.riceType}|$usage";
      
      if (groups.containsKey(key)) {
        groups[key]!.add(process);
      } else {
        groups[key] = [process];
      }
    }
    
    return groups;
  }
  
  // プロセス名から用途を決定
  String _determineUsage(String processName) {
    final name = processName.toLowerCase();
    
    if (name.contains('モト')) {
      return 'モト';
    } else if (name.contains('添') || name.contains('初')) {
      return '添/初';
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
  
  // 白米グループウィジェットを構築
  Widget _buildRiceGroup({
    required String riceType,
    required String usage,
    required List<BrewingProcess> processes,
    required List<WashingRecord> existingRecords,
    required bool isKoji,
  }) {
    // 品種と用途に対応する既存の洗米記録を検索
    WashingRecord? existingRecord;
    for (var record in existingRecords) {
      // ロットIDと品種のマッチングはより複雑になる可能性がある
      if (record.riceLotIds.isNotEmpty) {
        final riceLot = Provider.of<RiceDataProvider>(context, listen: false)
            .getRiceLotById(record.riceLotIds.first);
        
        if (riceLot != null && riceLot.riceType == riceType) {
          // 用途も確認（より詳細なマッチングのため）
          bool matchesUsage = true; // 現時点では単純化
          
          if (matchesUsage) {
            existingRecord = record;
            break;
          }
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
    
    // 既存値があれば設定
    if (existingRecord != null) {
      if (existingRecord.riceLotIds.isNotEmpty) {
        _selectedRiceLotIds = existingRecord.riceLotIds;
        
        // 選択されたロットの水分値を設定
        final lot = Provider.of<RiceDataProvider>(context, listen: false)
            .getRiceLotById(_selectedRiceLotIds.first);
        if (lot != null) {
          _currentMoisture = lot.moisture;
        }
      }
      
      _absorptionRateController.text = existingRecord.absorptionRate.toString();
      if (existingRecord.memo != null) {
        _memoController.text = existingRecord.memo!;
      }
      _riceEvaluation = existingRecord.riceEvaluation;
      _steamedEvaluation = existingRecord.steamedEvaluation;
    } else {
      // 既存値がなければクリア
      _absorptionRateController.clear();
      _memoController.clear();
      _riceEvaluation = RiceEvaluation.unknown;
      _steamedEvaluation = RiceEvaluation.unknown;
      _currentMoisture = null;
    }
    
    // カードの色を設定
    Color cardColor = isKoji 
        ? Colors.amber.withOpacity(0.05) 
        : Colors.blue.withOpacity(0.05);
    Color accentColor = isKoji ? Colors.amber : Colors.blue;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accentColor.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$riceType (${processes.first.ricePct}%)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '用途: $usage',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accentColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    '合計: ${totalWeight.toStringAsFixed(1)}kg',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            
            const Divider(height: 24),
            
            // 工程リスト
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: processes.length,
              itemBuilder: (context, index) {
                final process = processes[index];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    isKoji ? Icons.grain : Icons.rice_bowl,
                    color: accentColor,
                    size: 18,
                  ),
                  title: Text('${process.name} (順号${process.jungoId})'),
                  subtitle: Text('${process.amount}kg'),
                );
              },
            ),
            
            const Divider(height: 24),
            
            // 洗米記録部分
            Row(
              children: [
                Icon(Icons.opacity, color: accentColor),
                const SizedBox(width: 8),
                Text(
                  '洗米記録',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 白米ロット選択（ドロップダウン）
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: '白米ロット',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: Colors.white,
              ),
              value: _selectedRiceLotIds.isNotEmpty ? _selectedRiceLotIds.first : null,
              items: [
                ...relatedLots.map((lot) => DropdownMenuItem(
                  value: lot.lotId,
                  child: Text(
                    '${lot.lotId} - ${lot.riceType} (${lot.origin}, ${lot.polishingRatio}%, No.${lot.polishingNo ?? "なし"})',
                    style: const TextStyle(fontSize: 13),
                  ),
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
                    
                    // 選択されたロットの水分値を取得
                    final lot = Provider.of<RiceDataProvider>(context, listen: false)
                        .getRiceLotById(value);
                    if (lot != null) {
                      _currentMoisture = lot.moisture;
                    }
                  });
                }
              },
            ),
            
            // 白米水分表示（選択されたロットから）
            if (_currentMoisture != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.water_drop, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      '白米水分: ${_currentMoisture!.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // 吸水率入力
            TextField(
              controller: _absorptionRateController,
              decoration: InputDecoration(
                labelText: '吸水率 (%)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            
            const SizedBox(height: 12),
            
            // 評価
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<RiceEvaluation>(
                    decoration: InputDecoration(
                      labelText: '白米評価',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    value: existingRecord?.riceEvaluation ?? _riceEvaluation,
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
                    decoration: InputDecoration(
                      labelText: '蒸米評価',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    value: existingRecord?.steamedEvaluation ?? _steamedEvaluation,
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
              decoration: InputDecoration(
                labelText: 'メモ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: Colors.white,
              ),
              maxLines: 3,
            ),
            
            const SizedBox(height: 16),
            
            // 保存ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('保存'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _saveRecord(riceType, usage, processes),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  dateFormat.format(_selectedDate),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
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
  void _saveRecord(String riceType, String usage, List<BrewingProcess> processes) {
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
      // より厳密なマッチング条件
      if (existingRecord.riceLotIds.isNotEmpty) {
        final riceLot = riceProvider.getRiceLotById(existingRecord.riceLotIds.first);
        if (riceLot != null && riceLot.riceType == riceType) {
          // 用途やその他の条件も確認できる
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
    _riceEvaluation = RiceEvaluation.unknown;
    _steamedEvaluation = RiceEvaluation.unknown;
    _currentMoisture = null;
    
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