import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/case_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/app_header.dart';
import '../widgets/game_filter.dart';
import '../widgets/juror_profile_sheet.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/user_avatar.dart';
import '../widgets/verdict_bar.dart';
import 'case_create_step1_page.dart';
import 'case_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.liveOnly = false});
  final bool liveOnly;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const int _pageStep = 15;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  late Stream<List<CaseRecord>> _casesStream;
  Stream<UserProfile?>? _userStream;

  int _caseLimit = _pageStep;
  bool _canLoadMore = false;
  String filter = '전체';
  String _searchQuery = '';
  bool _isClaimingMission = false;

  @override
  void initState() {
    super.initState();
    final uid = AuthService.instance.currentUser?.uid;
    _userStream = uid != null ? UserService.instance.watchUser(uid) : null;
    _casesStream = CaseService.instance.watchCases(limit: _caseLimit);
    _scrollController.addListener(_onScroll);
    unawaited(_settlePendingVotes());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_canLoadMore || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _loadMoreCases();
    }
  }

  void _loadMoreCases() {
    if (!_canLoadMore) return;
    setState(() {
      _canLoadMore = false;
      _caseLimit += _pageStep;
      _casesStream = CaseService.instance.watchCases(limit: _caseLimit);
    });
  }

  bool _matchesSearch(CaseRecord c) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    return c.title.toLowerCase().contains(q) ||
        c.game.toLowerCase().contains(q) ||
        c.tier.toLowerCase().contains(q) ||
        c.type.toLowerCase().contains(q) ||
        c.description.toLowerCase().contains(q) ||
        c.authorNickname.toLowerCase().contains(q) ||
        c.issues.any((tag) => tag.toLowerCase().contains(q));
  }

  Future<void> _settlePendingVotes() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final result = await CaseService.instance.settleMyVotes(uid);
      if (!mounted || result.settledCount == 0) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '마감된 판결 ${result.settledCount}건 정산 완료 (적중 ${result.hitCount}건)',
          ),
        ),
      );
    } catch (e) {
      debugPrint('투표 정산 건너뜀: $e');
    }
  }

  Future<void> _claimMission(UserProfile profile) async {
    if (_isClaimingMission) return;
    setState(() => _isClaimingMission = true);
    try {
      await UserService.instance.claimDailyMission(profile.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '오늘의 배심원 미션 완료! +${PolicyConfig.dailyMissionRewardPoints} P · +${PolicyConfig.dailyMissionRewardXp} XP 지급',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _isClaimingMission = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    final isSearching = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      appBar: const AppHeader(),
      bottomNavigationBar: AppBottomNavigation(index: widget.liveOnly ? 1 : 0),
      body: StreamBuilder<UserProfile?>(
        stream: _userStream,
        builder: (context, userSnap) {
          final userProfile = userSnap.data;
          final favoriteGames =
              userProfile?.favoriteGames ?? const <String>[];

          return StreamBuilder<List<CaseRecord>>(
            stream: _casesStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const HomeFeedSkeleton();
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '사건 목록을 불러오지 못했습니다.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final rawCases = snapshot.data ?? const <CaseRecord>[];
              final isLoadingMore =
                  snapshot.connectionState == ConnectionState.waiting &&
                      snapshot.hasData;
              _canLoadMore =
                  snapshot.connectionState == ConnectionState.active &&
                      rawCases.length >= _caseLimit;

              // 누적 신고 3건 이상 숨김 사건은 피드에서 제외
              final allCases = rawCases
                  .where((c) => !c.isHidden || c.authorUid == uid)
                  .toList();
              final openCases = allCases.where((c) => !c.isClosed).toList();

              final filtered = allCases.where((c) {
                if (widget.liveOnly && c.isClosed) return false;
                if (!_matchesSearch(c)) return false;
                if (filter == '전체') return true;
                if (filter == '관심 종목') {
                  return favoriteGames.isEmpty ||
                      favoriteGames.contains(c.game);
                }
                return c.game == filter;
              }).toList();

              // 1순위: 긴급 재판 부스트 / 2순위: (전체 보기일 때) 내 관심 종목 / 3순위: 최신순
              filtered.sort((a, b) {
                final aBoost = a.isBoosted ? 1 : 0;
                final bBoost = b.isBoosted ? 1 : 0;
                if (aBoost != bBoost) return bBoost.compareTo(aBoost);

                if (filter == '전체' && favoriteGames.isNotEmpty) {
                  final aFav = favoriteGames.contains(a.game) ? 1 : 0;
                  final bFav = favoriteGames.contains(b.game) ? 1 : 0;
                  if (aFav != bFav) return bFav.compareTo(aFav);
                }
                return b.createdAt.compareTo(a.createdAt);
              });

              // 상단 주목 판정: 부스트 사건 → 내 관심 종목 사건 → 전체 진행 중 사건 순
              CaseRecord? heroCase;
              var heroIsFavorite = false;
              if (!widget.liveOnly && !isSearching && openCases.isNotEmpty) {
                final boostedOpen =
                    openCases.where((c) => c.isBoosted).toList();
                if (boostedOpen.isNotEmpty) {
                  boostedOpen
                      .sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  heroCase = boostedOpen.first;
                  heroIsFavorite = favoriteGames.contains(heroCase.game);
                } else {
                  final favOpen = openCases
                      .where((c) => favoriteGames.contains(c.game))
                      .toList();
                  final pool = favOpen.isNotEmpty ? favOpen : openCases;
                  heroIsFavorite = favOpen.isNotEmpty;
                  heroCase = pool.reduce(
                    (a, b) => a.totalVotes >= b.totalVotes ? a : b,
                  );
                }
              }

              return ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.liveOnly ? '실시간 진행 중 사건' : '오늘의 판결 & 실시간',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.redPaleColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'LIVE ${openCases.length}',
                          style: const TextStyle(
                            color: AppColors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: '사건 제목, 게임, 티어, 쟁점 검색',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: context.mutedColor,
                      ),
                      suffixIcon: isSearching
                          ? IconButton(
                              tooltip: '검색어 지우기',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: context.mutedColor,
                              ),
                            )
                          : null,
                      isDense: true,
                      filled: true,
                      fillColor: context.surfaceColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.lineColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.lineColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GameFilter(
                    value: filter,
                    onChanged: (v) => setState(() => filter = v),
                  ),
                  if (!widget.liveOnly &&
                      !isSearching &&
                      userProfile != null &&
                      !userProfile.isDailyMissionClaimedToday) ...[
                    const SizedBox(height: 12),
                    _DailyMissionBanner(
                      profile: userProfile,
                      isClaiming: _isClaimingMission,
                      onClaim: () => _claimMission(userProfile),
                    ),
                  ],
                  if (!isSearching &&
                      favoriteGames.isNotEmpty &&
                      (filter == '전체' || filter == '관심 종목')) ...[
                    const SizedBox(height: 8),
                    Text(
                      filter == '관심 종목'
                          ? '내 관심 종목만 보기: ${favoriteGames.join(', ')}'
                          : '내 관심 종목(${favoriteGames.join(', ')}) 사건이 우선 추천됩니다.',
                      style: TextStyle(
                        color: context.mutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (heroCase != null) ...[
                    const SizedBox(height: 14),
                    _LiveHero(
                      item: heroCase,
                      isFavoriteRecommendation: heroIsFavorite,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CaseDetailPage(caseId: heroCase!.id),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isSearching
                              ? '"${_searchQuery.trim()}" 검색 결과'
                              : (filter == '관심 종목' ? '내 관심 종목 사건' : '등록된 사건'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '총 ${filtered.length}건',
                        style: TextStyle(
                          color: context.mutedColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (filtered.isEmpty)
                    _EmptyCasesCard(
                      isFiltered:
                          isSearching || filter != '전체' || widget.liveOnly,
                      isSearching: isSearching,
                      onCreateTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CaseCreateStep1Page(),
                        ),
                      ),
                    )
                  else
                    ...filtered.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RealCaseCard(
                          item: c,
                          isFavoriteGame: favoriteGames.contains(c.game),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CaseDetailPage(caseId: c.id),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      ),
                    )
                  else if (_canLoadMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: OutlinedButton.icon(
                        onPressed: _loadMoreCases,
                        icon: const Icon(Icons.expand_more_rounded, size: 18),
                        label: const Text('이전 사건 더 불러오기'),
                      ),
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

class _DailyMissionBanner extends StatelessWidget {
  const _DailyMissionBanner({
    required this.profile,
    required this.isClaiming,
    required this.onClaim,
  });

  final UserProfile profile;
  final bool isClaiming;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final progress =
        (profile.todayVotesCount / PolicyConfig.dailyMissionTarget)
            .clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              profile.canClaimDailyMission ? AppColors.gold : context.lineColor,
          width: profile.canClaimDailyMission ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: AppColors.gold,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘의 배심원 미션 (${profile.todayVotesCount}/${PolicyConfig.dailyMissionTarget}) · +${PolicyConfig.dailyMissionRewardPoints} P',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: context.redPaleColor,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          ),
          if (profile.canClaimDailyMission) ...[
            const SizedBox(width: 10),
            FilledButton(
              onPressed: isClaiming ? null : onClaim,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(isClaiming ? '...' : '보상 받기'),
            ),
          ],
        ],
      ),
    );
  }
}

class _VideoThumbnailBox extends StatelessWidget {
  const _VideoThumbnailBox({
    required this.thumbnailUrl,
    this.height = 156,
  });

  final String? thumbnailUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    final hasThumb = thumbnailUrl != null && thumbnailUrl!.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasThumb)
              Image.network(
                thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: AppColors.field),
              )
            else
              Container(color: AppColors.field),
            Container(color: Colors.black26),
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 46,
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.videocam_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '영상 증거',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveHero extends StatelessWidget {
  const _LiveHero({
    required this.item,
    required this.isFavoriteRecommendation,
    required this.onTap,
  });

  final CaseRecord item;
  final bool isFavoriteRecommendation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final heroLabel = item.isBoosted
        ? '긴급 재판 부스트 사건'
        : (isFavoriteRecommendation ? '내 관심 종목 주목 판정' : '실시간 주목 판정');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(14),
          border: item.isBoosted
              ? Border.all(color: const Color(0xFFF97316), width: 1.8)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (item.isBoosted) ...[
                  const Icon(
                    Icons.rocket_launch_rounded,
                    color: Color(0xFFFB923C),
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  heroLabel,
                  style: TextStyle(
                    color: item.isBoosted
                        ? const Color(0xFFFB923C)
                        : AppColors.lavender,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text(
                  '${item.totalVotes}명 참여',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
            if (item.hasVideo) ...[
              const SizedBox(height: 12),
              _VideoThumbnailBox(
                thumbnailUrl: item.thumbnailUrl,
                height: 148,
              ),
            ],
            const SizedBox(height: 14),
            Text(
              item.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${item.game} · ${item.tier} ·${item.remainingTimeText}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    color: Colors.white70,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '블라인드 투표 진행 중 · 판정 참여 시 비율 공개',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RealCaseCard extends StatelessWidget {
  const _RealCaseCard({
    required this.item,
    required this.isFavoriteGame,
    required this.onTap,
  });

  final CaseRecord item;
  final bool isFavoriteGame;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.isBoosted ? const Color(0xFFF97316) : context.lineColor,
            width: item.isBoosted ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (item.isBoosted) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF97316)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.rocket_launch_rounded,
                          size: 11,
                          color: Color(0xFFFB923C),
                        ),
                        SizedBox(width: 3),
                        Text(
                          '긴급 판정',
                          style: TextStyle(
                            color: Color(0xFFFB923C),
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
                    '${item.game} ·${item.tier}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (isFavoriteGame) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.redPaleColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '관심',
                      style: TextStyle(
                        color: AppColors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: item.isClosed
                        ? context.lineColor
                        : context.redPaleColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.isClosed ? '종결' : item.remainingTimeText,
                    style: TextStyle(
                      color: item.isClosed ? context.mutedColor : AppColors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 1.3,
              ),
            ),
            if (item.hasVideo) ...[
              const SizedBox(height: 10),
              _VideoThumbnailBox(
                thumbnailUrl: item.thumbnailUrl,
                height: 156,
              ),
            ],
            const SizedBox(height: 10),
            if (item.isClosed) ...[
              VerdictBar(left: item.leftPercent, right: item.rightPercent),
              const SizedBox(height: 6),
              Text(
                item.statusLabel,
                style: TextStyle(
                  color: context.mutedColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.redPaleColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 15,
                      color: AppColors.red,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '블라인드 투표 진행 중 (투표 후 결과 공개)',
                      style: TextStyle(
                        color: AppColors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => showJurorProfileSheet(
                      context,
                      uid: item.authorUid,
                      fallbackNickname: item.authorNickname,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          LiveUserAvatar(
                            uid: item.authorUid,
                            radius: 11,
                            showEmblems: false,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              item.authorNickname,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.mutedColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          LiveUserTitleBadge(
                            uid: item.authorUid,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '배심원 ${item.totalVotes}명 · 댓글 ${item.commentCount}',
                  style: TextStyle(color: context.mutedColor, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCasesCard extends StatelessWidget {
  const _EmptyCasesCard({
    required this.isFiltered,
    required this.isSearching,
    required this.onCreateTap,
  });

  final bool isFiltered;
  final bool isSearching;
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.lineColor),
      ),
      child: Column(
        children: [
          Icon(
            isSearching ? Icons.search_off_rounded : Icons.gavel_rounded,
            size: 42,
            color: context.mutedColor,
          ),
          const SizedBox(height: 12),
          Text(
            isSearching
                ? '검색 결과가 없습니다.'
                : (isFiltered ? '조건에 맞는 사건이 없습니다.' : '아직 등록된 사건이 없습니다.'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            isSearching
                ? '다른 키워드로 검색하거나 게임 필터를 전체로 바꿔보세요.'
                : '첫 번째 게임 과실 사건을 등록하고 배심원 판정을 받아보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedColor, fontSize: 13),
          ),
          if (!isSearching) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreateTap,
              style: FilledButton.styleFrom(backgroundColor: AppColors.red),
              icon: const Icon(Icons.add_rounded),
              label: const Text('사건 제보하기'),
            ),
          ],
        ],
      ),
    );
  }
}