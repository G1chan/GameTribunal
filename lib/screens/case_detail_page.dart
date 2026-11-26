import 'dart:async';
import 'package:flutter/material.dart';
import '../models/case_model.dart';
import '../services/auth_service.dart';
import '../services/case_service.dart';
import '../services/moderation_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/case_video_player.dart';
import '../widgets/moderation_notice.dart';
import '../widgets/user_avatar.dart';
import '../widgets/verdict_bar.dart';
import 'discussion_page.dart';
import 'shop_page.dart';
import 'verdict_report_page.dart';

class CaseDetailPage extends StatefulWidget {
  const CaseDetailPage({super.key, this.item, this.caseId})
      : assert(item != null || caseId != null);

  final GameCase? item;
  final String? caseId;

  @override
  State<CaseDetailPage> createState() => _CaseDetailPageState();
}

class _CaseDetailPageState extends State<CaseDetailPage> {
  static final _timestampRegex = RegExp(r'\b(\d{1,2}):([0-5]\d)\b');

  final _scrollController = ScrollController();
  final _videoController = CaseVideoPlayerController();
  final _quickCommentController = TextEditingController();

  String? _selectedChoice; // 'left' | 'right'
  String _quickCommentSide = 'left';
  bool _isSubmitting = false;
  bool _isManaging = false;
  bool _isSendingComment = false;

  String get _resolvedCaseId => widget.caseId ?? widget.item!.id;

  @override
  void initState() {
    super.initState();
    unawaited(CaseService.instance.closeIfExpired(_resolvedCaseId));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _quickCommentController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$m/$d $h:$min';
  }

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds < 0 ? 0 : d.inSeconds;
    final mins = totalSeconds ~/ 60;
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  List<({String label, Duration duration})> _extractTimestamps(String text) {
    final seen = <String>{};
    final result = <({String label, Duration duration})>[];
    for (final m in _timestampRegex.allMatches(text)) {
      final label = m.group(0)!;
      if (!seen.add(label)) continue;
      final mins = int.tryParse(m.group(1) ?? '0') ?? 0;
      final secs = int.tryParse(m.group(2) ?? '0') ?? 0;
      result.add((
        label: label,
        duration: Duration(minutes: mins, seconds: secs),
      ));
    }
    return result;
  }

