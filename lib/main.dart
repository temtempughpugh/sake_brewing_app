import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';
import 'package:sake_brewing_app/models/rice_data_provider.dart';
import 'package:sake_brewing_app/screens/auth_screen.dart'; // 追加
import 'package:sake_brewing_app/screens/home_screen.dart';
import 'package:sake_brewing_app/services/firebase_service.dart'; // 追加
import 'package:sake_brewing_app/services/notification_service.dart';
import 'package:sake_brewing_app/services/koji_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// main 関数を修正
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Firebaseサービスの初期化
    final firebaseService = FirebaseService();
    await firebaseService.initialize();
    
    // 保存データの読み込みを試みる
    final brewingProvider = BrewingDataProvider();
    await brewingProvider.loadFromLocalStorage();
    
    // 白米データプロバイダーを初期化
    final riceDataProvider = RiceDataProvider();
    
    // 麹サービスを初期化
    final kojiService = KojiService(brewingProvider);
    
    await NotificationService().init();
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => brewingProvider),
          ChangeNotifierProvider(create: (_) => riceDataProvider),
          ChangeNotifierProvider(create: (_) => kojiService),
          Provider.value(value: firebaseService),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    print('初期化エラー: $e');
    // エラーが発生してもアプリを起動できるようにする
    final brewingProvider = BrewingDataProvider();
    final riceDataProvider = RiceDataProvider();
    final kojiService = KojiService(brewingProvider);
    
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => brewingProvider),
          ChangeNotifierProvider(create: (_) => riceDataProvider),
          ChangeNotifierProvider(create: (_) => kojiService),
        ],
        child: const MyApp(),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return MaterialApp(
      title: '日本酒醸造管理',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // 既存のテーマ設定をそのまま保持
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8E7E6D),
          primary: const Color(0xFF8E7E6D),
          secondary: const Color(0xFF6B8E94),
          tertiary: const Color(0xFFAA6A6A),
          surface: const Color(0xFFF5F2EE),
          background: const Color(0xFFF8F6F2),
          onBackground: const Color(0xFF4A4237),
        ),
        textTheme: GoogleFonts.notoSansTextTheme(textTheme).copyWith(
          titleLarge: GoogleFonts.notoSans(
            textStyle: textTheme.titleLarge,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF4A4237),
          ),
          bodyLarge: GoogleFonts.notoSans(
            textStyle: textTheme.bodyLarge,
            color: const Color(0xFF4A4237),
          ),
          bodyMedium: GoogleFonts.notoSans(
            textStyle: textTheme.bodyMedium,
            color: const Color(0xFF4A4237),
          ),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Color(0xFF8E7E6D),
          foregroundColor: Colors.white,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F6F2),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja'),
      ],
      home: const AuthScreen(), // ホーム画面からAuthScreenに変更
    );
  }
}