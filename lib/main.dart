import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sake_brewing_app/models/brewing_data.dart';
import 'package:sake_brewing_app/screens/home_screen.dart';
import 'package:sake_brewing_app/services/notification_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 保存データの読み込みを試みる
  final provider = BrewingDataProvider();
  await provider.loadFromLocalStorage();
  
  await NotificationService().init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => provider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    // ThemeDataの部分を修正

    return MaterialApp(
      title: '日本酒醸造管理',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8E7E6D), // 上品な茶色
          primary: const Color(0xFF8E7E6D),
          secondary: const Color(0xFF6B8E94), // 落ち着いた青緑
          tertiary: const Color(0xFFAA6A6A), // 上品な赤茶
          surface: const Color(0xFFF5F2EE), // 淡いベージュ
          background: const Color(0xFFF8F6F2), // 淡いクリーム色
          onBackground: const Color(0xFF4A4237), // 濃いベージュ（文字色）
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
      home: const HomeScreen(),
    );
  }
}