import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'data/mock_data.dart';
import 'firebase_options.dart';
import 'screens/home_page.dart';
import 'screens/login.dart';
import 'screens/onboarding_page.dart';
import 'services/ai_moderation_engine.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, mode, _) => MaterialApp(
        title: '겜문철',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        home: const _AuthGate(),
      ),
    );
  }
}

/// 앱 시작 시 로그인 세션과 Firestore 유저 프로필을 확인해 첫 화면을 결정합니다.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late Future<UserProfile?> _initialProfileFuture;

  @override
  void initState() {
    super.initState();
    _initialProfileFuture = _loadInitialProfile();
  }

  Future<UserProfile?> _loadInitialProfile() async {
    final user = await AuthService.instance.authStateChanges.first;
    if (user == null) return null;

    final profile = await UserService.instance.ensureUserDocument(user);
    appStore.user.nickname = profile.nickname;
    appStore.user.points = profile.points;
    return profile;
  }

  void _retry() {
    setState(() {
      _initialProfileFuture = _loadInitialProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _initialProfileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '유저 정보를 불러오지 못했습니다.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _retry,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final profile = snapshot.data;
        if (profile == null) {
          return const LoginPage();
        }
        return profile.onboardingCompleted
            ? const HomePage()
            : const OnboardingPage();
      },
    );
  }
}