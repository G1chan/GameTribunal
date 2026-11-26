import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import '../models/moderation_result.dart';
import 'moderation_service.dart';

/// 판정 리포트 AI 3줄 요약 결과 모델
class VerdictAiSummary {
  const VerdictAiSummary({
    required this.issueLine,
    required this.partyALine,
    required this.partyBLine,
    required this.verdictLine,
    required this.usedOnDeviceModel,
  });

  final String issueLine;
  final String partyALine;
  final String partyBLine;
  final String verdictLine;
  final bool usedOnDeviceModel;
}

/// Gemma/LiteRT-LM 기반의 온디바이스 문맥 분류 및 판결 요약 엔진입니다.
///
/// 웹은 Gemma 4 E2B 웹 번들을, 모바일은 Gemma 3 1B 번들을 사용합니다.
/// 대용량 모델은 [downloadAndActivate]를 통해 사용자 동의 후 설치합니다.
class AiModerationEngine implements FlutterEdgeAiModerator {
  AiModerationEngine._();
  static final instance = AiModerationEngine._();
  bool _initialized = false;
  bool _modelReady = false;

  static const _modelRepository = 'litert-community/Gemma3-1B-IT';
  static const _modelFile =
      'Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm';
  static const _huggingFaceToken = String.fromEnvironment('GEMMA_HF_TOKEN');
  static const _webModelUrl = String.fromEnvironment(
    'GEMMA_WEB_MODERATION_MODEL_URL',
    defaultValue:
        'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it-web.litertlm',
  );

  bool get isReady => _modelReady;

