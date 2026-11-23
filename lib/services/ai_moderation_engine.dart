import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import '../models/moderation_result.dart';
import 'moderation_service.dart';

/// Gemma/LiteRT-LM 기반의 온디바이스 문맥 분류기입니다.
///
/// 웹은 Gemma 4 E2B 웹 번들을, 모바일은 Gemma 3 1B 번들을 사용합니다.
/// 대용량 모델은 [downloadAndActivate]를 통해 사용자 동의 후 설치합니다.
class AiModerationEngine implements FlutterEdgeAiModerator {
  AiModerationEngine._();
  static final instance = AiModerationEngine._();
  bool _initialized = false;
  bool _modelReady = false;
  // 공식 LiteRT Community Gemma 3 1B IT (int4, 약 0.6 GB) 배포 위치입니다.
  // Gemma 약관 수락 뒤 발급한 Hugging Face 토큰은 빌드 인자로만 전달합니다.
  static const _modelRepository = 'litert-community/Gemma3-1B-IT';
  static const _modelFile = 'Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm';
  static const _huggingFaceToken = String.fromEnvironment('GEMMA_HF_TOKEN');
  // LiteRT-LM 웹 엔진 전용 Gemma 4 E2B export (약 2 GB, ungated).
  static const _webModelUrl = String.fromEnvironment(
    'GEMMA_WEB_MODERATION_MODEL_URL',
    defaultValue: 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it-web.litertlm',
  );
  bool get isReady => _modelReady;

  Future<void> initialize() async {
    if (_initialized) return;
    await FlutterEdgeAi.initialize(inferenceEngines: [LiteRtLmEngine()]);
    _initialized = true;
  }

  /// 사용자가 명시적으로 요청했을 때만 대용량 모델을 내려받아 활성화합니다.
  Future<void> downloadAndActivate() async {
    await initialize();
    if (kIsWeb) {
      await FlutterEdgeAi.installModel(
        modelType: ModelType.gemma4,
        fileType: ModelFileType.litertlm,
      ).fromNetwork(_webModelUrl).install();
    } else {
      if (_huggingFaceToken.isEmpty) {
        throw StateError('모바일에서는 GEMMA_HF_TOKEN 설정 후 Gemma 3 모델을 다운로드할 수 있습니다.');
      }
      await FlutterEdgeAi.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.litertlm,
      ).fromHuggingFace(_modelRepository, file: _modelFile, token: _huggingFaceToken).install();
    }
    _modelReady = true;
  }

  @override
  Future<ModerationResult?> classify(String text, ModerationContext context) async {
    if (!_modelReady) return null;
    try {
      await initialize();
      final model = await FlutterEdgeAi.getActiveModel(maxTokens: 180);
      final session = await model.openSession();
      try {
        await session.addQueryChunk(Message(text: _prompt(text, context), isUser: true));
        final raw = '${await session.getResponse()}';
        return _parse(raw);
      } finally {
        await session.close();
        await model.close();
      }
    } catch (_) {
      // 모델 오류 시에도 앱의 필수 입력 흐름은 로컬 정책으로 계속 보호합니다.
      _modelReady = false;
      return null;
    }
  }

  String _prompt(String text, ModerationContext context) => '''
You are a Korean game-community content moderation classifier.
Classify the user's text for profanity, harassment, hate speech, threats,
sexual harassment, targeted insults, and evasion using punctuation or spacing.
Context: ${context.name}.
Return ONLY valid JSON with exactly these fields:
{"action":"allow|warn|block|review","reason":"short Korean reason"}
Use block for hateful, threatening, severe abusive, sexual or targeted harassment.
Use warn for mild profanity or hostile language. Use review when uncertain.
Text: ${jsonEncode(text)}
''';

  ModerationResult _parse(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return const ModerationResult(action: ModerationAction.review, message: 'AI 판정 결과를 확인할 수 없어 운영 검토가 필요합니다.');
    final json = jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
    final action = switch (json['action']) {
      'allow' => ModerationAction.allow,
      'warn' => ModerationAction.warn,
      'block' => ModerationAction.block,
      _ => ModerationAction.review,
    };
    final reason = (json['reason'] as String?)?.trim();
    return ModerationResult(action: action, message: reason?.isNotEmpty == true ? reason! : 'AI가 운영 검토가 필요하다고 판단했습니다.', matchedRule: 'gemma_context_classifier');
  }
}
