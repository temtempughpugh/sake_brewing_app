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
    
    return MaterialApp(
      title: '日本酒醸造管理',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          primary: const Color(0xFF1976D2),
          secondary: const Color(0xFF2ECC71),
          tertiary: const Color(0xFFE74C3C),
          surfaceVariant: const Color(0xFFF5F5F5),
          background: const Color(0xFFF8F8F8),
        ),
        textTheme: GoogleFonts.notoSansTextTheme(textTheme).copyWith(
          // 必要に応じてテキストスタイルをカスタマイズ
          titleLarge: GoogleFonts.notoSans(
            textStyle: textTheme.titleLarge,
            fontWeight: FontWeight.bold,
          ),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Color(0xFF1976D2),
          foregroundColor: Colors.white,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
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