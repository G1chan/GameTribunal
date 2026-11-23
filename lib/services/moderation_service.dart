import '../models/moderation_result.dart';
import 'ai_moderation_engine.dart';

/// 사용자 입력을 저장하거나 전송하기 전 호출하는 단일 진입점입니다.
/// 1단계는 빠른 로컬 정책 필터이며, 이후 Gemma 어댑터가 문맥 판단을 보강합니다.
class ModerationService {
  ModerationService._();
  static final instance = ModerationService._();

  final _blockedWords = <String>{
    '죽어', '죽인다', '자살해', '꺼져', '병신', '시발', '씨발', '좆', '개새',
    '지랄', 'fuck', 'fuk', 'fck',
    '니애미', '느금마', '애미창년', '창년',
  };
  final _warningWords = <String>{'멍청', '바보', '못하네', '트롤', '노답'};
  final _phonePattern = RegExp(r'(?<!\d)(01[016789])[-. ]?\d{3,4}[-. ]?\d{4}(?!\d)');
  final _emailPattern = RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.-]+\b');
  final _linkPattern = RegExp(r'(https?://|www\.)', caseSensitive: false);

  Future<ModerationResult> check(String input, {required ModerationContext context}) async {
    final text = input.trim();
    if (text.isEmpty) return const ModerationResult(action: ModerationAction.allow, message: '');
    if (_phonePattern.hasMatch(text) || _emailPattern.hasMatch(text)) return const ModerationResult(action: ModerationAction.block, message: '전화번호나 이메일 등 개인정보는 게시할 수 없습니다.', matchedRule: 'personal_information');
    if (_linkPattern.hasMatch(text)) return const ModerationResult(action: ModerationAction.review, message: '외부 링크가 포함된 글은 운영 검토가 필요합니다.', matchedRule: 'external_link');
    // 공백·기호를 끼워 넣어 우회하는 "f*ck", "ㅈ 랄"도 기본적으로 차단합니다.
    final aiResult = await AiModerationEngine.instance.classify(text, context);
    if (aiResult != null) return aiResult;
    final compact = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');
    for (final word in _blockedWords) { if (compact.contains(word)) return const ModerationResult(action: ModerationAction.block, message: '공격적이거나 위협적인 표현은 사용할 수 없습니다. 표현을 수정해 주세요.', matchedRule: 'blocked_language'); }
    for (final word in _warningWords) { if (compact.contains(word)) return const ModerationResult(action: ModerationAction.warn, message: '상대를 비난하는 표현이 포함되어 있습니다. 근거 중심의 표현을 권장합니다.', matchedRule: 'discouraged_language'); }
    return const ModerationResult(action: ModerationAction.allow, message: '');
  }
}
enum ModerationContext { comment, caseTitle, caseDescription, partyStatement, nickname }
/// 온디바이스 Gemma/LiteRT-LM 모델을 위한 교체 지점입니다.
abstract interface class FlutterEdgeAiModerator { Future<ModerationResult?> classify(String text, ModerationContext context); }
