import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shop_item.dart';

typedef JsonMap = Map<String, dynamic>;

/// 겜문철 판정·보상 정책 상수 (추후 서비스 규모에 맞춰 숫자만 조정)
class PolicyConfig {
  PolicyConfig._();

  // 테스트 단계에서는 3건으로 두고, 실제 배포 시 10건으로 올리면 됩니다.
  static const int minValidJudgedForAccuracy = 3;
  static const int minVotesForValidCase = 3;
  static const double decisiveThreshold = 0.60; // 60:40 이상일 때만 유효 판결
  static const int reportHideThreshold = 3; // 누적 신고 3건 이상 시 자동 숨김

  static const int xpVote = 10;
  static const int pointsVote = 5;

  static const int xpComment = 15;
  static const int pointsComment = 5;

  static const int xpCreateCase = 30;
  static const int pointsCreateCase = 10;

  static const int xpHitBonus = 20;
  static const int pointsHitBonus = 15;

  // 일일 배심원 미션 정책
  static const int dailyMissionTarget = 3;
  static const int dailyMissionRewardPoints = 25;
  static const int dailyMissionRewardXp = 30;
}

/// 게임별 연동 계정 및 티어 정보
class GameAccountInfo {
  const GameAccountInfo({
    required this.gameId,
    required this.tier,
  });

  final String gameId;
  final String tier;

  static const List<String> tierOptions = [
    '언랭크',
    '아이언',
    '브론즈',
    '실버',
    '골드',
    '플래티넘',
    '에메랄드/다이아',
    '마스터 이상',
  ];

  /// 플래티넘 이상을 상위 티어 배심원으로 분류 (리포트 집계용)
  bool get isHighTier =>
      tier == '플래티넘' || tier == '에메랄드/다이아' || tier == '마스터 이상';

  JsonMap toMap() => {
        'gameId': gameId,
        'tier': tier,
      };

  factory GameAccountInfo.fromMap(Map<dynamic, dynamic> map) {
    return GameAccountInfo(
      gameId: (map['gameId'] as String?)?.trim() ?? '',
      tier: (map['tier'] as String?)?.trim() ?? '언랭크',
    );
  }
}

