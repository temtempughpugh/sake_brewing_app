import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';

class CsvInputScreen extends StatefulWidget {
  const CsvInputScreen({Key? key}) : super(key: key);

  @override
  State<CsvInputScreen> createState() => _CsvInputScreenState();
}

class _CsvInputScreenState extends State<CsvInputScreen> {
  final TextEditingController _csvController = TextEditingController();

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CSVデータ入力')),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _csvController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: 'ここにCSVデータを貼り付けてください...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                if (_csvController.text.isNotEmpty) {
                  final provider = Provider.of<BrewingDataProvider>(context, listen: false);
                  provider.loadFromCsv(_csvController.text);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('インポート'),
            ),
          ),
        ],
      ),
    );
  }
}