import 'package:flutter_test/flutter_test.dart';
import 'package:game_tribunal/models/moderation_result.dart';
import 'package:game_tribunal/services/moderation_service.dart';

void main() {
  final service = ModerationService.instance;

  test('blocks personal information', () async {
    final result = await service.check('연락처는 010-1234-5678 입니다', context: ModerationContext.comment);
    expect(result.action, ModerationAction.block);
  });

  test('warns on hostile language', () async {
    final result = await service.check('정말 못하네', context: ModerationContext.comment);
    expect(result.action, ModerationAction.warn);
  });

  test('blocks Korean and English profanity including punctuation bypasses', () async {
    for (final text in ['지랄', 'fuck', 'f*ck', '니 애미', '느금마', '애미창년', '창년']) {
      final result = await service.check(text, context: ModerationContext.comment);
      expect(result.action, ModerationAction.block, reason: text);
    }
  });

  test('allows ordinary case discussion', () async {
    final result = await service.check('시야 확보 후 진입하는 판단이 더 적절해 보입니다.', context: ModerationContext.comment);
    expect(result.action, ModerationAction.allow);
  });
}
