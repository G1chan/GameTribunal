import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'screens/login.dart';
import 'services/ai_moderation_engine.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 엔진만 준비하고 대용량 모델 다운로드는 프로필에서 사용자가 시작합니다.
  await AiModerationEngine.instance.initialize();
  if (kIsWeb && const bool.fromEnvironment('GEMMA_AUTO_DOWNLOAD')) {
    unawaited(AiModerationEngine.instance.downloadAndActivate());
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
    home: const LoginPage(),
  );
}
