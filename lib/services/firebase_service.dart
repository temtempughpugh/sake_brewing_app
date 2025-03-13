import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sake_brewing_app/firebase_options.dart'; // 追加: プロジェクトに合わせたパスを指定

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  
  factory FirebaseService() {
    return _instance;
  }
  
  FirebaseService._internal();
  
  late final FirebaseApp _app;
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;
  User? _currentUser;
  final Connectivity _connectivity = Connectivity();
  
  FirebaseAuth get auth => _auth;
  FirebaseFirestore get firestore => _firestore;
  User? get currentUser => _currentUser;

  Future<void> initialize() async {
    try {
      // Firebase初期化時にoptionsを指定
      _app = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      
      _currentUser = _auth.currentUser;
      
      _auth.authStateChanges().listen((User? user) {
        _currentUser = user;
        debugPrint('Auth状態変更: ${user?.uid ?? 'ログアウト'}');
      });
      
      debugPrint('Firebase初期化成功');
    } catch (e) {
      debugPrint('Firebase初期化エラー: $e');
      rethrow;
    }
  }

  Future<bool> isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      _currentUser = userCredential.user;
      return _currentUser;
    } catch (e) {
      debugPrint('匿名サインインエラー: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
  }
}