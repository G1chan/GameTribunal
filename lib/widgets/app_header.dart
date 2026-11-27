import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/case_detail_page.dart';
import '../services/auth_service.dart';
import '../services/case_service.dart';
import '../services/notification_service.dart';
import '../services/push_notification_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

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

class _NotificationBellButton extends StatefulWidget {
  const _NotificationBellButton();

  @override
  State<_NotificationBellButton> createState() =>
      _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<_NotificationBellButton> {
  @override
  void initState() {
    super.initState();
    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      unawaited(PushNotificationService.instance.syncIfAlreadyAuthorized(uid));
      PushNotificationService.instance.bindForegroundHandler((title, body) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title${body.isNotEmpty ? ' · $body' : ''}')),
        );
      });
    }
  }

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
    required List<AppNotification> personalItems,
    required List<CaseRecord> caseItems,
    required DateTime? previousReadAt,
  }) {
    unawaited(UserService.instance.markNotificationsRead(uid));
    unawaited(NotificationService.instance.markAllRead(uid));

    final favGames = profile?.favoriteGames ?? const <String>[];
    final notificationsEnabled = profile?.notificationsEnabled ?? true;
    final hasUnreadPersonal = personalItems.any((n) => !n.read);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.72,
            child: DefaultTabController(
              length: 2,
              initialIndex: hasUnreadPersonal || personalItems.isNotEmpty ? 0 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 12, 6),
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
                            '알림 센터',
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
                  ValueListenableBuilder<bool>(
                    valueListenable:
                        PushNotificationService.instance.isPushAuthorized,
                    builder: (ctx, authorized, _) {
                      if (authorized) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: ctx.redPaleColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.campaign_outlined,
                              size: 18,
                              color: AppColors.red,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '대댓글·판정 종결을 브라우저 푸시로 바로 받아보세요.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final res = await PushNotificationService
                                    .instance
                                    .requestAndRegister(uid);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(res.message)),
                                );
                              },
                              child: const Text(
                                '켜기',
                                style: TextStyle(
                                  color: AppColors.red,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  TabBar(
                    labelColor: AppColors.red,
                    unselectedLabelColor: sheetContext.mutedColor,
                    indicatorColor: AppColors.red,
                    tabs: [
                      Tab(text: '내 활동 (${personalItems.length})'),
                      Tab(text: '관심 종목 (${caseItems.length})'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // 탭 1: 내 활동 알림 (대댓글, 내 사건 새 댓글, 종결)
                        personalItems.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.mark_chat_unread_outlined,
                                        size: 38,
                                        color: sheetContext.mutedColor,
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        '아직 도착한 활동 알림이 없습니다.',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '내 댓글에 답글이 달리거나 참여한 사건이 종결되면 여기에 표시됩니다.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: sheetContext.mutedColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(14),
                                itemCount: personalItems.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, index) {
                                  final n = personalItems[index];
                                  final iconData = switch (n.type) {
                                    'reply' =>
                                      Icons.subdirectory_arrow_right_rounded,
                                    'comment' => Icons.forum_outlined,
                                    'closed' => Icons.gavel_rounded,
                                    _ => Icons.notifications_outlined,
                                  };

                                  return InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: n.caseId.isEmpty
                                        ? null
                                        : () {
                                            Navigator.pop(sheetContext);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => CaseDetailPage(
                                                  caseId: n.caseId,
                                                ),
                                              ),
                                            );
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: !n.read
                                            ? sheetContext.redPaleColor
                                                .withValues(alpha: 0.65)
                                            : sheetContext.bgColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: !n.read
                                              ? AppColors.red
                                                  .withValues(alpha: 0.45)
                                              : sheetContext.lineColor,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: sheetContext.redPaleColor,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              iconData,
                                              color: AppColors.red,
                                              size: 19,
                                            ),
                                          ),
                                          const SizedBox(width: 11),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 6,
                                                        vertical: 1.5,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: sheetContext
                                                            .redPaleColor,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                      child: Text(
                                                        n.badgeLabel,
                                                        style: const TextStyle(
                                                          color: AppColors.red,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                      ),
                                                    ),
                                                    const Spacer(),
                                                    Text(
                                                      _timeAgo(n.createdAt),
                                                      style: TextStyle(
                                                        color: sheetContext
                                                            .mutedColor,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  n.title,
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                if (n.body.isNotEmpty) ...[
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    n.body,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: sheetContext
                                                          .mutedColor,
                                                      fontSize: 12,
                                                      height: 1.35,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                        // 탭 2: 관심 종목 새 사건 알림
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 10, 16, 6),
                              child: Text(
                                !notificationsEnabled
                                    ? '프로필에서 판정 알림이 꺼져 있어 배지가 표시되지 않습니다.'
                                    : favGames.isEmpty
                                        ? '전체 종목의 새로 등록된 사건 알림입니다.'
                                        : '내 관심 종목(${favGames.join(', ')})에 새로 올라온 사건입니다.',
                                style: TextStyle(
                                  color: sheetContext.mutedColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              child: caseItems.isEmpty
                                  ? Center(
                                      child: Text(
                                        '새로 도착한 사건 알림이 없습니다.',
                                        style: TextStyle(
                                          color: sheetContext.mutedColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.all(14),
                                      itemCount: caseItems.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 10),
                                      itemBuilder: (_, index) {
                                        final c = caseItems[index];
                                        final isUnread = previousReadAt ==
                                                null ||
                                            c.createdAt.isAfter(previousReadAt);

                                        return InkWell(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          onTap: () {
                                            Navigator.pop(sheetContext);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => CaseDetailPage(
                                                  caseId: c.id,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: isUnread
                                                  ? sheetContext.redPaleColor
                                                      .withValues(alpha: 0.55)
                                                  : sheetContext.bgColor,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isUnread
                                                    ? AppColors.red
                                                        .withValues(alpha: 0.4)
                                                    : sheetContext.lineColor,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                _NotificationThumb(item: c),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Text(
                                                            c.game,
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  AppColors.red,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          if (c.hasVideo)
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 5,
                                                                vertical: 1,
                                                              ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: AppColors
                                                                    .field,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                  4,
                                                                ),
                                                              ),
                                                              child: const Text(
                                                                '영상',
                                                                style:
                                                                    TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                ),
                                                              ),
                                                            ),
                                                          const Spacer(),
                                                          Text(
                                                            _timeAgo(
                                                              c.createdAt,
                                                            ),
                                                            style: TextStyle(
                                                              color:
                                                                  sheetContext
                                                                      .mutedColor,
                                                              fontSize: 11,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 5),
                                                      Text(
                                                        c.title,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          height: 1.3,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        c.hasVideo
                                                            ? '${c.authorNickname}님이 새 증거 영상을 등록했어요'
                                                            : '${c.authorNickname}님이 새 사건을 제보했어요',
                                                        style: TextStyle(
                                                          color: sheetContext
                                                              .mutedColor,
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
                      ],
                    ),
                  ),
                ],
              ),
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

        return StreamBuilder<List<AppNotification>>(
          stream: NotificationService.instance.watchMyNotifications(uid),
          builder: (context, personalSnap) {
            final personalItems =
                personalSnap.data ?? const <AppNotification>[];

            return StreamBuilder<List<CaseRecord>>(
              stream: CaseService.instance.watchCases(limit: 30),
              builder: (context, caseSnap) {
                final allCases = caseSnap.data ?? const <CaseRecord>[];
                final matching = allCases
                    .where((c) => favGames.isEmpty || favGames.contains(c.game))
                    .take(15)
                    .toList();

                final unreadPersonal =
                    personalItems.where((n) => !n.read).length;
                final unreadCases = !enabled
                    ? 0
                    : matching
                        .where(
                          (c) =>
                              lastReadAt == null ||
                              c.createdAt.isAfter(lastReadAt),
                        )
                        .length;
                final totalUnread = unreadPersonal + unreadCases;

                return IconButton(
                  tooltip: '알림',
                  onPressed: () => _openNotificationSheet(
                    context,
                    uid: uid,
                    profile: profile,
                    personalItems: personalItems,
                    caseItems: matching,
                    previousReadAt: lastReadAt,
                  ),
                  icon: Badge(
                    isLabelVisible: totalUnread > 0,
                    backgroundColor: AppColors.red,
                    label: Text(
                      totalUnread > 99 ? '99+' : '$totalUnread',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    child: Icon(
                      totalUnread > 0
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                    ),
                  ),
                );
              },
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
        color: context.redPaleColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.gavel_rounded, color: AppColors.red, size: 24),
    );
  }
}