  Future<void> initialize() async {
    if (_initialized) return;
    await FlutterEdgeAi.initialize(
      inferenceEngines: [const LiteRtLmEngine()],
    );
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
        throw StateError(
          '모바일에서는 GEMMA_HF_TOKEN 설정 후 Gemma 3 모델을 다운로드할 수 있습니다.',
        );
      }
      await FlutterEdgeAi.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.litertlm,
      )
          .fromHuggingFace(
            _modelRepository,
            file: _modelFile,
            token: _huggingFaceToken,
          )
          .install();
    }
    _modelReady = true;
  }

  @override
  Future<ModerationResult?> classify(
    String text,
    ModerationContext context,
  ) async {
    if (!_modelReady) return null;
    try {
      await initialize();
      final model = await FlutterEdgeAi.getActiveModel(maxTokens: 180);
      final session = await model.openSession();
      try {
        await session.addQueryChunk(
          Message(text: _prompt(text, context), isUser: true),
        );
        final raw = await session.getResponse();
        return _parse(raw);
      } finally {
        await session.close();
        await model.close();
      }
    } catch (_) {
      _modelReady = false;
      return null;
    }
  }

  /// 사건 진술·투표 비율·상위 댓글을 바탕으로 판정 리포트 3줄 요약 생성
  Future<VerdictAiSummary> summarizeVerdict({
    required String game,
    required String title,
    required String description,
    required String partyAStatement,
    required String partyBStatement,
    required int leftPercent,
    required int rightPercent,
    required int totalVotes,
    required bool isClosed,
    required List<String> topComments,
  }) async {
    if (_modelReady) {
      try {
        await initialize();
        final model = await FlutterEdgeAi.getActiveModel(maxTokens: 320);
        final session = await model.openSession();
        try {
          final prompt = _summaryPrompt(
            game: game,
            title: title,
            description: description,
            partyAStatement: partyAStatement,
            partyBStatement: partyBStatement,
            leftPercent: leftPercent,
            rightPercent: rightPercent,
            totalVotes: totalVotes,
            isClosed: isClosed,
            topComments: topComments,
          );
          await session.addQueryChunk(Message(text: prompt, isUser: true));
          final raw = await session.getResponse();
          final parsed = _parseSummary(raw);
          if (parsed != null) return parsed;
        } finally {
          await session.close();
          await model.close();
        }
      } catch (e) {
        debugPrint('AI 판결 요약 추론 폴백: $e');
      }
    }

    return _buildStructuredFallback(
      game: game,
      title: title,
      partyAStatement: partyAStatement,
      partyBStatement: partyBStatement,
      leftPercent: leftPercent,
      rightPercent: rightPercent,
      totalVotes: totalVotes,
      isClosed: isClosed,
      topComments: topComments,
    );
  }

  String _summaryPrompt({
    required String game,
    required String title,
    required String description,
    required String partyAStatement,
    required String partyBStatement,
    required int leftPercent,
    required int rightPercent,
    required int totalVotes,
    required bool isClosed,
    required List<String> topComments,
  }) {
    final commentsBlock =
        topComments.isEmpty ? '없음' : topComments.take(3).join(' / ');
    return '''
You are a neutral Korean e-sports tribunal judge summarizing a match fault dispute.
Summarize concisely in natural Korean without markdown.
Return ONLY valid JSON with these exact keys:
{"issue":"핵심 쟁점 1문장","partyA":"신청인 주장 요지 1문장","partyB":"상대방 주장 요지 1문장","verdict":"배심원 여론 기반 최종 요약 1문장"}

Game: $game
Title: ${jsonEncode(title)}
Background: ${jsonEncode(description)}
Party A (신청인): ${jsonEncode(partyAStatement)}
Party B (상대방): ${jsonEncode(partyBStatement)}
Votes: total $totalVotes (Party A fault $leftPercent percent, Party B fault $rightPercent percent, closed=$isClosed)
Top jury comments: ${jsonEncode(commentsBlock)}
''';
  }

  VerdictAiSummary? _parseSummary(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final json =
          jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
      final issue = (json['issue'] as String?)?.trim() ?? '';
      final partyA = (json['partyA'] as String?)?.trim() ?? '';
      final partyB = (json['partyB'] as String?)?.trim() ?? '';
      final verdict = (json['verdict'] as String?)?.trim() ?? '';
      if (issue.isEmpty || verdict.isEmpty) return null;
      return VerdictAiSummary(
        issueLine: issue,
        partyALine: partyA.isEmpty ? '신청인 진술 요약을 확인해 주세요.' : partyA,
        partyBLine: partyB.isEmpty ? '상대방 진술 요약을 확인해 주세요.' : partyB,
        verdictLine: verdict,
        usedOnDeviceModel: true,
      );
    } catch (_) {
      return null;
    }
  }

  String _trimText(String text, {int max = 72}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return '';
    if (normalized.length <= max) return normalized;
    return '${normalized.substring(0, max)}…';
  }

  VerdictAiSummary _buildStructuredFallback({
    required String game,
    required String title,
    required String partyAStatement,
    required String partyBStatement,
    required int leftPercent,
    required int rightPercent,
    required int totalVotes,
    required bool isClosed,
    required List<String> topComments,
  }) {
    final aTrim = _trimText(partyAStatement);
    final bTrim = _trimText(partyBStatement);
    final topCommentTrim =
        topComments.isNotEmpty ? _trimText(topComments.first, max: 60) : '';

    final String verdictLine;
    if (totalVotes == 0) {
      verdictLine = '아직 투표 데이터가 충분하지 않아 배심원 판정 집계를 기다리고 있습니다.';
    } else if ((leftPercent - rightPercent).abs() < 20) {
      verdictLine =
          '총 $totalVotes명 참여 기준 $leftPercent:$rightPercent 접전 양상이며, 양측 판단 근거가 팽팽하게 대립 중입니다.';
    } else {
      final faultParty =
          leftPercent > rightPercent ? 'Party A(신청인)' : 'Party B(상대방)';
      final majorPct =
          leftPercent > rightPercent ? leftPercent : rightPercent;
      final suffix = topCommentTrim.isNotEmpty
          ? ' 핵심 여론: "$topCommentTrim"'
          : '';
      verdictLine =
          '${isClosed ? '최종' : '현재'} 배심원 $majorPct%가 $faultParty 측의 주된 과실로 판단했습니다.$suffix';
    }

    return VerdictAiSummary(
      issueLine: '[$game] ${_trimText(title, max: 64)} 상황의 과실 귀책 여부',
      partyALine: aTrim.isEmpty ? '신청인 측 상세 진술이 등록되지 않았습니다.' : aTrim,
      partyBLine: bTrim.isEmpty ? '상대방 측 상세 진술이 등록되지 않았습니다.' : bTrim,
      verdictLine: verdictLine,
      usedOnDeviceModel: false,
    );
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
    if (start < 0 || end <= start) {
      return const ModerationResult(
        action: ModerationAction.review,
        message: 'AI 판정 결과를 확인할 수 없어 운영 검토가 필요합니다.',
      );
    }
    final json =
        jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
    final action = switch (json['action']) {
      'allow' => ModerationAction.allow,
      'warn' => ModerationAction.warn,
      'block' => ModerationAction.block,
      _ => ModerationAction.review,
    };
    final reason = (json['reason'] as String?)?.trim();
    return ModerationResult(
      action: action,
      message: reason?.isNotEmpty == true
          ? reason!
          : 'AI가 운영 검토가 필요하다고 판단했습니다.',
      matchedRule: 'gemma_context_classifier',
    );
  }
}