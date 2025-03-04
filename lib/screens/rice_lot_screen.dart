// lib/screens/rice_lot_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sake_brewing_app/models/rice_data.dart';
import 'package:sake_brewing_app/models/rice_data_provider.dart';

class RiceLotScreen extends StatefulWidget {
  const RiceLotScreen({Key? key}) : super(key: key);

  @override
  State<RiceLotScreen> createState() => _RiceLotScreenState();
}

class _RiceLotScreenState extends State<RiceLotScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RiceDataProvider>(context);
    final riceLots = provider.riceLots;
    
    // 検索フィルタリング
    final filteredLots = riceLots.where((lot) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return lot.lotId.toLowerCase().contains(query) ||
             lot.riceType.toLowerCase().contains(query) ||
             lot.origin.toLowerCase().contains(query);
    }).toList();
    
    // ロットIDでソート
    filteredLots.sort((a, b) => b.lotId.compareTo(a.lotId)); // 新しいロットを上に
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('白米ロット管理'),
      ),
      body: Column(
        children: [
          // 検索バー
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ロット検索...',
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
          
          // ロットリスト
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredLots.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '白米ロットがありません',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('ロットを追加'),
                              onPressed: () => _showAddLotDialog(context),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredLots.length,
                        itemBuilder: (context, index) {
                          final lot = filteredLots[index];
                          return _buildRiceLotCard(context, lot);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddLotDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRiceLotCard(BuildContext context, RiceData lot) {
    final dateFormat = DateFormat('yyyy年MM月dd日');
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _showLotDetailDialog(context, lot),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ロット: ${lot.lotId}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: lot.isNew 
                              ? Colors.green.shade100 
                              : Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          lot.isNew ? '新米' : '古米',
                          style: TextStyle(
                            color: lot.isNew 
                                ? Colors.green.shade800 
                                : Colors.amber.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 編集ボタン追加
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _showEditLotDialog(context, lot),
                        tooltip: 'ロット情報を編集',
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('品種: ${lot.riceType}'),
                        const SizedBox(height: 4),
                        Text('産地: ${lot.origin}'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('精米歩合: ${lot.polishingRatio}%'),
                        const SizedBox(height: 4),
                        Text('白米水分: ${lot.moisture.toStringAsFixed(1)}%'),
                      ],
                    ),
                  ),
                ],
              ),
              if (lot.arrivalDate != null) ...[
                const SizedBox(height: 4),
                Text('入荷日: ${dateFormat.format(lot.arrivalDate!)}'),
              ],
              if (lot.polishingNo != null) ...[
                const SizedBox(height: 4),
                Text('精米No: ${lot.polishingNo}'),
              ],
              const SizedBox(height: 8),
              if (lot.washingRecords.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.opacity, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      '洗米記録: ${lot.washingRecords.length}件',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ロット編集ダイアログ
  Future<void> _showEditLotDialog(BuildContext context, RiceData lot) async {
    final provider = Provider.of<RiceDataProvider>(context, listen: false);
    
    String riceType = lot.riceType;
    String origin = lot.origin;
    int polishingRatio = lot.polishingRatio;
    DateTime? arrivalDate = lot.arrivalDate;
    String? polishingNo = lot.polishingNo;
    double moisture = lot.moisture;
    bool isNew = lot.isNew;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ロット ${lot.lotId} 編集'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 品種選択
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: '品種',
                  border: OutlineInputBorder(),
                ),
                value: riceType,
                items: RiceDataProvider.riceTypes
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    riceType = value;
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // 産地選択
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: '産地',
                  border: OutlineInputBorder(),
                ),
                value: origin,
                items: RiceDataProvider.origins
                    .map((org) => DropdownMenuItem(
                          value: org,
                          child: Text(org),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    origin = value;
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // 精米歩合
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '精米歩合 (%)',
                  border: OutlineInputBorder(),
                ),
                initialValue: polishingRatio.toString(),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  polishingRatio = int.tryParse(value) ?? 70;
                },
              ),
              const SizedBox(height: 16),
              
              // 白米水分
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '白米水分 (%)',
                  border: OutlineInputBorder(),
                ),
                initialValue: moisture.toString(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  moisture = double.tryParse(value) ?? 14.5;
                },
              ),
              const SizedBox(height: 16),
              
              // 入荷日
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: arrivalDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    arrivalDate = date;
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '入荷日（任意）',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    arrivalDate != null
                        ? DateFormat('yyyy年MM月dd日').format(arrivalDate!)
                        : '選択してください',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // 精米No
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '精米No（任意）',
                  border: OutlineInputBorder(),
                ),
                initialValue: polishingNo ?? '',
                onChanged: (value) {
                  polishingNo = value.isEmpty ? null : value;
                },
              ),
              const SizedBox(height: 16),
              
              // 新米/古米選択
              Row(
                children: [
                  const Text('米の種類:'),
                  const SizedBox(width: 16),
                  ChoiceChip(
                    label: const Text('新米'),
                    selected: isNew,
                    onSelected: (selected) {
                      if (selected) {
                        isNew = true;
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('古米'),
                    selected: !isNew,
                    onSelected: (selected) {
                      if (selected) {
                        isNew = false;
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              // 更新したロットを作成
              final updatedLot = RiceData(
                lotId: lot.lotId,
                riceType: riceType,
                origin: origin,
                polishingRatio: polishingRatio,
                arrivalDate: arrivalDate,
                polishingNo: polishingNo,
                moisture: moisture,
                isNew: isNew,
                washingRecords: lot.washingRecords,
              );
              
              // プロバイダーで更新
              provider.updateRiceLot(updatedLot);
              
              Navigator.pop(context);
              
              // 成功メッセージ表示
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ロット情報を更新しました')),
              );
            },
            child: const Text('更新'),
          ),
        ],
      ),
    );
  }

  // 白米ロット追加ダイアログ
  Future<void> _showAddLotDialog(BuildContext context) async {
    final provider = Provider.of<RiceDataProvider>(context, listen: false);
    final newLotId = provider.generateNextLotId();
    
    String riceType = RiceDataProvider.riceTypes.first;
    String origin = RiceDataProvider.origins.first;
    int polishingRatio = 70;
    DateTime? arrivalDate;
    String? polishingNo;
    double moisture = 14.5;
    bool isNew = true;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新規白米ロット登録'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ロットID: $newLotId', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              // 品種選択
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: '品種',
                  border: OutlineInputBorder(),
                ),
                value: riceType,
                items: RiceDataProvider.riceTypes
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    riceType = value;
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // 産地選択
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: '産地',
                  border: OutlineInputBorder(),
                ),
                value: origin,
                items: RiceDataProvider.origins
                    .map((org) => DropdownMenuItem(
                          value: org,
                          child: Text(org),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    origin = value;
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // 精米歩合
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '精米歩合 (%)',
                  border: OutlineInputBorder(),
                ),
                initialValue: polishingRatio.toString(),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  polishingRatio = int.tryParse(value) ?? 70;
                },
              ),
              const SizedBox(height: 16),
              
              // 白米水分
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '白米水分 (%)',
                  border: OutlineInputBorder(),
                ),
                initialValue: moisture.toString(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  moisture = double.tryParse(value) ?? 14.5;
                },
              ),
              const SizedBox(height: 16),
              
              // 入荷日
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    arrivalDate = date;
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '入荷日（任意）',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    arrivalDate != null
                        ? DateFormat('yyyy年MM月dd日').format(arrivalDate!)
                        : '選択してください',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // 精米No
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '精米No（任意）',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  polishingNo = value.isEmpty ? null : value;
                },
              ),
              const SizedBox(height: 16),
              
              // 新米/古米選択
              Row(
                children: [
                  const Text('米の種類:'),
                  const SizedBox(width: 16),
                  ChoiceChip(
                    label: const Text('新米'),
                    selected: isNew,
                    onSelected: (selected) {
                      if (selected) {
                        isNew = true;
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('古米'),
                    selected: !isNew,
                    onSelected: (selected) {
                      if (selected) {
                        isNew = false;
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              // 新しいロットを作成
              final newLot = RiceData(
                lotId: newLotId,
                riceType: riceType,
                origin: origin,
                polishingRatio: polishingRatio,
                arrivalDate: arrivalDate,
                polishingNo: polishingNo,
                moisture: moisture,
                isNew: isNew,
                washingRecords: [],
              );
              
              // プロバイダーに追加
              provider.addRiceLot(newLot);
              
              Navigator.pop(context);
              
              // 成功メッセージ表示
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('新規ロットを登録しました')),
              );
            },
            child: const Text('登録'),
          ),
        ],
      ),
    );
  }

  // ロット詳細ダイアログ
  Future<void> _showLotDetailDialog(BuildContext context, RiceData lot) async {
    final provider = Provider.of<RiceDataProvider>(context, listen: false);
    final dateFormat = DateFormat('yyyy年MM月dd日');
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ロット ${lot.lotId} 詳細'),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () {
                Navigator.pop(context); // 詳細ダイアログを閉じる
                _showEditLotDialog(context, lot); // 編集ダイアログを開く
              },
              tooltip: '編集',
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 基本情報
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('基本情報', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Divider(),
                      _buildInfoItem('品種', lot.riceType),
                      _buildInfoItem('産地', lot.origin),
                      _buildInfoItem('精米歩合', '${lot.polishingRatio}%'),
                      _buildInfoItem('白米水分', '${lot.moisture.toStringAsFixed(1)}%'),
                      if (lot.arrivalDate != null) 
                        _buildInfoItem('入荷日', dateFormat.format(lot.arrivalDate!)),
                      if (lot.polishingNo != null) 
                        _buildInfoItem('精米No', lot.polishingNo!),
                      _buildInfoItem('種類', lot.isNew ? "新米" : "古米"),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 洗米記録
              if (lot.washingRecords.isNotEmpty) ...[
                const Text('洗米記録', style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                ...lot.washingRecords.map((record) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('日付: ${dateFormat.format(record.date)}'),
                        Text('洗米時間: ${record.minutes}分${record.seconds}秒'),
                        Text('吸水率: ${record.absorptionRate.toStringAsFixed(1)}%'),
                        Text('バッチ重量: ${record.batchWeight.toStringAsFixed(1)}kg'),
                        Text('バッチモード: ${record.batchMode}'),
                      ],
                    ),
                  ),
                )),
              ] else ...[
                const Text('洗米記録はありません', style: TextStyle(fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          TextButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('削除の確認'),
                  content: Text('ロット ${lot.lotId} を削除してもよろしいですか？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('キャンセル'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('削除', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              
              if (confirm == true) {
                provider.deleteRiceLot(lot.lotId);
                Navigator.pop(context);
                
                // 成功メッセージ表示
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ロットを削除しました')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
          ElevatedButton(
            onPressed: () {
              // 洗米記録追加ダイアログを表示
              _showAddWashingRecordDialog(context, lot);
            },
            child: const Text('洗米記録を追加'),
          ),
        ],
      ),
    );
  }
  
  // 情報項目ウィジェット
  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 洗米記録追加ダイアログ
  Future<void> _showAddWashingRecordDialog(BuildContext context, RiceData lot) async {
    final provider = Provider.of<RiceDataProvider>(context, listen: false);
    
    DateTime date = DateTime.now();
    int minutes = 5;
    int seconds = 0;
    double absorptionRate = 30.0;
    double batchWeight = 10.0;
    int batchMode = 1;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${lot.lotId} 洗米記録追加'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 日付選択
              InkWell(
                onTap: () async {
                  final selectedDate = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (selectedDate != null) {
                    date = selectedDate;
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '洗米日',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    DateFormat('yyyy年MM月dd日').format(date),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // 分秒入力 (横並び)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: '分',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: minutes.toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        minutes = int.tryParse(value) ?? 5;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: '秒',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: seconds.toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        seconds = int.tryParse(value) ?? 0;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 吸水率
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '吸水率 (%)',
                  border: OutlineInputBorder(),
                ),
                initialValue: absorptionRate.toString(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  absorptionRate = double.tryParse(value) ?? 30.0;
                },
              ),
              const SizedBox(height: 16),
              
              // バッチ重量
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'バッチ重量 (kg)',
                  border: OutlineInputBorder(),
                ),
                initialValue: batchWeight.toString(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  batchWeight = double.tryParse(value) ?? 10.0;
                },
              ),
              const SizedBox(height: 16),
              
              // バッチモード
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'バッチモード',
                  border: OutlineInputBorder(),
                ),
                value: batchMode,
                items: [1, 2, 3, 4]
                    .map((mode) => DropdownMenuItem(
                          value: mode,
                          child: Text('モード $mode'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    batchMode = value;
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              // 洗米記録を作成
              final washingRecord = RiceWashingData(
                date: date,
                minutes: minutes,
                seconds: seconds,
                absorptionRate: absorptionRate,
                batchWeight: batchWeight,
                batchMode: batchMode,
              );
              
              // ロットを更新（洗米記録を追加）
              final updatedLot = RiceData(
                lotId: lot.lotId,
                riceType: lot.riceType,
                origin: lot.origin,
                polishingRatio: lot.polishingRatio,
                arrivalDate: lot.arrivalDate,
                polishingNo: lot.polishingNo,
                moisture: lot.moisture,
                isNew: lot.isNew,
                washingRecords: [...lot.washingRecords, washingRecord],
              );
              
              // プロバイダーを更新
              provider.updateRiceLot(updatedLot);
              
              // ダイアログを閉じる
              Navigator.pop(context); // 洗米記録ダイアログを閉じる
              Navigator.pop(context); // ロット詳細ダイアログを閉じる
              
              // 成功メッセージを表示
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('洗米記録を追加しました')),
              );
            },
            child: const Text('登録'),
          ),
        ],
      ),
    );
  }
}