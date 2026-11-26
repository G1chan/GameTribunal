import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/case_detail_page.dart';
import '../services/auth_service.dart';
import '../services/case_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    this.title = '겜문철',
    this.back = false,
    this.actions,
  });

  final String title;
  final bool back;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: back
          ? IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
            )
          : null,
      title: Row(
        children: [
          Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(
              color: AppColors.red,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.gavel_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
      actions: actions ?? const [_NotificationBellButton()],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton();

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  void _openNotificationSheet(
    BuildContext context, {
    required String uid,
    required UserProfile? profile,
    required List<CaseRecord> items,
    required DateTime? previousReadAt,
  }) {
    unawaited(UserService.instance.markNotificationsRead(uid));

    final favGames = profile?.favoriteGames ?? const <String>[];
    final notificationsEnabled = profile?.notificationsEnabled ?? true;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.68,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_outlined,
                        color: AppColors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '새 사건 · 영상 알림',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  child: Text(
                    !notificationsEnabled
                        ? '프로필에서 판정 알림이 꺼져 있어 배지가 표시되지 않습니다.'
                        : favGames.isEmpty
                            ? '전체 종목의 새로 등록된 사건 알림입니다.'
                            : '내 관심 종목(${favGames.join(', ')})에 새로 올라온 사건입니다.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: items.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.notifications_off_outlined,
                                  size: 38,
                                  color: AppColors.muted,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  '새로 도착한 사건 알림이 없습니다.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final c = items[index];
                            final isUnread = previousReadAt == null ||
                                c.createdAt.isAfter(previousReadAt);

                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CaseDetailPage(caseId: c.id),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isUnread
                                      ? AppColors.redPale.withValues(alpha: 0.55)
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isUnread
                                        ? AppColors.red.withValues(alpha: 0.4)
                                        : AppColors.line,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _NotificationThumb(item: c),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                c.game,
                                                style: const TextStyle(
                                                  color: AppColors.red,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              if (c.hasVideo)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 1,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.field,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      4,
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    '영상',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              const Spacer(),
                                              Text(
                                                _timeAgo(c.createdAt),
                                                style: const TextStyle(
                                                  color: AppColors.muted,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            c.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              height: 1.3,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            c.hasVideo
                                                ? '${c.authorNickname}님이 새 증거 영상을 등록했어요'
                                                : '${c.authorNickname}님이 새 사건을 제보했어요',
                                            style: const TextStyle(
                                              color: AppColors.muted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      return IconButton(
        onPressed: () {},
        icon: const Icon(Icons.notifications_none_rounded),
      );
    }

    return StreamBuilder<UserProfile?>(
      stream: UserService.instance.watchUser(uid),
      builder: (context, userSnap) {
        final profile = userSnap.data;
        final favGames = profile?.favoriteGames ?? const <String>[];
        final enabled = profile?.notificationsEnabled ?? true;
        final lastReadAt = profile?.lastNotificationReadAt;

        return StreamBuilder<List<CaseRecord>>(
          stream: CaseService.instance.watchCases(),
          builder: (context, caseSnap) {
            final allCases = caseSnap.data ?? const <CaseRecord>[];
            final matching = allCases
                .where((c) => favGames.isEmpty || favGames.contains(c.game))
                .take(15)
                .toList();

            final unreadCount = !enabled
                ? 0
                : matching
                    .where(
                      (c) =>
                          lastReadAt == null || c.createdAt.isAfter(lastReadAt),
                    )
                    .length;

            return IconButton(
              tooltip: '알림',
              onPressed: () => _openNotificationSheet(
                context,
                uid: uid,
                profile: profile,
                items: matching,
                previousReadAt: lastReadAt,
              ),
              icon: Badge(
                isLabelVisible: unreadCount > 0,
                backgroundColor: AppColors.red,
                label: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                child: Icon(
                  unreadCount > 0
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _NotificationThumb extends StatelessWidget {
  const _NotificationThumb({required this.item});
  final CaseRecord item;

  @override
  Widget build(BuildContext context) {
    final thumb = item.thumbnailUrl;
    if (item.hasVideo && thumb != null && thumb.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 72,
          height: 54,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                thumb,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: AppColors.field),
              ),
              Container(color: Colors.black26),
              const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: 72,
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.redPale,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.gavel_rounded, color: AppColors.red, size: 24),
    );
  }
}