import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';
import 'package:intl/intl.dart';

class SyncStatusWidget extends StatelessWidget {
  const SyncStatusWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BrewingDataProvider>(context);
    final isSyncing = provider.isSyncing;
    final lastSyncTime = provider.lastSyncTime;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSyncing)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        else
          Icon(
            lastSyncTime != null ? Icons.cloud_done : Icons.cloud_off,
            size: 16,
            color: Colors.white,
          ),
        const SizedBox(width: 8),
        if (lastSyncTime != null)
          Text(
            '最終同期: ${DateFormat('HH:mm').format(lastSyncTime!)}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          )
        else
          const Text(
            '未同期',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
      ],
    );
  }
}