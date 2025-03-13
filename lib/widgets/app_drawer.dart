// lib/widgets/app_drawer.dart を修正
import 'package:flutter/material.dart';
import 'package:sake_brewing_app/services/firebase_service.dart';
import 'package:sake_brewing_app/screens/home_screen.dart';
import 'package:sake_brewing_app/screens/auth_screen.dart';
import 'package:sake_brewing_app/screens/jungo_list_screen.dart';
import 'package:sake_brewing_app/screens/koji_screen.dart';
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
          // ドロワーヘッダー
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
          
          // 基本機能
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
          
          // 麹管理セクション
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '麹管理',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildDrawerItem(
            context,
            title: '麹工程管理',
            icon: Icons.grain,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const KojiScreen()),
              );
            },
          ),
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
          
          // 原料管理セクション
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

          // ドロワー内の最後に以下を追加
const Divider(),
ListTile(
  leading: Icon(
    Icons.logout,
    color: Theme.of(context).colorScheme.error,
  ),
  title: const Text('ログアウト'),
  onTap: () async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウト確認'),
        content: const Text('本当にログアウトしますか？\nログアウトするとサーバーデータにアクセスできなくなります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await FirebaseService().signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    }
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