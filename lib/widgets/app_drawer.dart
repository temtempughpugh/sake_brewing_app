// lib/widgets/app_drawer.dart
import 'package:flutter/material.dart';
import 'package:sake_brewing_app/screens/home_screen.dart';
import 'package:sake_brewing_app/screens/jungo_list_screen.dart';
import 'package:sake_brewing_app/screens/koji_screen.dart';
// 新しい画面のインポート（後で実装）
import 'package:sake_brewing_app/screens/rice_lot_screen.dart';
import 'package:sake_brewing_app/screens/washing_record_screen.dart';
import 'package:sake_brewing_app/screens/dekoji_distribution_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.wine_bar,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '日本酒醸造管理',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildDrawerItem(
            context,
            title: 'ホーム画面',
            icon: Icons.home,
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
          ),
          _buildDrawerItem(
            context,
            title: '順号一覧',
            icon: Icons.list,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const JungoListScreen()),
              );
            },
          ),
          _buildDrawerItem(
            context,
            title: '麹管理',
            icon: Icons.grain,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const KojiScreen()),
              );
            },
          ),
          // 出麹配分メニューアイテム追加
          _buildDrawerItem(
            context,
            title: '出麹配分',
            icon: Icons.gesture,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DekojiDistributionScreen()),
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '原料管理',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildDrawerItem(
            context,
            title: '白米ロット管理',
            icon: Icons.inventory,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RiceLotScreen()),
              );
            },
          ),
          _buildDrawerItem(
            context,
            title: '洗米記録',
            icon: Icons.opacity,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WashingRecordScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(title),
      onTap: onTap,
    );
  }
}