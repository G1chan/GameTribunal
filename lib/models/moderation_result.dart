enum ModerationAction { allow, warn, block, review }

class ModerationResult {
  const ModerationResult({required this.action, required this.message, this.matchedRule});
  final ModerationAction action;
  final String message;
  final String? matchedRule;
  bool get canSubmit => action == ModerationAction.allow || action == ModerationAction.warn;
}