/// Firestore users/{uid} 문서와 1:1 대응하는 유저 모델
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.nickname,
    required this.email,
    required this.favoriteGames,
    required this.xp,
    required this.level,
    required this.points,
    required this.totalVotes,
    required this.validJudgedCount,
    required this.hitCount,
    required this.onboardingCompleted,
    this.notificationsEnabled = true,
    this.lastNotificationReadAt,
    this.gameAccounts = const <String, GameAccountInfo>{},
    this.photoUrl,
    int? totalEarnedPoints,
    this.ownedTitles = const <String>[],
    this.equippedTitleId,
    this.nicknameTickets = 0,
    this.boostTickets = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.dailyMissionDate = '',
    this.dailyVotesCount = 0,
    this.dailyMissionClaimed = false,
    this.bookmarkedCaseIds = const <String>[],
    this.darkMode = true,
  }) : totalEarnedPoints = totalEarnedPoints ?? points;

  final String uid;
  final String nickname;
  final String email;
  final List<String> favoriteGames;
  final int xp; // 누적 경험치
  final int level;
  final int points; // 상점에서 사용 가능한 보유 포인트
  final int totalEarnedPoints; // 누적 획득 포인트 (명예의 전당 랭킹 기준)
  final int totalVotes;
  final int validJudgedCount;
  final int hitCount;
  final bool onboardingCompleted;
  final bool notificationsEnabled;
  final DateTime? lastNotificationReadAt;
  final Map<String, GameAccountInfo> gameAccounts;
  final String? photoUrl;
  final List<String> ownedTitles;
  final String? equippedTitleId;
  final int nicknameTickets;
  final int boostTickets;
  final int currentStreak; // 현재 연속 적중 횟수
  final int bestStreak; // 역대 최고 연속 적중 횟수
  final String dailyMissionDate; // YYYY-MM-DD
  final int dailyVotesCount;
  final bool dailyMissionClaimed;
  final List<String> bookmarkedCaseIds;
  final bool darkMode;

  static String todayKey() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  int get todayVotesCount =>
      dailyMissionDate == todayKey() ? dailyVotesCount : 0;

  bool get isDailyMissionClaimedToday =>
      dailyMissionDate == todayKey() && dailyMissionClaimed;

  bool get canClaimDailyMission =>
      todayVotesCount >= PolicyConfig.dailyMissionTarget &&
      !isDailyMissionClaimedToday;

  bool isBookmarked(String caseId) => bookmarkedCaseIds.contains(caseId);

  ShopItem? get equippedTitleItem => ShopCatalog.findById(equippedTitleId);

  /// 특정 게임에 등록된 티어 조회 (없으면 '미등록')
  String tierForGame(String game) => gameAccounts[game]?.tier ?? '미등록';

  bool isHighTierForGame(String game) =>
      gameAccounts[game]?.isHighTier ?? false;

  /// 누적 XP로 현재 레벨, 현재 레벨 내 경험치, 다음 레벨 필요 XP 계산
  /// 공식: 다음 레벨 필요 XP = 현재 레벨 * 100
  static ({int level, int currentXp, int nextLevelXp}) computeLevelProgress(
    int totalXp,
  ) {
    var lv = 1;
    var remaining = totalXp < 0 ? 0 : totalXp;
    while (remaining >= lv * 100) {
      remaining -= lv * 100;
      lv++;
    }
    return (level: lv, currentXp: remaining, nextLevelXp: lv * 100);
  }

  ({int level, int currentXp, int nextLevelXp}) get levelProgress =>
      computeLevelProgress(xp);

  /// 레벨 구간별 기본 칭호
  String get title {
    if (level >= 20) return '수석 판사';
    if (level >= 10) return '신뢰 배심원';
    if (level >= 5) return '시민 배심원';
    return '견습 배심원';
  }

  /// 최소 유효 판결 참여 수 이상일 때만 적중률 계산
  double? get accuracyRate {
    if (validJudgedCount < PolicyConfig.minValidJudgedForAccuracy) return null;
    return (hitCount / validJudgedCount) * 100;
  }

  String get accuracyText {
    final rate = accuracyRate;
    if (rate == null) {
      return '산정 중 ($validJudgedCount/${PolicyConfig.minValidJudgedForAccuracy}건)';
    }
    return '${rate.toStringAsFixed(1)}%';
  }

  factory UserProfile.fromDoc(DocumentSnapshot<JsonMap> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final totalXp = (data['xp'] as num?)?.toInt() ?? 0;
    final progress = computeLevelProgress(totalXp);
    final lastReadTs = data['lastNotificationReadAt'] as Timestamp?;
    final currentPoints = (data['points'] as num?)?.toInt() ?? 0;
    final earnedPoints =
        (data['totalEarnedPoints'] as num?)?.toInt() ?? currentPoints;

    final rawAccounts = data['gameAccounts'];
    final parsedAccounts = <String, GameAccountInfo>{};
    if (rawAccounts is Map) {
      rawAccounts.forEach((key, value) {
        if (value is Map) {
          parsedAccounts[key.toString()] = GameAccountInfo.fromMap(value);
        }
      });
    }

    return UserProfile(
      uid: doc.id,
      nickname: (data['nickname'] as String?)?.trim().isNotEmpty == true
          ? (data['nickname'] as String).trim()
          : '신규 배심원',
      email: (data['email'] as String?) ?? '',
      favoriteGames: (data['favoriteGames'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      xp: totalXp,
      level: (data['level'] as num?)?.toInt() ?? progress.level,
      points: currentPoints,
      totalEarnedPoints: earnedPoints,
      totalVotes: (data['totalVotes'] as num?)?.toInt() ?? 0,
      validJudgedCount: (data['validJudgedCount'] as num?)?.toInt() ?? 0,
      hitCount: (data['hitCount'] as num?)?.toInt() ?? 0,
      onboardingCompleted: (data['onboardingCompleted'] as bool?) ?? false,
      notificationsEnabled: (data['notificationsEnabled'] as bool?) ?? true,
      lastNotificationReadAt: lastReadTs?.toDate(),
      gameAccounts: parsedAccounts,
      photoUrl: (data['photoUrl'] as String?)?.trim().isNotEmpty == true
          ? (data['photoUrl'] as String).trim()
          : null,
      ownedTitles: (data['ownedTitles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      equippedTitleId: data['equippedTitleId'] as String?,
      nicknameTickets: (data['nicknameTickets'] as num?)?.toInt() ?? 0,
      boostTickets: (data['boostTickets'] as num?)?.toInt() ?? 0,
      currentStreak: (data['currentStreak'] as num?)?.toInt() ?? 0,
      bestStreak: (data['bestStreak'] as num?)?.toInt() ?? 0,
      dailyMissionDate: (data['dailyMissionDate'] as String?) ?? '',
      dailyVotesCount: (data['dailyVotesCount'] as num?)?.toInt() ?? 0,
      dailyMissionClaimed: (data['dailyMissionClaimed'] as bool?) ?? false,
      bookmarkedCaseIds: (data['bookmarkedCaseIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      darkMode: (data['darkMode'] as bool?) ?? true,
    );
  }
}

class UserService {
  UserService._();
  static final instance = UserService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<JsonMap> get _users => _db.collection('users');

  /// 로그인·회원가입 시 Firestore에 유저 문서가 없으면 초기값으로 생성
  Future<UserProfile> ensureUserDocument(
    User firebaseUser, {
    String? preferredNickname,
  }) async {
    final docRef = _users.doc(firebaseUser.uid);
    final snapshot = await docRef.get();

    if (snapshot.exists) {
      return UserProfile.fromDoc(snapshot);
    }

    final fallbackEmailName =
        (firebaseUser.email != null && firebaseUser.email!.contains('@'))
            ? firebaseUser.email!.split('@').first
            : '신규 배심원';
    final resolvedNickname =
        (preferredNickname?.trim().isNotEmpty == true)
            ? preferredNickname!.trim()
            : (firebaseUser.displayName?.trim().isNotEmpty == true)
                ? firebaseUser.displayName!.trim()
                : fallbackEmailName;

    await docRef.set({
      'nickname': resolvedNickname,
      'email': firebaseUser.email ?? '',
      'photoUrl': firebaseUser.photoURL,
      'favoriteGames': <String>[],
      'gameAccounts': <String, dynamic>{},
      'ownedTitles': <String>[],
      'equippedTitleId': null,
      'nicknameTickets': 0,
      'boostTickets': 0,
      'xp': 0,
      'level': 1,
      'points': 0,
      'totalEarnedPoints': 0,
      'totalVotes': 0,
      'validJudgedCount': 0,
      'hitCount': 0,
      'currentStreak': 0,
      'bestStreak': 0,
      'dailyMissionDate': '',
      'dailyVotesCount': 0,
      'dailyMissionClaimed': false,
      'bookmarkedCaseIds': <String>[],
      'darkMode': true,
      'onboardingCompleted': false,
      'notificationsEnabled': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final created = await docRef.get();
    return UserProfile.fromDoc(created);
  }

  /// 내 유저 정보 실시간 구독 (프로필·홈·알림·토론 자동 갱신용)
  Stream<UserProfile?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromDoc(doc);
    });
  }

  /// 내 유저 정보 1회 조회
  Future<UserProfile?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromDoc(doc);
  }

  /// 전체 유저 실시간 랭킹 구독 (기존 유저 누락 없이 누적 획득 포인트 순 정렬)
  Stream<List<UserProfile>> watchLeaderboard({int limit = 100}) {
    return _users.limit(limit).snapshots().map((snap) {
      final list = snap.docs.map(UserProfile.fromDoc).toList();
      list.sort((a, b) => b.totalEarnedPoints.compareTo(a.totalEarnedPoints));
      return list;
    });
  }

  /// 온보딩에서 선택한 관심 게임 저장
  Future<void> saveFavoriteGames(String uid, List<String> games) async {
    await _users.doc(uid).set(
      {
        'favoriteGames': games,
        'onboardingCompleted': true,
      },
      SetOptions(merge: true),
    );
  }

  /// 다크 모드 설정 저장
  Future<void> updateDarkMode(String uid, bool enabled) async {
    await _users.doc(uid).set(
      {'darkMode': enabled},
      SetOptions(merge: true),
    );
  }

  /// 관심 사건 북마크(찜) 토글
  Future<void> toggleBookmark({
    required String uid,
    required String caseId,
    required bool currentlyBookmarked,
  }) async {
    await _users.doc(uid).set(
      {
        'bookmarkedCaseIds': currentlyBookmarked
            ? FieldValue.arrayRemove([caseId])
            : FieldValue.arrayUnion([caseId]),
      },
      SetOptions(merge: true),
    );
  }

  /// 일일 배심원 미션 보상 수령 (하루 3건 판정 달성 시 +25 P, +30 XP)
  Future<void> claimDailyMission(String uid) async {
    final docRef = _users.doc(uid);
    final today = UserProfile.todayKey();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() ?? const <String, dynamic>{};

      final date = (data['dailyMissionDate'] as String?) ?? '';
      final count =
          date == today ? ((data['dailyVotesCount'] as num?)?.toInt() ?? 0) : 0;
      final claimed =
          date == today && ((data['dailyMissionClaimed'] as bool?) ?? false);

      if (count < PolicyConfig.dailyMissionTarget) {
        throw StateError(
          '오늘 판정 ${PolicyConfig.dailyMissionTarget}건을 완료해야 보상을 받을 수 있습니다. ($count/${PolicyConfig.dailyMissionTarget})',
        );
      }
      if (claimed) {
        throw StateError('오늘의 미션 보상을 이미 수령했습니다.');
      }

      final prevXp = (data['xp'] as num?)?.toInt() ?? 0;
      final prevPoints = (data['points'] as num?)?.toInt() ?? 0;
      final prevEarned =
          (data['totalEarnedPoints'] as num?)?.toInt() ?? prevPoints;

      final nextXp = prevXp + PolicyConfig.dailyMissionRewardXp;
      final nextLevel = UserProfile.computeLevelProgress(nextXp).level;

      tx.set(
        docRef,
        {
          'xp': nextXp,
          'level': nextLevel,
          'points': prevPoints + PolicyConfig.dailyMissionRewardPoints,
          'totalEarnedPoints':
              prevEarned + PolicyConfig.dailyMissionRewardPoints,
          'dailyMissionDate': today,
          'dailyMissionClaimed': true,
        },
        SetOptions(merge: true),
      );
    });
  }

  /// 프로필 사진 URL 저장 (null 전달 시 기본 아바타로 초기화)
  Future<void> updatePhotoUrl(String uid, String? photoUrl) async {
    await _users.doc(uid).set(
      {'photoUrl': photoUrl},
      SetOptions(merge: true),
    );
  }

  /// 닉네임 변경 (requireTicket이 true이면 닉네임 변경권 1장 차감)
  Future<void> updateNickname(
    String uid,
    String nickname, {
    bool requireTicket = false,
  }) async {
    final trimmed = nickname.trim();
    if (trimmed.isEmpty) return;

    final docRef = _users.doc(uid);
    if (!requireTicket) {
      await docRef.set({'nickname': trimmed}, SetOptions(merge: true));
      return;
    }

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() ?? const <String, dynamic>{};
      final tickets = (data['nicknameTickets'] as num?)?.toInt() ?? 0;
      if (tickets < 1) {
        throw StateError('보유한 닉네임 변경권이 없습니다. 포인트 상점에서 구매해 주세요.');
      }
      tx.set(
        docRef,
        {
          'nickname': trimmed,
          'nicknameTickets': tickets - 1,
        },
        SetOptions(merge: true),
      );
    });
  }

  /// 포인트 상점 아이템 구매 (보유 포인트 차감 · 누적 포인트 유지)
  Future<void> purchaseShopItem({
    required String uid,
    required ShopItem item,
  }) async {
    final docRef = _users.doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() ?? const <String, dynamic>{};

      final currentPoints = (data['points'] as num?)?.toInt() ?? 0;
      final currentEarned =
          (data['totalEarnedPoints'] as num?)?.toInt() ?? currentPoints;

      if (currentPoints < item.price) {
        throw StateError(
          '포인트가 부족합니다. (보유 $currentPoints P / 필요 ${item.price} P)',
        );
      }

      final updates = <String, dynamic>{
        'points': currentPoints - item.price,
        'totalEarnedPoints': currentEarned,
      };

      if (item.isTitle) {
        final owned = (data['ownedTitles'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[];
        if (owned.contains(item.id)) {
          throw StateError('이미 보유 중인 칭호입니다.');
        }
        owned.add(item.id);
        updates['ownedTitles'] = owned;
        if (data['equippedTitleId'] == null) {
          updates['equippedTitleId'] = item.id;
        }
      } else if (item.id == ShopCatalog.nicknameTicketId) {
        final currentTickets = (data['nicknameTickets'] as num?)?.toInt() ?? 0;
        updates['nicknameTickets'] = currentTickets + 1;
      } else if (item.id == ShopCatalog.caseBoostId) {
        final currentBoosts = (data['boostTickets'] as num?)?.toInt() ?? 0;
        updates['boostTickets'] = currentBoosts + 1;
      }

      tx.set(docRef, updates, SetOptions(merge: true));
    });
  }

  /// 보유 칭호 장착/해제 (null 전달 시 기본 레벨 칭호로 해제)
  Future<void> equipTitle({
    required String uid,
    required String? titleId,
  }) async {
    final docRef = _users.doc(uid);
    if (titleId == null) {
      await docRef.set({'equippedTitleId': null}, SetOptions(merge: true));
      return;
    }

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final owned = (snap.data()?['ownedTitles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      if (!owned.contains(titleId)) {
        throw StateError('보유하지 않은 칭호입니다.');
      }
      tx.set(docRef, {'equippedTitleId': titleId}, SetOptions(merge: true));
    });
  }

  /// 긴급 재판 부스트권 1장 차감
  Future<void> consumeBoostTicket(String uid) async {
    final docRef = _users.doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final tickets = (snap.data()?['boostTickets'] as num?)?.toInt() ?? 0;
      if (tickets < 1) {
        throw StateError('보유한 긴급 재판 부스트권이 없습니다. 상점에서 구매해 주세요.');
      }
      tx.set(
        docRef,
        {'boostTickets': tickets - 1},
        SetOptions(merge: true),
      );
    });
  }

  /// 게임별 계정 닉네임 및 티어 저장
  Future<void> saveGameAccount({
    required String uid,
    required String game,
    required String gameId,
    required String tier,
  }) async {
    await _users.doc(uid).set(
      {
        'gameAccounts': {
          game: GameAccountInfo(
            gameId: gameId.trim(),
            tier: tier,
          ).toMap(),
        },
      },
      SetOptions(merge: true),
    );
  }

  /// 특정 게임 계정 연동 해제
  Future<void> removeGameAccount({
    required String uid,
    required String game,
  }) async {
    await _users.doc(uid).update({
      'gameAccounts.$game': FieldValue.delete(),
    });
  }

  /// 프로필의 판정 알림 스위치 저장
  Future<void> updateNotificationSetting(String uid, bool enabled) async {
    await _users.doc(uid).set(
      {'notificationsEnabled': enabled},
      SetOptions(merge: true),
    );
  }

  /// 알림함 확인 시각 기록 (안 읽은 알림 배지 초기화)
  Future<void> markNotificationsRead(String uid) async {
    await _users.doc(uid).set(
      {'lastNotificationReadAt': Timestamp.fromDate(DateTime.now())},
      SetOptions(merge: true),
    );
  }

  /// 회원 탈퇴 시 Firestore 유저 문서 및 myVotes 정리
  Future<void> deleteUserDocument(String uid) async {
    final userRef = _users.doc(uid);
    final myVotesSnap = await userRef.collection('myVotes').get();

    final batch = _db.batch();
    for (final doc in myVotesSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(userRef);
    await batch.commit();
  }

  /// 경험치·포인트·투표 통계·스트릭·일일 미션 진행도 안전하게 갱신 (트랜잭션)
  Future<void> addReward({
    required String uid,
    int xpDelta = 0,
    int pointsDelta = 0,
    int totalVotesDelta = 0,
    int validJudgedDelta = 0,
    int hitDelta = 0,
    bool? streakResult,
  }) async {
    final docRef = _users.doc(uid);
    final today = UserProfile.todayKey();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() ?? const <String, dynamic>{};

      final prevPoints = (data['points'] as num?)?.toInt() ?? 0;
      final prevEarned =
          (data['totalEarnedPoints'] as num?)?.toInt() ?? prevPoints;

      final nextXp = ((data['xp'] as num?)?.toInt() ?? 0) + xpDelta;
      final nextLevel = UserProfile.computeLevelProgress(nextXp).level;
      final nextPoints = prevPoints + pointsDelta;
      final nextEarned =
          pointsDelta > 0 ? prevEarned + pointsDelta : prevEarned;
      final nextTotalVotes =
          ((data['totalVotes'] as num?)?.toInt() ?? 0) + totalVotesDelta;
      final nextValidJudged =
          ((data['validJudgedCount'] as num?)?.toInt() ?? 0) + validJudgedDelta;
      final nextHit = ((data['hitCount'] as num?)?.toInt() ?? 0) + hitDelta;

      final updates = <String, dynamic>{
        'xp': nextXp,
        'level': nextLevel,
        'points': nextPoints,
        'totalEarnedPoints': nextEarned,
        'totalVotes': nextTotalVotes,
        'validJudgedCount': nextValidJudged,
        'hitCount': nextHit,
      };

      // 일일 미션(오늘 투표 수) 자동 누적
      if (totalVotesDelta > 0) {
        final prevDate = (data['dailyMissionDate'] as String?) ?? '';
        final prevDaily = prevDate == today
            ? ((data['dailyVotesCount'] as num?)?.toInt() ?? 0)
            : 0;
        final prevClaimed = prevDate == today &&
            ((data['dailyMissionClaimed'] as bool?) ?? false);
        updates['dailyMissionDate'] = today;
        updates['dailyVotesCount'] = prevDaily + totalVotesDelta;
        updates['dailyMissionClaimed'] = prevClaimed;
      }

      // 연속 적중 스트릭 갱신
      if (streakResult != null) {
        final prevStreak = (data['currentStreak'] as num?)?.toInt() ?? 0;
        final prevBest = (data['bestStreak'] as num?)?.toInt() ?? 0;
        final nextStreak = streakResult ? prevStreak + 1 : 0;
        final nextBest = nextStreak > prevBest ? nextStreak : prevBest;
        updates['currentStreak'] = nextStreak;
        updates['bestStreak'] = nextBest;
      }

      tx.set(docRef, updates, SetOptions(merge: true));
    });
  }

  /// 누적 획득 포인트 기준 전체 순위 계산 (상점에서 포인트를 써도 순위 유지)
  Future<int> getUserRank(int myEarnedPoints) async {
    final snap = await _users.get();
    var higher = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final earned = (data['totalEarnedPoints'] as num?)?.toInt() ??
          (data['points'] as num?)?.toInt() ??
          0;
      if (earned > myEarnedPoints) higher++;
    }
    return higher + 1;
  }
}