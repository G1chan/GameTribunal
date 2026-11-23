import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'data/mock_data.dart';
import 'firebase_options.dart';
import 'screens/home_page.dart';
import 'screens/login.dart';
import 'services/ai_moderation_engine.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 엔진만 준비하고 대용량 모델 다운로드는 프로필에서 사용자가 시작합니다.
  try {
    await AiModerationEngine.instance.initialize();
    if (kIsWeb && const bool.fromEnvironment('GEMMA_AUTO_DOWNLOAD')) {
      unawaited(AiModerationEngine.instance.downloadAndActivate());
    }
  } catch (e) {
    debugPrint('AI 엔진 초기화 건너뜀: $e');
  }

  runApp(const GameTribunalApp());
}

class GameTribunalApp extends StatelessWidget {
  const GameTribunalApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '겜문철',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _AuthGate(),
      );
}

/// 앱 시작 시 기존 로그인 상태를 확인해 첫 화면을 결정합니다.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final Future<User?> _initialUserFuture;

  @override
  void initState() {
    super.initState();
    _initialUserFuture = AuthService.instance.authStateChanges.first;
  }

  void _syncNickname(User user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      appStore.user.nickname = displayName;
      return;
    }
    final email = user.email;
    if (email != null && email.contains('@')) {
      appStore.user.nickname = email.split('@').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: _initialUserFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          _syncNickname(user);
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}