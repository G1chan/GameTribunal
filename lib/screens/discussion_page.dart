import 'package:flutter/material.dart';
import '../models/case_model.dart';
import '../services/auth_service.dart';
import '../services/case_service.dart';
import '../services/moderation_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/moderation_notice.dart';
import '../widgets/user_avatar.dart';

class DiscussionPage extends StatefulWidget {
  const DiscussionPage({
    super.key,
    required this.item,
    this.hasVideo = false,
  });

  final GameCase item;
  final bool hasVideo;

  @override
  State<DiscussionPage> createState() => _DiscussionPageState();
}

class _DiscussionPageState extends State<DiscussionPage> {
  static final _timestampRegex = RegExp(r'\b(\d{1,2}):([0-5]\d)\b');

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  String _selectedSide = 'left'; // 'left' | 'right'
  CaseComment? _replyTarget;
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
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

  void _startReply(CaseComment parent) {
    setState(() => _replyTarget = parent);
    _focusNode.requestFocus();
  }

  Future<void> _sendComment() async {
    if (_isSending) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final firebaseUser = AuthService.instance.currentUser;
    if (firebaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      final modResult = await ModerationService.instance.check(
        text,
        context: ModerationContext.partyStatement,
      );
      if (!mounted) return;
      final passed = await handleModeration(context, modResult);
      if (!mounted || !passed) return;

      final profile = await UserService.instance.ensureUserDocument(firebaseUser);
      final targetParentId = _replyTarget?.id;

      await CaseService.instance.addComment(
        caseId: widget.item.id,
        authorUid: firebaseUser.uid,
        authorNickname: profile.nickname,
        content: text,
        side: _selectedSide,
        parentId: targetParentId,
      );

      if (!mounted) return;
      _controller.clear();
      setState(() => _replyTarget = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            targetParentId != null
                ? '답글이 등록되었습니다! (+${PolicyConfig.xpComment} XP, +${PolicyConfig.pointsComment} P)'
                : '판결 근거가 등록되었습니다! (+${PolicyConfig.xpComment} XP, +${PolicyConfig.pointsComment} P)',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 등록 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteComment(CaseComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(comment.isReply ? '답글을 삭제할까요?' : '댓글을 삭제할까요?'),
        content: Text(
          comment.isReply
              ? '삭제한 답글은 복구할 수 없습니다.'
              : '댓글을 삭제하면 달린 답글도 함께 삭제되며 복구할 수 없습니다.',
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

    try {
      await CaseService.instance.deleteComment(
        caseId: widget.item.id,
        commentId: comment.id,
      );
      if (!mounted) return;
      if (_replyTarget?.id == comment.id) {
        setState(() => _replyTarget = null);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(comment.isReply ? '답글이 삭제되었습니다.' : '댓글이 삭제되었습니다.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }

  Widget _buildReactionBar({
    required CaseComment comment,
    required String? uid,
    required bool isMine,
    int? replyCount,
    VoidCallback? onReplyTap,
  }) {
    final liked = comment.isLikedBy(uid);
    final disliked = comment.isDislikedBy(uid);

    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: uid == null
              ? null
              : () => CaseService.instance.toggleCommentLike(
                    caseId: widget.item.id,
                    commentId: comment.id,
                    uid: uid,
                    currentlyLiked: liked,
                  ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  liked
                      ? Icons.thumb_up_alt_rounded
                      : Icons.thumb_up_alt_outlined,
                  size: 15,
                  color: liked ? AppColors.red : AppColors.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  '공감 ${comment.likeCount}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: liked ? AppColors.red : AppColors.muted,
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
              : () => CaseService.instance.toggleCommentDislike(
                    caseId: widget.item.id,
                    commentId: comment.id,
                    uid: uid,
                    currentlyDisliked: disliked,
                  ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  disliked
                      ? Icons.thumb_down_alt_rounded
                      : Icons.thumb_down_alt_outlined,
                  size: 15,
                  color: disliked ? const Color(0xFF2563EB) : AppColors.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  '비공감 ${comment.dislikeCount}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        disliked ? const Color(0xFF2563EB) : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (onReplyTap != null) ...[
          const SizedBox(width: 12),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onReplyTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.subdirectory_arrow_right_rounded,
                    size: 15,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    (replyCount ?? 0) > 0 ? '답글 $replyCount' : '답글',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const Spacer(),
        if (isMine)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _deleteComment(comment),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    size: 15,
                    color: AppColors.muted,
                  ),
                  SizedBox(width: 3),
                  Text(
                    '삭제',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReplyCard(CaseComment reply, String? uid) {
    final isLeft = reply.side == 'left';
    final isMine = uid != null && reply.authorUid == uid;
    final timestamps = _extractTimestamps(reply.content);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LiveUserAvatar(
                uid: reply.authorUid,
                radius: 13,
                showEmblems: false,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 5,
                  runSpacing: 2,
                  children: [
                    Text(
                      reply.authorNickname,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    LiveUserTitleBadge(uid: reply.authorUid, compact: true),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: isLeft ? AppColors.redPale : AppColors.bluePale,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        reply.sideLabel,
                        style: TextStyle(
                          color: isLeft ? AppColors.red : AppColors.ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _timeAgo(reply.createdAt),
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            reply.content,
            style: const TextStyle(fontSize: 13, height: 1.45),
          ),
          if (widget.hasVideo && timestamps.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: timestamps
                  .map(
                    (t) => ActionChip(
                      avatar: const Icon(
                        Icons.play_arrow_rounded,
                        size: 14,
                        color: AppColors.red,
                      ),
                      label: Text(
                        '${t.label} 영상 보기',
                        style: const TextStyle(
                          color: AppColors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppColors.redPale,
                      side: BorderSide.none,
                      onPressed: () => Navigator.pop(context, t.duration),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 6),
          _buildReactionBar(
            comment: reply,
            uid: uid,
            isMine: isMine,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;

    return Scaffold(
      appBar: const AppHeader(title: '실시간 토론', back: true),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.game,
                  style: const TextStyle(
                    color: AppColors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<CaseComment>>(
              stream: CaseService.instance.watchComments(widget.item.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allComments = snapshot.data ?? const <CaseComment>[];
                final rootComments =
                    allComments.where((c) => !c.isReply).toList();
                final repliesByParent = <String, List<CaseComment>>{};
                for (final c in allComments) {
                  if (c.isReply) {
                    repliesByParent.putIfAbsent(c.parentId!, () => []).add(c);
                  }
                }
                for (final list in repliesByParent.values) {
                  list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                }

                if (rootComments.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            size: 40,
                            color: AppColors.muted,
                          ),
                          SizedBox(height: 10),
                          Text(
                            '아직 작성된 판결 근거가 없습니다.',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '첫 의견을 남기고 +15 XP · +5 P를 받아보세요.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rootComments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final c = rootComments[index];
                    final replies =
                        repliesByParent[c.id] ?? const <CaseComment>[];
                    final isLeft = c.side == 'left';
                    final isMine = uid != null && c.authorUid == uid;
                    final timestamps = _extractTimestamps(c.content);

                    return Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _replyTarget?.id == c.id
                              ? AppColors.red
                              : AppColors.line,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              LiveUserAvatar(uid: c.authorUid, radius: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 3,
                                  children: [
                                    Text(
                                      c.authorNickname,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                    LiveUserTitleBadge(
                                      uid: c.authorUid,
                                      compact: true,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isLeft
                                            ? AppColors.redPale
                                            : AppColors.bluePale,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        c.sideLabel,
                                        style: TextStyle(
                                          color: isLeft
                                              ? AppColors.red
                                              : AppColors.ink,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _timeAgo(c.createdAt),
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            c.content,
                            style: const TextStyle(fontSize: 14, height: 1.45),
                          ),
                          if (widget.hasVideo && timestamps.isNotEmpty) ...[
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
                                        '${t.label} 영상 보기',
                                        style: const TextStyle(
                                          color: AppColors.red,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: AppColors.redPale,
                                      side: BorderSide.none,
                                      onPressed: () =>
                                          Navigator.pop(context, t.duration),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          const SizedBox(height: 8),
                          _buildReactionBar(
                            comment: c,
                            uid: uid,
                            isMine: isMine,
                            replyCount: replies.length,
                            onReplyTap: () => _startReply(c),
                          ),
                          if (replies.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8, left: 10),
                              padding: const EdgeInsets.only(left: 10),
                              decoration: const BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: AppColors.line,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Column(
                                children: replies
                                    .map((r) => _buildReplyCard(r, uid))
                                    .toList(),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_replyTarget != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.redPale,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.subdirectory_arrow_right_rounded,
                            size: 16,
                            color: AppColors.red,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${_replyTarget!.authorNickname}님에게 답글 작성 중',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => _replyTarget = null),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 17,
                              color: AppColors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('신청인 과실'),
                        selected: _selectedSide == 'left',
                        selectedColor: AppColors.redPale,
                        onSelected: (_) =>
                            setState(() => _selectedSide = 'left'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('상대방 과실'),
                        selected: _selectedSide == 'right',
                        selectedColor: AppColors.bluePale,
                        onSelected: (_) =>
                            setState(() => _selectedSide = 'right'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          onSubmitted: (_) => _sendComment(),
                          decoration: InputDecoration(
                            hintText: _replyTarget != null
                                ? '${_replyTarget!.authorNickname}님에게 답글 입력...'
                                : (widget.hasVideo
                                    ? '예: 0:14 진입이 너무 빨랐어요 (+15 XP)'
                                    : '판결 근거를 작성해 주세요 (+15 XP)'),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _isSending ? null : _sendComment,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.red,
                          minimumSize: const Size(64, 46),
                        ),
                        child: Text(_isSending ? '...' : '등록'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}