import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/case_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/app_header.dart';
import '../widgets/game_filter.dart';
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
  final _searchController = TextEditingController();
  String filter = '전체';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    unawaited(_settlePendingVotes());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    final isSearching = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      appBar: const AppHeader(),
      bottomNavigationBar: AppBottomNavigation(index: widget.liveOnly ? 1 : 0),
      body: StreamBuilder<UserProfile?>(
        stream: uid != null
            ? UserService.instance.watchUser(uid)
            : const Stream<UserProfile?>.empty(),
        builder: (context, userSnap) {
          final favoriteGames =
              userSnap.data?.favoriteGames ?? const <String>[];

          return StreamBuilder<List<CaseRecord>>(
            stream: CaseService.instance.watchCases(),
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
                      '사건 목록을 불러오지 못했습니다.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final allCases = snapshot.data ?? const <CaseRecord>[];
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
                          color: AppColors.redPale,
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
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: AppColors.muted,
                      ),
                      suffixIcon: isSearching
                          ? IconButton(
                              tooltip: '검색어 지우기',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppColors.muted,
                              ),
                            )
                          : null,
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GameFilter(
                    value: filter,
                    onChanged: (v) => setState(() => filter = v),
                  ),
                  if (!isSearching &&
                      favoriteGames.isNotEmpty &&
                      (filter == '전체' || filter == '관심 종목')) ...[
                    const SizedBox(height: 8),
                    Text(
                      filter == '관심 종목'
                          ? '내 관심 종목만 보기: ${favoriteGames.join(', ')}'
                          : '내 관심 종목(${favoriteGames.join(', ')}) 사건이 우선 추천됩니다.',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (heroCase != null) ...[
                    const SizedBox(height: 15),
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
                        style: const TextStyle(
                          color: AppColors.muted,
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
                ],
              );
            },
          );
        },
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
                        : AppColors.red,
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
              '${item.game} · ${item.tier} · ${item.remainingTimeText}',
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.isBoosted ? const Color(0xFFF97316) : AppColors.line,
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
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF97316)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.rocket_launch_rounded,
                          size: 11,
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
                    '${item.game} · ${item.tier}',
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
                      color: AppColors.redPale,
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
                    color: item.isClosed ? AppColors.line : AppColors.redPale,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.isClosed ? '종결' : item.remainingTimeText,
                    style: TextStyle(
                      color: item.isClosed ? AppColors.muted : AppColors.red,
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
                style: const TextStyle(
                  color: AppColors.muted,
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
                  color: AppColors.redPale,
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
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                LiveUserTitleBadge(uid: item.authorUid, compact: true),
                const Spacer(),
                Text(
                  '배심원 ${item.totalVotes}명 · 댓글 ${item.commentCount}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Icon(
            isSearching ? Icons.search_off_rounded : Icons.gavel_rounded,
            size: 42,
            color: AppColors.muted,
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
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
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