  void _insertCurrentTimestamp() {
    final pos = _videoController.currentPosition;
    final tag = _formatDuration(pos);
    final current = _quickCommentController.text;
    final prefix = current.isEmpty || current.endsWith(' ') ? '' : ' ';
    final nextText = '$current$prefix$tag ';
    _quickCommentController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  Future<void> _jumpToTimestamp(Duration target) async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
    await _videoController.seekTo(target, autoPlay: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        content: Text('${_formatDuration(target)} 지점으로 이동했습니다.'),
      ),
    );
  }

  Future<void> _submitQuickComment(CaseRecord record) async {
    if (_isSendingComment) return;
    final text = _quickCommentController.text.trim();
    if (text.isEmpty) return;

    final firebaseUser = AuthService.instance.currentUser;
    if (firebaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    setState(() => _isSendingComment = true);
    try {
      final modResult = await ModerationService.instance.check(
        text,
        context: ModerationContext.partyStatement,
      );
      if (!mounted) return;
      final passed = await handleModeration(context, modResult);
      if (!mounted || !passed) return;

      final profile = await UserService.instance.ensureUserDocument(firebaseUser);
      await CaseService.instance.addComment(
        caseId: record.id,
        authorUid: firebaseUser.uid,
        authorNickname: profile.nickname,
        content: text,
        side: _quickCommentSide,
      );

      if (!mounted) return;
      _quickCommentController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '판독 의견이 등록되었습니다! (+${PolicyConfig.xpComment} XP, +${PolicyConfig.pointsComment} P)',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('의견 등록 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  Future<void> _submitVote(CaseRecord record) async {
    if (_isSubmitting || _selectedChoice == null) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await CaseService.instance.submitVote(
        caseId: record.id,
        uid: uid,
        choice: _selectedChoice!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '판정이 제출되었습니다! (+${PolicyConfig.xpVote} XP, +${PolicyConfig.pointsVote} P)',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('판정 제출 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleBoostCase(CaseRecord record) async {
    if (_isManaging) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;

    final profile = await UserService.instance.getUser(uid);
    if (!mounted) return;

    final tickets = profile?.boostTickets ?? 0;
    if (tickets < 1) {
      final goShop = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('긴급 재판 부스트권 없음'),
          content: const Text(
            '보유 중인 긴급 재판 부스트권이 없습니다. 포인트 상점에서 구매 후 사용할 수 있습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('닫기'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.red),
              child: const Text('상점 가기'),
            ),
          ],
        ),
      );
      if (goShop == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ShopPage(initialTab: 0)),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('긴급 재판 부스트 사용'),
        content: Text(
          '보유 중인 부스트권 $tickets장 중 1장을 사용해 이 사건을 24시간 동안 홈 최상단에 우선 노출할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
            ),
            child: const Text('부스트 적용'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isManaging = true);
    try {
      await CaseService.instance.boostCase(caseId: record.id, uid: uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('긴급 재판 부스트가 적용되었습니다! 홈 최상단에 우선 노출됩니다.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('부스트 적용 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isManaging = false);
    }
  }

  Future<void> _handleCloseNow(CaseRecord record) async {
    if (_isManaging) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('투표를 즉시 마감할까요?'),
        content: const Text(
          '지금까지의 배심원 투표로 60:40 유효 판결을 확정하고, 참여한 배심원의 적중률·보너스 정산을 진행합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('즉시 마감'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isManaging = true);
    try {
      final closed = await CaseService.instance.closeCaseNow(record.id);
      final uid = AuthService.instance.currentUser?.uid;
      if (uid != null) {
        await CaseService.instance.settleMyVotes(uid);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '마감 완료: ${closed?.statusLabel ?? '판정 종결'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('마감 처리 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isManaging = false);
    }
  }

  Future<void> _handleDeleteCase(CaseRecord record) async {
    if (_isManaging) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('이 사건을 삭제할까요?'),
        content: const Text(
          '삭제된 사건과 해당 사건의 투표·댓글 기록은 복구할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isManaging = true);
    try {
      await CaseService.instance.deleteCase(record.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사건이 삭제되었습니다.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사건 삭제 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isManaging = false);
    }
  }

  Future<void> _openDiscussion(CaseRecord record) async {
    final jumped = await Navigator.push<Duration>(
      context,
      MaterialPageRoute(
        builder: (_) => DiscussionPage(
          item: record.toLegacyGameCase(),
          hasVideo: record.hasVideo,
        ),
      ),
    );
    if (jumped != null && record.hasVideo && mounted) {
      await _jumpToTimestamp(jumped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;

    return Scaffold(
      appBar: const AppHeader(title: '사건 상세', back: true),
      body: StreamBuilder<CaseRecord?>(
        stream: CaseService.instance.watchCase(_resolvedCaseId),
        builder: (context, caseSnap) {
          if (caseSnap.connectionState == ConnectionState.waiting &&
              !caseSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final record = caseSnap.data;
          if (record == null) {
            return const Center(child: Text('존재하지 않거나 삭제된 사건입니다.'));
          }

          final isAuthor = uid != null && record.authorUid == uid;

          return StreamBuilder<String?>(
            stream: uid != null
                ? CaseService.instance.watchMyVote(record.id, uid)
                : const Stream<String?>.empty(),
            builder: (context, voteSnap) {
              final myChoice = voteSnap.data;
              final showResult = record.isClosed || myChoice != null;

              return ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      if (record.isBoosted) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFF97316),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.rocket_launch_rounded,
                                size: 12,
                                color: Color(0xFFEA580C),
                              ),
                              SizedBox(width: 3),
                              Text(
                                '긴급 판정',
                                style: TextStyle(
                                  color: Color(0xFFEA580C),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          '${record.game} · ${record.tier} · ${record.type}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.red,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: record.isClosed
                              ? AppColors.line
                              : AppColors.redPale,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          record.isClosed ? '투표 마감' : record.remainingTimeText,
                          style: TextStyle(
                            color: record.isClosed
                                ? AppColors.muted
                                : AppColors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    record.title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      height: 1.28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      LiveUserAvatar(uid: record.authorUid, radius: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 3,
                              children: [
                                Text(
                                  record.authorNickname,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                                LiveUserTitleBadge(
                                  uid: record.authorUid,
                                  compact: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_formatDate(record.createdAt)} · 배심원 ${record.totalVotes}명 참여',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isAuthor) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (!record.isClosed) ...[
                          OutlinedButton.icon(
                            onPressed: _isManaging
                                ? null
                                : () => _handleBoostCase(record),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: const Color(0xFFEA580C),
                              side: const BorderSide(
                                color: Color(0xFFF97316),
                              ),
                            ),
                            icon: const Icon(
                              Icons.rocket_launch_rounded,
                              size: 15,
                            ),
                            label: Text(
                              record.isBoosted ? '부스트 연장' : '긴급 부스트',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isManaging
                                ? null
                                : () => _handleCloseNow(record),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: AppColors.ink,
                            ),
                            icon: const Icon(Icons.gavel_rounded, size: 15),
                            label: const Text(
                              '투표 즉시 마감',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                        OutlinedButton.icon(
                          onPressed: _isManaging
                              ? null
                              : () => _handleDeleteCase(record),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppColors.red,
                            side: const BorderSide(color: AppColors.red),
                          ),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 15,
                          ),
                          label: const Text(
                            '사건 삭제',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 15),
                  if (record.hasVideo) ...[
                    CaseVideoPlayer(
                      videoUrl: record.videoUrl!,
                      controller: _videoController,
                    ),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '사건 배경 및 상황',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          record.description.isEmpty
                              ? '등록된 상세 설명이 없습니다.'
                              : record.description,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                        if (record.issues.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: record.issues
                                .map(
                                  (issue) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.redPale,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '#$issue',
                                      style: const TextStyle(
                                        color: AppColors.red,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '양측 당사자 진술',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 9),
                  _Statement(
                    name: 'Party A · 신청인 주장',
                    text: record.partyAStatement.isEmpty
                        ? '입력된 주장이 없습니다.'
                        : record.partyAStatement,
                    tint: AppColors.redPale,
                  ),
                  _Statement(
                    name: 'Party B · 상대방 주장',
                    text: record.partyBStatement.isEmpty
                        ? '입력된 주장이 없습니다.'
                        : record.partyBStatement,
                    tint: AppColors.bluePale,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '배심원 과실 판정',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  if (showResult) ...[
                    VerdictBar(
                      left: record.leftPercent,
                      right: record.rightPercent,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '신청인 과실 ${record.leftVotes}표 (${record.leftPercent}%)',
                          style: const TextStyle(
                            color: AppColors.red,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '상대방 과실 ${record.rightVotes}표 (${record.rightPercent}%)',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.isClosed
                                ? '최종 판결: ${record.statusLabel}'
                                : '내 판정 완료 · 마감 시 60:40 이상이면 적중률에 반영됩니다.',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          if (myChoice != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '내가 선택한 과실: ${myChoice == 'left' ? 'Party A (신청인) 과실' : 'Party B (상대방) 과실'}',
                              style: const TextStyle(
                                color: AppColors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.redPale,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.visibility_off_outlined,
                            color: AppColors.red,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '블라인드 투표 진행 중입니다. 과실 쪽을 선택해 제출하면 현재 비율이 공개됩니다.',
                              style: TextStyle(
                                color: AppColors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _VoteChoiceCard(
                            title: 'Party A 과실',
                            subtitle: '신청인 잘못이 더 큼',
                            selected: _selectedChoice == 'left',
                            onTap: _isSubmitting
                                ? null
                                : () =>
                                    setState(() => _selectedChoice = 'left'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _VoteChoiceCard(
                            title: 'Party B 과실',
                            subtitle: '상대방 잘못이 더 큼',
                            selected: _selectedChoice == 'right',
                            onTap: _isSubmitting
                                ? null
                                : () =>
                                    setState(() => _selectedChoice = 'right'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: (_selectedChoice == null || _isSubmitting)
                          ? null
                          : () => _submitVote(record),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.red,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: Text(
                        _isSubmitting
                            ? '판정 제출 중...'
                            : '판정 제출하기 (+${PolicyConfig.xpVote} XP · +${PolicyConfig.pointsVote} P)',
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openDiscussion(record),
                          icon: const Icon(Icons.forum_outlined),
                          label: Text('실시간 토론 (${record.commentCount})'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VerdictReportPage(
                                item: record.toLegacyGameCase(),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.assessment_outlined),
                          label: const Text('판정 리포트'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '타임스탬프 판독 의견',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _openDiscussion(record),
                        child: const Text('전체 보기'),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ChoiceChip(
                              label: const Text('신청인 과실'),
                              visualDensity: VisualDensity.compact,
                              selected: _quickCommentSide == 'left',
                              selectedColor: AppColors.redPale,
                              onSelected: (_) =>
                                  setState(() => _quickCommentSide = 'left'),
                            ),
                            ChoiceChip(
                              label: const Text('상대방 과실'),
                              visualDensity: VisualDensity.compact,
                              selected: _quickCommentSide == 'right',
                              selectedColor: AppColors.bluePale,
                              onSelected: (_) =>
                                  setState(() => _quickCommentSide = 'right'),
                            ),
                            if (record.hasVideo)
                              ActionChip(
                                avatar: const Icon(
                                  Icons.schedule_rounded,
                                  size: 15,
                                  color: AppColors.red,
                                ),
                                label: const Text(
                                  '+ 현재 시간',
                                  style: TextStyle(
                                    color: AppColors.red,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: AppColors.redPale,
                                side: BorderSide.none,
                                onPressed: _insertCurrentTimestamp,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _quickCommentController,
                                onSubmitted: (_) => _submitQuickComment(record),
                                decoration: InputDecoration(
                                  hintText: record.hasVideo
                                      ? '예: 0:14 진입 타이밍이 너무 일렀어요'
                                      : '판결 근거를 남겨주세요 (+15 XP)',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _isSendingComment
                                  ? null
                                  : () => _submitQuickComment(record),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.red,
                                minimumSize: const Size(60, 44),
                              ),
                              child: Text(_isSendingComment ? '...' : '등록'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<List<CaseComment>>(
                    stream: CaseService.instance.watchComments(record.id),
                    builder: (context, commentSnap) {
                      final allComments =
                          commentSnap.data ?? const <CaseComment>[];
                      final replyCounts = <String, int>{};
                      for (final c in allComments) {
                        if (c.isReply) {
                          replyCounts[c.parentId!] =
                              (replyCounts[c.parentId!] ?? 0) + 1;
                        }
                      }
                      final comments = allComments
                          .where((c) => !c.isReply)
                          .take(5)
                          .toList();

                      if (comments.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            '아직 판독 의견이 없습니다. 영상 시점을 찍어 첫 의견을 남겨보세요.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: comments.map((c) {
                          final timestamps = _extractTimestamps(c.content);
                          final isLeft = c.side == 'left';
                          final liked = c.isLikedBy(uid);
                          final disliked = c.isDislikedBy(uid);
                          final replyCount = replyCounts[c.id] ?? 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    LiveUserAvatar(
                                      uid: c.authorUid,
                                      radius: 15,
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 5,
                                        runSpacing: 3,
                                        children: [
                                          Text(
                                            c.authorNickname,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12,
                                            ),
                                          ),
                                          LiveUserTitleBadge(
                                            uid: c.authorUid,
                                            compact: true,
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isLeft
                                                  ? AppColors.redPale
                                                  : AppColors.bluePale,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              c.sideLabel,
                                              style: TextStyle(
                                                color: isLeft
                                                    ? AppColors.red
                                                    : AppColors.ink,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  c.content,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                if (record.hasVideo &&
                                    timestamps.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: timestamps
                                        .map(
                                          (t) => ActionChip(
                                            avatar: const Icon(
                                              Icons.play_arrow_rounded,
                                              size: 15,
                                              color: AppColors.red,
                                            ),
                                            label: Text(
                                              '${t.label} 보기',
                                              style: const TextStyle(
                                                color: AppColors.red,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                            backgroundColor: AppColors.redPale,
                                            side: BorderSide.none,
                                            onPressed: () =>
                                                _jumpToTimestamp(t.duration),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: uid == null
                                          ? null
                                          : () => CaseService.instance
                                              .toggleCommentLike(
                                                caseId: record.id,
                                                commentId: c.id,
                                                uid: uid,
                                                currentlyLiked: liked,
                                              ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              liked
                                                  ? Icons.thumb_up_alt_rounded
                                                  : Icons.thumb_up_alt_outlined,
                                              size: 14,
                                              color: liked
                                                  ? AppColors.red
                                                  : AppColors.muted,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${c.likeCount}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: liked
                                                    ? AppColors.red
                                                    : AppColors.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: uid == null
                                          ? null
                                          : () => CaseService.instance
                                              .toggleCommentDislike(
                                                caseId: record.id,
                                                commentId: c.id,
                                                uid: uid,
                                                currentlyDisliked: disliked,
                                              ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              disliked
                                                  ? Icons.thumb_down_alt_rounded
                                                  : Icons
                                                      .thumb_down_alt_outlined,
                                              size: 14,
                                              color: disliked
                                                  ? const Color(0xFF2563EB)
                                                  : AppColors.muted,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${c.dislikeCount}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: disliked
                                                    ? const Color(0xFF2563EB)
                                                    : AppColors.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _openDiscussion(record),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons
                                                  .subdirectory_arrow_right_rounded,
                                              size: 14,
                                              color: AppColors.muted,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              replyCount > 0
                                                  ? '답글 $replyCount'
                                                  : '답글',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _VoteChoiceCard extends StatelessWidget {
  const _VoteChoiceCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.redPale : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.red : AppColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: selected ? AppColors.red : null,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.red,
                    size: 18,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Statement extends StatelessWidget {
  const _Statement({
    required this.name,
    required this.text,
    required this.tint,
  });

  final String name, text;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
        ),
      );
}