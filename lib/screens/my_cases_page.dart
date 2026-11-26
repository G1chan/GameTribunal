import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/case_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'case_detail_page.dart';

class MyCasesPage extends StatelessWidget {
  const MyCasesPage({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('내 사건 및 활동 내역')),
        body: const Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return DefaultTabController(
      length: 3,
      initialIndex: initialTab.clamp(0, 2),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            '내 사건 및 활동 내역',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          bottom: const TabBar(
            labelColor: AppColors.red,
            indicatorColor: AppColors.red,
            tabs: [
              Tab(text: '제보한 사건'),
              Tab(text: '판정한 사건'),
              Tab(text: '북마크'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SubmittedCasesTab(uid: uid),
            _VotedCasesTab(uid: uid),
            _BookmarkedCasesTab(uid: uid),
          ],
        ),
      ),
    );
  }
}

class _SubmittedCasesTab extends StatelessWidget {
  const _SubmittedCasesTab({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CaseRecord>>(
      stream: CaseService.instance.watchMySubmittedCases(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? const <CaseRecord>[];
        if (items.isEmpty) {
          return Center(
            child: Text(
              '아직 제보한 사건이 없습니다.',
              style: TextStyle(color: context.mutedColor),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CaseDetailPage(caseId: item.id),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.lineColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${item.game} · ${item.tier}',
                          style: const TextStyle(
                            color: AppColors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          item.isClosed ? '종결' : item.remainingTimeText,
                          style: TextStyle(
                            color: context.mutedColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.statusLabel} · 참여 ${item.totalVotes}명 · 댓글 ${item.commentCount}',
                      style: TextStyle(
                        color: context.mutedColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _VotedCasesTab extends StatelessWidget {
  const _VotedCasesTab({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MyVoteRecord>>(
      stream: CaseService.instance.watchMyVotedCases(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final votes = snapshot.data ?? const <MyVoteRecord>[];
        if (votes.isEmpty) {
          return Center(
            child: Text(
              '아직 판정에 참여한 사건이 없습니다.',
              style: TextStyle(color: context.mutedColor),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: votes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final vote = votes[index];
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CaseDetailPage(caseId: vote.caseId),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.lineColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          vote.caseGame.isEmpty ? '판정 참여 사건' : vote.caseGame,
                          style: const TextStyle(
                            color: AppColors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: vote.settled
                                ? context.lineColor
                                : context.redPaleColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            vote.resultLabel,
                            style: TextStyle(
                              color: vote.settled
                                  ? context.inkColor
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
                      vote.caseTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '내 선택: ${vote.choiceLabel}',
                      style: TextStyle(
                        color: context.mutedColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _BookmarkedCasesTab extends StatelessWidget {
  const _BookmarkedCasesTab({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: UserService.instance.watchUser(uid),
      builder: (context, userSnap) {
        final bookmarkIds =
            userSnap.data?.bookmarkedCaseIds ?? const <String>[];
        if (bookmarkIds.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bookmark_border_rounded,
                    size: 42,
                    color: context.mutedColor,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '북마크한 관심 사건이 없습니다.',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '사건 상세 화면에서 북마크 버튼을 눌러 나중에 결과를 확인해 보세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.mutedColor, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        return StreamBuilder<List<CaseRecord>>(
          stream: CaseService.instance.watchCases(),
          builder: (context, caseSnap) {
            if (caseSnap.connectionState == ConnectionState.waiting &&
                !caseSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final bookmarked = (caseSnap.data ?? const <CaseRecord>[])
                .where((c) => bookmarkIds.contains(c.id))
                .toList();

            if (bookmarked.isEmpty) {
              return Center(
                child: Text(
                  '북마크한 사건이 삭제되었거나 존재하지 않습니다.',
                  style: TextStyle(color: context.mutedColor),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bookmarked.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = bookmarked[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CaseDetailPage(caseId: item.id),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.lineColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${item.game} · ${item.tier}',
                              style: const TextStyle(
                                color: AppColors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              item.isClosed ? '종결' : item.remainingTimeText,
                              style: TextStyle(
                                color: context.mutedColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => UserService.instance.toggleBookmark(
                                uid: uid,
                                caseId: item.id,
                                currentlyBookmarked: true,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(
                                  Icons.bookmark_rounded,
                                  color: AppColors.red,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${item.statusLabel} · 참여 ${item.totalVotes}명 · 댓글 ${item.commentCount}',
                          style: TextStyle(
                            color: context.mutedColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
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