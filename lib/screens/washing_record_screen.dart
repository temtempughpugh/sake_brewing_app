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
  String _absorptionRateText = '';  // 吸水率の状態を追跡する変数
  RiceEvaluation _riceEvaluation = RiceEvaluation.unknown;
  RiceEvaluation _steamedEvaluation = RiceEvaluation.unknown;
  double? _currentMoisture;
  bool _isProcessingSave = false;  // 保存処理中かどうかを追跡するフラグ
  
  // 選択された白米ロットID
  List<String> _selectedRiceLotIds = [];
  
  @override
  void initState() {
    super.initState();
    _absorptionRateController.addListener(_updateAbsorptionRateText);
  }
  
  void _updateAbsorptionRateText() {
    setState(() {
      _absorptionRateText = _absorptionRateController.text;
    });
  }
  
  @override
  void dispose() {
    _absorptionRateController.removeListener(_updateAbsorptionRateText);
    _absorptionRateController.dispose();
    _memoController.dispose();
    super.dispose();
  }
  
  // ドロップダウンの値を検証するヘルパーメソッド
  String? _validateDropdownValue(List<String> selectedIds, List<RiceData> availableLots) {
    // 選択されたIDがある場合
    if (selectedIds.isNotEmpty) {
      // 選択されたIDが利用可能なロットの中に存在するか確認
      bool idExists = availableLots.any((lot) => lot.lotId == selectedIds.first);
      if (idExists) {
        return selectedIds.first;
      }
    }
    
    // 選択されたIDがない、または利用可能なロットの中に存在しない場合
    return availableLots.isEmpty ? null : availableLots.first.lotId;
  }
  
  @override
  Widget build(BuildContext context) {
    final brewingProvider = Provider.of<BrewingDataProvider>(context);
    final riceProvider = Provider.of<RiceDataProvider>(context);
    
    // 選択された日付の洗米工程を取得（四段も含める）
    final washingProcesses = _getWashingProcessesForDate(brewingProvider.jungoList, _selectedDate);
    
    // 麹用と掛米用に分離 - 工程タイプと名前の両方を考慮
    final kojiProcesses = washingProcesses.where((p) => 
      p.type == ProcessType.koji || // 工程タイプが麹
      p.name.toLowerCase().contains('麹') // または名前に「麹」が含まれる
    ).toList();
    
    // 掛米の場合は四段も含める
    final kakemaiProcesses = washingProcesses.where((p) => 
      (p.type != ProcessType.koji && !p.name.toLowerCase().contains('麹')) || // 麹でない通常の掛米
      p.name.toLowerCase().contains('四段') // または四段工程
    ).toList();
    
    // 品種と用途でグループ化
    final kojiGroups = _groupProcessesByRiceTypeAndUsage(kojiProcesses);
    final kakemaiGroups = _groupProcessesByRiceTypeAndUsage(kakemaiProcesses);
    
    // 選択日の既存洗米記録を取得
    final existingRecords = riceProvider.getWashingRecordsByDate(_selectedDate);
    
    // テーマカラーを取得
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('洗米記録'),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryColor.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            // 日付選択部分（スタイル改善）
            _buildDateSelector(),
            
            // 洗米記録表示部分
            Expanded(
              child: washingProcesses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.water_drop,
                            size: 80,
                            color: Colors.blue.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'この日の洗米予定はありません',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 麹米グループ
                          if (kojiGroups.isNotEmpty) ...[
                            _buildSectionHeader('麹米', Icons.grain, Colors.amber),
                            ...kojiGroups.entries.map((entry) => 
                              _buildRiceGroup(
                                riceType: entry.key.split('|')[0],
                                usage: entry.key.split('|')[1],
                                processes: entry.value, 
                                existingRecords: existingRecords,
                                isKoji: true,
                              )
                            ).toList(),
                            const SizedBox(height: 24),
                          ],
                          
                          // 掛米グループ
                          if (kakemaiGroups.isNotEmpty) ...[
                            _buildSectionHeader('掛米・四段', Icons.rice_bowl, Colors.blue),
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
      ),
    );
  }
  
  // セクションヘッダー
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
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
    
    // 既存値があれば設定（UIの構築前に一度だけ実行）
    if (existingRecord != null && _absorptionRateText.isEmpty) {
      if (existingRecord.riceLotIds.isNotEmpty) {
        _selectedRiceLotIds = existingRecord.riceLotIds;
        
        // 選択されたロットの水分値を設定
        final lot = Provider.of<RiceDataProvider>(context, listen: false)
            .getRiceLotById(_selectedRiceLotIds.first);
        if (lot != null) {
          _currentMoisture = lot.moisture;
        }
      }
      
      // 吸水率が既存ならコントローラにセット
      _absorptionRateController.text = existingRecord.absorptionRate.toString();
      _absorptionRateText = existingRecord.absorptionRate.toString(); // ステート変数も更新
      
      if (existingRecord.memo != null) {
        _memoController.text = existingRecord.memo!;
      }
      _riceEvaluation = existingRecord.riceEvaluation;
      _steamedEvaluation = existingRecord.steamedEvaluation;
    }
    
    // カードの色を設定
    Color cardColor = isKoji 
        ? Colors.amber.withOpacity(0.05) 
        : Colors.blue.withOpacity(0.05);
    Color accentColor = isKoji ? Colors.amber.shade800 : Colors.blue.shade700;
    
    // モダンなカードデザイン
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: accentColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー (グラデーション背景)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withOpacity(0.8),
                  accentColor.withOpacity(0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$riceType (${processes.first.ricePct}%)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '用途: $usage',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${totalWeight.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 工程リスト
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 工程ヘッダー
                Row(
                  children: [
                    Icon(isKoji ? Icons.grain : Icons.rice_bowl, size: 16, color: accentColor),
                    const SizedBox(width: 8),
                    Text(
                      '工程リスト',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: accentColor,
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
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: accentColor.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isKoji ? Icons.grain : Icons.rice_bowl,
                            size: 16,
                            color: accentColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${process.name} (順号${process.jungoId})',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text('${process.amount} kg', style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                
                // 洗米記録部分
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 洗米記録ヘッダー
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
                      const SizedBox(height: 16),
                      
                      // 白米ロット選択（ドロップダウン）
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: '白米ロット',
                            labelStyle: TextStyle(color: accentColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: accentColor),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          value: _validateDropdownValue(_selectedRiceLotIds, relatedLots),
                          items: relatedLots.isEmpty
                              ? [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('ロットを追加してください'),
                                  )
                                ]
                              : relatedLots.map((lot) => DropdownMenuItem(
                                  value: lot.lotId,
                                  child: Text(
                                    '${lot.lotId} - ${lot.riceType} (${lot.polishingRatio}%, No.${lot.polishingNo ?? "なし"})',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                )).toList(),
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
                      ),
                      
                      // 白米水分表示（選択されたロットから）
                      if (_currentMoisture != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.shade100,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.water_drop, size: 18, color: Colors.blue),
                              const SizedBox(width: 12),
                              Text(
                                '白米水分: ${_currentMoisture!.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 16),
                      
                      // 吸水率入力
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _absorptionRateController,
                          decoration: InputDecoration(
                            labelText: '吸水率 (%)',
                            labelStyle: TextStyle(color: accentColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: accentColor),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon: Icon(Icons.percent, color: accentColor.withOpacity(0.5)),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 評価セクション
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '白米評価',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: accentColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: DropdownButtonFormField<RiceEvaluation>(
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    value: existingRecord?.riceEvaluation ?? _riceEvaluation,
                                    items: RiceEvaluation.values.map((eval) => DropdownMenuItem(
                                      value: eval,
                                      child: Text(
                                        eval.toDisplayString(),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: _getEvaluationColor(eval),
                                        ),
                                      ),
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
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '蒸米評価',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: accentColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: DropdownButtonFormField<RiceEvaluation>(
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    value: existingRecord?.steamedEvaluation ?? _steamedEvaluation,
                                    items: RiceEvaluation.values.map((eval) => DropdownMenuItem(
                                      value: eval,
                                      child: Text(
                                        eval.toDisplayString(),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: _getEvaluationColor(eval),
                                        ),
                                      ),
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
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // メモ入力
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _memoController,
                          decoration: InputDecoration(
                            labelText: 'メモ',
                            labelStyle: TextStyle(color: accentColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: accentColor),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          maxLines: 3,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // 保存ボタン
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: _isProcessingSave 
                              ? Container(
                                  width: 20,
                                  height: 20,
                                  padding: const EdgeInsets.all(4),
                                  child: const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(_isProcessingSave ? '保存中...' : '保存'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          onPressed: _isProcessingSave 
                              ? null 
                              : () => _saveRecord(riceType, usage, processes),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // 評価の色を取得
  Color _getEvaluationColor(RiceEvaluation eval) {
    switch (eval) {
      case RiceEvaluation.excellent:
        return Colors.blue;
      case RiceEvaluation.good:
        return Colors.green;
      case RiceEvaluation.fair:
        return Colors.orange;
      case RiceEvaluation.poor:
        return Colors.red;
      case RiceEvaluation.unknown:
        return Colors.grey;
    }
  }
  
  // 日付選択部分
  Widget _buildDateSelector() {
    final dateFormat = DateFormat('yyyy年MM月dd日 (E)', 'ja');
    
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 前日ボタン
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                    _resetFormState(); // フォームの状態をリセット
                  });
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade100,
                  ),
                  child: const Icon(
                    Icons.chevron_left,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            
            // 日付表示
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      dateFormat.format(_selectedDate),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 翌日ボタン
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedDate = _selectedDate.add(const Duration(days: 1));
                    _resetFormState(); // フォームの状態をリセット
                  });
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade100,
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // フォームの状態をリセット
  void _resetFormState() {
    _absorptionRateController.clear();
    _absorptionRateText = '';
    _memoController.clear();
    _riceEvaluation = RiceEvaluation.unknown;
    _steamedEvaluation = RiceEvaluation.unknown;
    _currentMoisture = null;
    _selectedRiceLotIds = [];
  }
  
  // 記録保存処理
  Future<void> _saveRecord(String riceType, String usage, List<BrewingProcess> processes) async {
    // 二重送信防止
    if (_isProcessingSave) {
      return;
    }
    
    // 保存処理中フラグをON
    setState(() {
      _isProcessingSave = true;
    });
    
    // ロットIDのチェック
    if (_selectedRiceLotIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('白米ロットを選択してください')),
      );
      setState(() {
        _isProcessingSave = false;
      });
      return;
    }
    
    // 吸水率の解析 - _absorptionRateTextを使用
    double? absorptionRate;
    try {
      if (_absorptionRateText.isNotEmpty) {
        absorptionRate = double.parse(_absorptionRateText);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('吸水率の値が不正です')),
      );
      setState(() {
        _isProcessingSave = false;
      });
      return;
    }
    
    // 吸水率のチェック
    if (absorptionRate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('吸水率を入力してください')),
      );
      setState(() {
        _isProcessingSave = false;
      });
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
    
    try {
      for (var existingRecord in existingRecords) {
        // より厳密なマッチング条件
        if (existingRecord.riceLotIds.isNotEmpty) {
          final riceLot = riceProvider.getRiceLotById(existingRecord.riceLotIds.first);
          if (riceLot != null && riceLot.riceType == riceType) {
            // 用途やその他の条件も確認できる
            await riceProvider.updateWashingRecord(record);
            isUpdate = true;
            break;
          }
        }
      }
      
      // 新規記録の場合
      if (!isUpdate) {
        await riceProvider.addWashingRecord(record);
      }
      
      // 工程の情報も更新（吸水率の反映）
      for (var process in processes) {
      await Provider.of<BrewingDataProvider>(context, listen: false)
      .updateProcessData(
      process.jungoId, 
      process.name, 
      waterAbsorption: absorptionRate,
    );
      }
      
      // 成功メッセージ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              const Text('洗米記録を保存しました'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      // エラーメッセージ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Text('保存中にエラーが発生しました: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      // 保存処理中フラグをOFF
      setState(() {
        _isProcessingSave = false;
      });
    }
  }
  
  // 日付選択ダイアログ
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ja'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _resetFormState(); // フォームの状態をリセット
      });
    }
  }
  
  // 指定日の洗米工程を取得 (四段も含める)
  List<BrewingProcess> _getWashingProcessesForDate(List<JungoData> jungoList, DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    return jungoList.expand((jungo) => jungo.processes).where((process) => 
      // 洗米、麹、醪の工程を含める
      (process.type == ProcessType.washing || 
       process.type == ProcessType.koji || 
       process.type == ProcessType.moromi ||
       // 四段の工程も含める (ProcessType.other)
       (process.type == ProcessType.other && process.name.toLowerCase().contains('四段'))) && 
      // 選択された日付の洗米工程のみ
      DateFormat('yyyy-MM-dd').format(process.washingDate) == dateStr
    ).toList();
  }
}