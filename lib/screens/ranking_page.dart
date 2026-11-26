import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/app_header.dart';
import '../widgets/user_avatar.dart';

class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  String tab = '명예의 전당';
  String gameFilter = '전체';

  static const _games = ['전체', '리그 오브 레전드', '발로란트', '오버워치 2'];

  List<UserProfile> _sortUsers(List<UserProfile> users) {
    final list = users
        .where(
          (u) => gameFilter == '전체' || u.favoriteGames.contains(gameFilter),
        )
        .toList();

    if (tab == '명예의 전당') {
      // 누적 획득 포인트(상점 소비 무관) → 판정 적중률 → 참여 횟수 순
      list.sort((a, b) {
        final p = b.totalEarnedPoints.compareTo(a.totalEarnedPoints);
        if (p != 0) return p;
        final accA = a.accuracyRate ?? -1;
        final accB = b.accuracyRate ?? -1;
        final acc = accB.compareTo(accA);
        if (acc != 0) return acc;
        return b.totalVotes.compareTo(a.totalVotes);
      });
    } else {
      // 활동 경험치(XP) / 레벨 → 참여 횟수 순
      list.sort((a, b) {
        final xp = b.xp.compareTo(a.xp);
        if (xp != 0) return xp;
        return b.totalVotes.compareTo(a.totalVotes);
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService.instance.currentUser?.uid;

    return Scaffold(
      appBar: const AppHeader(title: '랭킹 & 명예의 전당'),
      bottomNavigationBar: const AppBottomNavigation(index: 3),
      body: StreamBuilder<List<UserProfile>>(
        stream: UserService.instance.watchLeaderboard(limit: 100),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '랭킹 정보를 불러오지 못했습니다.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final ranked = _sortUsers(snapshot.data ?? const <UserProfile>[]);
          final myIndex =
              myUid == null ? -1 : ranked.indexWhere((u) => u.uid == myUid);
          final myProfile = myIndex >= 0 ? ranked[myIndex] : null;
          final isPointsTab = tab == '명예의 전당';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '명예의 전당', label: Text('명예의 전당 (누적 P)')),
                  ButtonSegment(value: '배심원 랭킹', label: Text('배심원 랭킹 (활동)')),
                ],
                selected: {tab},
                onSelectionChanged: (s) => setState(() => tab = s.first),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    isPointsTab ? '실시간 누적 포인트 순위' : '실시간 활동 레벨 순위',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '총 ${ranked.length}명',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _games.map((g) {
                    final selected = gameFilter == g;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(g),
                        selected: selected,
                        selectedColor: AppColors.redPale,
                        labelStyle: TextStyle(
                          color: selected ? AppColors.red : null,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        onSelected: (_) => setState(() => gameFilter = g),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              if (ranked.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 36,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        size: 40,
                        color: AppColors.muted,
                      ),
                      SizedBox(height: 10),
                      Text(
                        '해당 조건의 배심원이 아직 없습니다.',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                _TopThree(
                  first: ranked.isNotEmpty ? ranked[0] : null,
                  second: ranked.length > 1 ? ranked[1] : null,
                  third: ranked.length > 2 ? ranked[2] : null,
                  isPointsTab: isPointsTab,
                ),
                const SizedBox(height: 14),
                ...List.generate(ranked.length, (i) {
                  final u = ranked[i];
                  final isMe = u.uid == myUid;
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isMe ? AppColors.red : Colors.transparent,
                        width: isMe ? 1.5 : 0,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 26,
                            child: Text(
                              '${i + 1}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: i < 3 ? AppColors.red : AppColors.muted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          LevelUserAvatar(
                            level: u.level,
                            photoUrl: u.photoUrl,
                            radius: 19,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 5,
                                  runSpacing: 3,
                                  children: [
                                    Text(
                                      u.nickname,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                    UserTitleBadge(
                                      titleItem: u.equippedTitleItem,
                                      compact: true,
                                    ),
                                    if (isMe)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.redPale,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          '나',
                                          style: TextStyle(
                                            color: AppColors.red,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Lv.${u.level} ${u.title} · 적중률 ${u.accuracyText} · 참여 ${u.totalVotes}회',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isPointsTab
                                ? '${u.totalEarnedPoints} P'
                                : '${u.xp} XP',
                            style: const TextStyle(
                              color: AppColors.red,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
              if (myProfile != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.redPale,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      LevelUserAvatar(
                        level: myProfile.level,
                        photoUrl: myProfile.photoUrl,
                        radius: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '내 랭킹 · ${myIndex + 1}위 (Lv.${myProfile.level})\n적중률 ${myProfile.accuracyText}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        isPointsTab
                            ? '${myProfile.totalEarnedPoints} P'
                            : '${myProfile.xp} XP',
                        style: const TextStyle(
                          color: AppColors.red,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TopThree extends StatelessWidget {
  const _TopThree({
    required this.first,
    required this.second,
    required this.third,
    required this.isPointsTab,
  });

  final UserProfile? first;
  final UserProfile? second;
  final UserProfile? third;
  final bool isPointsTab;

  String _score(UserProfile? user) {
    if (user == null) return '-';
    return isPointsTab ? '${user.totalEarnedPoints} P' : '${user.xp} XP';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 22, 8, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _Podium(
            rank: 2,
            user: second,
            score: _score(second),
            height: 68,
          ),
          _Podium(
            rank: 1,
            user: first,
            score: _score(first),
            height: 98,
          ),
          _Podium(
            rank: 3,
            user: third,
            score: _score(third),
            height: 52,
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({
    required this.rank,
    required this.user,
    required this.score,
    required this.height,
  });

  final int rank;
  final UserProfile? user;
  final String score;
  final double height;

  @override
  Widget build(BuildContext context) {
    final empty = user == null;

    return SizedBox(
      width: 96,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (empty)
            CircleAvatar(
              radius: rank == 1 ? 23 : 18,
              backgroundColor: AppColors.background,
              child: Icon(
                Icons.person,
                size: rank == 1 ? 24 : 19,
                color: AppColors.muted,
              ),
            )
          else
            LevelUserAvatar(
              level: user!.level,
              photoUrl: user!.photoUrl,
              radius: rank == 1 ? 23 : 18,
            ),
          const SizedBox(height: 8),
          Text(
            user?.nickname ?? '대기 중',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: empty ? AppColors.muted : null,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 82,
            height: height,
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: empty
                  ? AppColors.background
                  : (rank == 1 ? AppColors.red : AppColors.redPale),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Column(
              children: [
                Text(
                  '$rank위',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: empty
                        ? AppColors.muted
                        : (rank == 1 ? Colors.white : AppColors.red),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  score,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: empty
                        ? AppColors.muted
                        : (rank == 1 ? Colors.white70 : AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}