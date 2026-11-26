import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/case_model.dart';
import 'user_service.dart';

/// Firestore cases/{caseId} 문서와 1:1 대응하는 실제 사건 모델
class CaseRecord {
  const CaseRecord({
    required this.id,
    required this.authorUid,
    required this.authorNickname,
    required this.game,
    required this.title,
    required this.type,
    required this.tier,
    required this.description,
    required this.partyAStatement,
    required this.partyBStatement,
    required this.issues,
    required this.leftVotes,
    required this.rightVotes,
    required this.commentCount,
    required this.status,
    required this.winner,
    required this.createdAt,
    required this.expiresAt,
    this.videoUrl,
    this.thumbnailUrl,
    this.boostedUntil,
    this.reportedBy = const <String>[],
  });

  final String id;
  final String authorUid;
  final String authorNickname;
  final String game;
  final String title;
  final String type;
  final String tier;
  final String description;
  final String partyAStatement;
  final String partyBStatement;
  final List<String> issues;
  final int leftVotes; // Party A(신청인) 과실 표
  final int rightVotes; // Party B(상대방) 과실 표
  final int commentCount;
  final String status; // 'open' | 'closed'
  final String? winner; // 'left' | 'right' | 'draw' | null
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? videoUrl;
  final String? thumbnailUrl;
  final DateTime? boostedUntil;
  final List<String> reportedBy;

  bool get hasVideo => videoUrl != null && videoUrl!.trim().isNotEmpty;
  bool get isHidden => reportedBy.length >= PolicyConfig.reportHideThreshold;
  bool isReportedBy(String? uid) => uid != null && reportedBy.contains(uid);

  int get totalVotes => leftVotes + rightVotes;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isClosed => status == 'closed' || isExpired;

  bool get isBoosted =>
      !isClosed &&
      boostedUntil != null &&
      boostedUntil!.isAfter(DateTime.now());

  int get leftPercent {
    if (totalVotes == 0) return 50;
    return ((leftVotes / totalVotes) * 100).round();
  }

  int get rightPercent => 100 - leftPercent;

  String get statusLabel {
    if (!isClosed) return '실시간 판정 중';
    return switch (winner) {
      'left' => '판정 종결 · 신청인 과실',
      'right' => '판정 종결 · 상대방 과실',
      'draw' => '판정 종결 · 치열한 논쟁(보류)',
      _ => '판정 종결',
    };
  }

  String get remainingTimeText {
    if (isClosed) return '투표 마감';
    final diff = expiresAt.difference(DateTime.now());
    if (diff.inDays >= 1) {
      return '${diff.inDays}일 ${diff.inHours % 24}시간 남음';
    }
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m 남음';
  }

  /// 기존 DiscussionPage / VerdictReportPage 호환용 변환
  GameCase toLegacyGameCase() => GameCase(
        id: id,
        game: game,
        title: title,
        status: statusLabel,
        leftRate: leftPercent,
        rightRate: rightPercent,
        comments: commentCount,
        live: !isClosed,
        description: description,
      );

  factory CaseRecord.fromDoc(DocumentSnapshot<JsonMap> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdTs = data['createdAt'] as Timestamp?;
    final expiresTs = data['expiresAt'] as Timestamp?;
    final boostedTs = data['boostedUntil'] as Timestamp?;
    final created = createdTs?.toDate() ?? DateTime.now();
    final expires =
        expiresTs?.toDate() ?? created.add(const Duration(hours: 24));

    return CaseRecord(
      id: doc.id,
      authorUid: (data['authorUid'] as String?) ?? '',
      authorNickname: (data['authorNickname'] as String?) ?? '익명 배심원',
      game: (data['game'] as String?) ?? '리그 오브 레전드',
      title: (data['title'] as String?) ?? '',
      type: (data['type'] as String?) ?? '판단 미스',
      tier: (data['tier'] as String?) ?? '언랭크',
      description: (data['description'] as String?) ?? '',
      partyAStatement: (data['partyAStatement'] as String?) ?? '',
      partyBStatement: (data['partyBStatement'] as String?) ?? '',
      issues: (data['issues'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      leftVotes: (data['leftVotes'] as num?)?.toInt() ?? 0,
      rightVotes: (data['rightVotes'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      status: (data['status'] as String?) ?? 'open',
      winner: data['winner'] as String?,
      createdAt: created,
      expiresAt: expires,
      videoUrl: data['videoUrl'] as String?,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      boostedUntil: boostedTs?.toDate(),
      reportedBy: (data['reportedBy'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
    );
  }
}

/// Firestore cases/{caseId}/votes/{uid} 집계용 투표 모델
class CaseVoteEntry {
  const CaseVoteEntry({
    required this.uid,
    required this.choice,
    required this.voterTier,
    required this.isHighTier,
  });

  final String uid;
  final String choice; // 'left' | 'right'
  final String voterTier;
  final bool isHighTier;

  factory CaseVoteEntry.fromDoc(DocumentSnapshot<JsonMap> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CaseVoteEntry(
      uid: (data['uid'] as String?) ?? doc.id,
      choice: (data['choice'] as String?) ?? 'left',
      voterTier: (data['voterTier'] as String?) ?? '미등록',
      isHighTier: (data['isHighTier'] as bool?) ?? false,
    );
  }
}

/// Firestore cases/{caseId}/comments/{commentId} 모델
class CaseComment {
  const CaseComment({
    required this.id,
    required this.authorUid,
    required this.authorNickname,
    required this.content,
    required this.side,
    required this.likedBy,
    required this.dislikedBy,
    required this.createdAt,
    this.parentId,
    this.reportedBy = const <String>[],
  });

  final String id;
  final String authorUid;
  final String authorNickname;
  final String content;
  final String side; // 'left'(신청인 과실) | 'right'(상대방 과실)
  final List<String> likedBy;
  final List<String> dislikedBy;
  final DateTime createdAt;
  final String? parentId;
  final List<String> reportedBy;

  int get likeCount => likedBy.length;
  int get dislikeCount => dislikedBy.length;
  bool get isHidden => reportedBy.length >= PolicyConfig.reportHideThreshold;

  bool isLikedBy(String? uid) => uid != null && likedBy.contains(uid);
  bool isDislikedBy(String? uid) => uid != null && dislikedBy.contains(uid);
  bool isReportedBy(String? uid) => uid != null && reportedBy.contains(uid);
  bool get isReply => parentId != null && parentId!.isNotEmpty;

  String get sideLabel => side == 'left' ? '신청인 과실' : '상대방 과실';

  factory CaseComment.fromDoc(DocumentSnapshot<JsonMap> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final ts = data['createdAt'] as Timestamp?;
    final rawParentId = (data['parentId'] as String?)?.trim();
    return CaseComment(
      id: doc.id,
      authorUid: (data['authorUid'] as String?) ?? '',
      authorNickname: (data['authorNickname'] as String?) ?? '익명 배심원',
      content: (data['content'] as String?) ?? '',
      side: (data['side'] as String?) ?? 'left',
      likedBy: (data['likedBy'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      dislikedBy: (data['dislikedBy'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      createdAt: ts?.toDate() ?? DateTime.now(),
      parentId: (rawParentId != null && rawParentId.isNotEmpty)
          ? rawParentId
          : null,
      reportedBy: (data['reportedBy'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
    );
  }
}

/// Firestore users/{uid}/myVotes/{caseId} 모델
class MyVoteRecord {
  const MyVoteRecord({
    required this.caseId,
    required this.caseTitle,
    required this.caseGame,
    required this.choice,
    required this.settled,
    required this.caseWinner,
    required this.votedAt,
  });

  final String caseId;
  final String caseTitle;
  final String caseGame;
  final String choice; // 'left' | 'right'
  final bool settled;
  final String? caseWinner;
  final DateTime votedAt;

  String get choiceLabel =>
      choice == 'left' ? 'Party A (신청인) 과실' : 'Party B (상대방) 과실';

  String get resultLabel {
    if (!settled) return '판정 진행 중';
    if (caseWinner == 'draw') return '치열한 논쟁(적중률 제외)';
    return choice == caseWinner ? '판정 적중 (+15 P)' : '판정 불일치';
  }

  factory MyVoteRecord.fromDoc(DocumentSnapshot<JsonMap> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final ts = data['votedAt'] as Timestamp?;
    return MyVoteRecord(
      caseId: (data['caseId'] as String?) ?? doc.id,
      caseTitle: (data['caseTitle'] as String?) ?? '사건 상세 보기',
      caseGame: (data['caseGame'] as String?) ?? '',
      choice: (data['choice'] as String?) ?? 'left',
      settled: (data['settled'] as bool?) ?? false,
      caseWinner: data['caseWinner'] as String?,
      votedAt: ts?.toDate() ?? DateTime.now(),
    );
  }
}

class CaseService {
  CaseService._();
  static final instance = CaseService._();

  static const List<String> reportReasons = [
    '욕설 · 비방 · 혐오 표현',
    '도배 · 광고 · 스팸',
    '허위 사실 · 조작된 영상',
    '개인정보 노출 · 저격 글',
    '기타 커뮤니티 정책 위반',
  ];

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<JsonMap> get _cases => _db.collection('cases');
  CollectionReference<JsonMap> get _reports => _db.collection('reports');

  String _determineWinner(CaseRecord current) {
    if (current.totalVotes < PolicyConfig.minVotesForValidCase) {
      return 'draw';
    }
    final leftRatio = current.leftVotes / current.totalVotes;
    final rightRatio = current.rightVotes / current.totalVotes;
    if (leftRatio >= PolicyConfig.decisiveThreshold) {
      return 'left';
    }
    if (rightRatio >= PolicyConfig.decisiveThreshold) {
      return 'right';
    }
    return 'draw';
  }

  /// 전체 사건 실시간 구독 (최신순)
  Stream<List<CaseRecord>> watchCases() {
    return _cases
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CaseRecord.fromDoc).toList());
  }

  /// 단일 사건 실시간 구독
  Stream<CaseRecord?> watchCase(String caseId) {
    return _cases.doc(caseId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CaseRecord.fromDoc(doc);
    });
  }

  /// 사건 투표 목록 실시간 구독 (티어별 집계용)
  Stream<List<CaseVoteEntry>> watchVotes(String caseId) {
    return _cases.doc(caseId).collection('votes').snapshots().map(
          (snap) => snap.docs.map(CaseVoteEntry.fromDoc).toList(),
        );
  }

  /// 내가 제보한 사건 실시간 구독
  Stream<List<CaseRecord>> watchMySubmittedCases(String uid) {
    return _cases.where('authorUid', isEqualTo: uid).snapshots().map((snap) {
      final list = snap.docs.map(CaseRecord.fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// 내가 판정(투표)에 참여한 사건 실시간 구독
  Stream<List<MyVoteRecord>> watchMyVotedCases(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('myVotes')
        .orderBy('votedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(MyVoteRecord.fromDoc).toList());
  }

  /// 특정 사건에 대한 내 투표 기록 실시간 구독
  Stream<String?> watchMyVote(String caseId, String uid) {
    return _cases.doc(caseId).collection('votes').doc(uid).snapshots().map(
          (doc) => doc.exists ? (doc.data()?['choice'] as String?) : null,
        );
  }

  /// 새 사건 등록 + 작성자 보상(+30 XP, +10 P) 지급
  Future<String> createCase({
    required String authorUid,
    required String authorNickname,
    required String game,
    required String title,
    required String type,
    required String tier,
    required String description,
    required String partyAStatement,
    required String partyBStatement,
    required List<String> issues,
    required Duration duration,
    String? videoUrl,
    String? thumbnailUrl,
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(duration);

    final docRef = await _cases.add({
      'authorUid': authorUid,
      'authorNickname': authorNickname,
      'game': game,
      'title': title.trim(),
      'type': type,
      'tier': tier,
      'description': description.trim(),
      'partyAStatement': partyAStatement.trim(),
      'partyBStatement': partyBStatement.trim(),
      'issues': issues,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'boostedUntil': null,
      'reportedBy': <String>[],
      'leftVotes': 0,
      'rightVotes': 0,
      'commentCount': 0,
      'status': 'open',
      'winner': null,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    });

    await UserService.instance.addReward(
      uid: authorUid,
      xpDelta: PolicyConfig.xpCreateCase,
      pointsDelta: PolicyConfig.pointsCreateCase,
    );

    return docRef.id;
  }

  /// 부적절 사건 신고 (중복 신고 방지 + 누적 3회 이상 자동 숨김)
  Future<void> reportCase({
    required String caseId,
    required String uid,
    required String reason,
  }) async {
    final caseRef = _cases.doc(caseId);
    final reportRef = _reports.doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(caseRef);
      if (!snap.exists) {
        throw StateError('존재하지 않는 사건입니다.');
      }
      final reportedBy = (snap.data()?['reportedBy'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
      if (reportedBy.contains(uid)) {
        throw StateError('이미 신고한 사건입니다.');
      }

      reportedBy.add(uid);
      tx.update(caseRef, {'reportedBy': reportedBy});
      tx.set(reportRef, {
        'targetType': 'case',
        'caseId': caseId,
        'reporterUid': uid,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 부적절 댓글/대댓글 신고 (중복 신고 방지 + 누적 3회 이상 자동 숨김)
  Future<void> reportComment({
    required String caseId,
    required String commentId,
    required String uid,
    required String reason,
  }) async {
    final commentRef =
        _cases.doc(caseId).collection('comments').doc(commentId);
    final reportRef = _reports.doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(commentRef);
      if (!snap.exists) {
        throw StateError('존재하지 않는 댓글입니다.');
      }
      final reportedBy = (snap.data()?['reportedBy'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
      if (reportedBy.contains(uid)) {
        throw StateError('이미 신고한 댓글입니다.');
      }

      reportedBy.add(uid);
      tx.update(commentRef, {'reportedBy': reportedBy});
      tx.set(reportRef, {
        'targetType': 'comment',
        'caseId': caseId,
        'commentId': commentId,
        'reporterUid': uid,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 긴급 재판 부스트권 1장을 소모해 사건을 24시간 동안 홈 최상단 우선 노출
  Future<void> boostCase({
    required String caseId,
    required String uid,
    Duration duration = const Duration(hours: 24),
  }) async {
    final caseRef = _cases.doc(caseId);
    final userRef = _db.collection('users').doc(uid);

    await _db.runTransaction((tx) async {
      final caseSnap = await tx.get(caseRef);
      if (!caseSnap.exists) {
        throw StateError('존재하지 않는 사건입니다.');
      }

      final record = CaseRecord.fromDoc(caseSnap);
      if (record.isClosed) {
        throw StateError('이미 마감된 사건에는 부스트권을 사용할 수 없습니다.');
      }
      if (record.authorUid != uid) {
        throw StateError('본인이 제보한 사건에만 부스트권을 사용할 수 있습니다.');
      }

      final userSnap = await tx.get(userRef);
      final tickets = (userSnap.data()?['boostTickets'] as num?)?.toInt() ?? 0;
      if (tickets < 1) {
        throw StateError('보유한 긴급 재판 부스트권이 없습니다. 포인트 상점에서 구매해 주세요.');
      }

      final baseTime = record.isBoosted ? record.boostedUntil! : DateTime.now();
      final nextUntil = baseTime.add(duration);

      tx.set(
        userRef,
        {'boostTickets': tickets - 1},
        SetOptions(merge: true),
      );
      tx.update(caseRef, {
        'boostedUntil': Timestamp.fromDate(nextUntil),
      });
    });
  }

  /// 본인 사건 삭제 (하위 votes, comments 정리 포함)
  Future<void> deleteCase(String caseId) async {
    final caseRef = _cases.doc(caseId);
    final votesSnap = await caseRef.collection('votes').get();
    final commentsSnap = await caseRef.collection('comments').get();

    final refsToDelete = <DocumentReference>[
      ...votesSnap.docs.map((d) => d.reference),
      ...commentsSnap.docs.map((d) => d.reference),
      caseRef,
    ];

    const chunkSize = 400;
    for (var i = 0; i < refsToDelete.length; i += chunkSize) {
      final batch = _db.batch();
      final end = (i + chunkSize < refsToDelete.length)
          ? i + chunkSize
          : refsToDelete.length;
      for (var j = i; j < end; j++) {
        batch.delete(refsToDelete[j]);
      }
      await batch.commit();
    }
  }

  /// 블라인드 투표 제출 (1인 1표 트랜잭션 + 배심원 티어 기록 + 참여 보상 +10 XP, +5 P)
  Future<void> submitVote({
    required String caseId,
    required String uid,
    required String choice,
  }) async {
    if (choice != 'left' && choice != 'right') {
      throw ArgumentError('유효하지 않은 투표 선택입니다.');
    }

    final profile = await UserService.instance.getUser(uid);
    final caseRef = _cases.doc(caseId);
    final voteRef = caseRef.collection('votes').doc(uid);
    final myVoteRef =
        _db.collection('users').doc(uid).collection('myVotes').doc(caseId);

    await _db.runTransaction((tx) async {
      final caseSnap = await tx.get(caseRef);
      if (!caseSnap.exists) {
        throw StateError('존재하지 않는 사건입니다.');
      }

      final record = CaseRecord.fromDoc(caseSnap);
      if (record.isClosed) {
        throw StateError('이미 투표가 마감된 사건입니다.');
      }

      final existingVote = await tx.get(voteRef);
      if (existingVote.exists) {
        throw StateError('이미 이 사건에 판정을 완료했습니다.');
      }

      final voterTier = profile?.tierForGame(record.game) ?? '미등록';
      final isHighTier = profile?.isHighTierForGame(record.game) ?? false;

      tx.set(voteRef, {
        'uid': uid,
        'choice': choice,
        'voterTier': voterTier,
        'isHighTier': isHighTier,
        'votedAt': FieldValue.serverTimestamp(),
      });

      tx.set(myVoteRef, {
        'caseId': caseId,
        'caseTitle': record.title,
        'caseGame': record.game,
        'choice': choice,
        'settled': false,
        'votedAt': FieldValue.serverTimestamp(),
      });

      tx.update(caseRef, {
        choice == 'left' ? 'leftVotes' : 'rightVotes': FieldValue.increment(1),
      });
    });

    await UserService.instance.addReward(
      uid: uid,
      xpDelta: PolicyConfig.xpVote,
      pointsDelta: PolicyConfig.pointsVote,
      totalVotesDelta: 1,
    );
  }

  /// 사건 토론 댓글 실시간 구독 (최신순)
  Stream<List<CaseComment>> watchComments(String caseId) {
    return _cases
        .doc(caseId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CaseComment.fromDoc).toList());
  }

  /// 판결 근거 댓글 또는 대댓글 작성 (+15 XP, +5 P)
  Future<void> addComment({
    required String caseId,
    required String authorUid,
    required String authorNickname,
    required String content,
    required String side,
    String? parentId,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    final caseRef = _cases.doc(caseId);
    final commentRef = caseRef.collection('comments').doc();

    final batch = _db.batch();
    batch.set(commentRef, {
      'authorUid': authorUid,
      'authorNickname': authorNickname,
      'content': trimmed,
      'side': side,
      'parentId': parentId,
      'likedBy': <String>[],
      'dislikedBy': <String>[],
      'reportedBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(caseRef, {
      'commentCount': FieldValue.increment(1),
    });
    await batch.commit();

    await UserService.instance.addReward(
      uid: authorUid,
      xpDelta: PolicyConfig.xpComment,
      pointsDelta: PolicyConfig.pointsComment,
    );
  }

  /// 본인 댓글 삭제 (부모 댓글이면 하위 대댓글도 함께 정리 + 댓글 카운트 차감)
  Future<void> deleteComment({
    required String caseId,
    required String commentId,
  }) async {
    final caseRef = _cases.doc(caseId);
    final commentRef = caseRef.collection('comments').doc(commentId);
    final repliesSnap = await caseRef
        .collection('comments')
        .where('parentId', isEqualTo: commentId)
        .get();

    final batch = _db.batch();
    batch.delete(commentRef);
    for (final reply in repliesSnap.docs) {
      batch.delete(reply.reference);
    }

    final deleteCount = 1 + repliesSnap.docs.length;
    final caseSnap = await caseRef.get();
    if (caseSnap.exists) {
      final currentCount =
          (caseSnap.data()?['commentCount'] as num?)?.toInt() ?? 0;
      final nextCount =
          currentCount > deleteCount ? currentCount - deleteCount : 0;
      batch.update(caseRef, {'commentCount': nextCount});
    }

    await batch.commit();
  }

  /// 댓글 공감 토글 (공감 누르면 기존 비공감 자동 해제)
  Future<void> toggleCommentLike({
    required String caseId,
    required String commentId,
    required String uid,
    required bool currentlyLiked,
  }) async {
    final commentRef =
        _cases.doc(caseId).collection('comments').doc(commentId);
    await commentRef.update({
      'likedBy': currentlyLiked
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
      if (!currentlyLiked) 'dislikedBy': FieldValue.arrayRemove([uid]),
    });
  }

  /// 댓글 비공감(싫어요) 토글 (비공감 누르면 기존 공감 자동 해제)
  Future<void> toggleCommentDislike({
    required String caseId,
    required String commentId,
    required String uid,
    required bool currentlyDisliked,
  }) async {
    final commentRef =
        _cases.doc(caseId).collection('comments').doc(commentId);
    await commentRef.update({
      'dislikedBy': currentlyDisliked
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
      if (!currentlyDisliked) 'likedBy': FieldValue.arrayRemove([uid]),
    });
  }

  /// 작성자 즉시 마감 (시연 및 조기 종결용)
  Future<CaseRecord?> closeCaseNow(String caseId) async {
    final caseRef = _cases.doc(caseId);
    await _db.runTransaction((tx) async {
      final fresh = await tx.get(caseRef);
      if (!fresh.exists) return;

      final current = CaseRecord.fromDoc(fresh);
      if (current.status == 'closed') return;

      final winner = _determineWinner(current);
      tx.update(caseRef, {
        'status': 'closed',
        'winner': winner,
        'expiresAt': Timestamp.fromDate(DateTime.now()),
        'closedAt': FieldValue.serverTimestamp(),
      });
    });

    final updated = await caseRef.get();
    return updated.exists ? CaseRecord.fromDoc(updated) : null;
  }

  /// 마감 시간이 지난 사건을 closed 상태로 확정하고 60:40 규칙으로 승자 판정
  Future<CaseRecord?> closeIfExpired(String caseId) async {
    final caseRef = _cases.doc(caseId);
    final snap = await caseRef.get();
    if (!snap.exists) return null;

    final record = CaseRecord.fromDoc(snap);
    if (record.status == 'closed' || !record.isExpired) {
      return record;
    }

    await _db.runTransaction((tx) async {
      final fresh = await tx.get(caseRef);
      if (!fresh.exists) return;

      final current = CaseRecord.fromDoc(fresh);
      if (current.status == 'closed' || !current.isExpired) return;

      final winner = _determineWinner(current);
      tx.update(caseRef, {
        'status': 'closed',
        'winner': winner,
        'closedAt': FieldValue.serverTimestamp(),
      });
    });

    final updated = await caseRef.get();
    return updated.exists ? CaseRecord.fromDoc(updated) : null;
  }

  /// 내가 투표한 사건 중 마감된 건을 자동 정산해 적중률·연속 적중 스트릭·보너스 반영
  Future<({int settledCount, int hitCount})> settleMyVotes(String uid) async {
    final pendingSnap = await _db
        .collection('users')
        .doc(uid)
        .collection('myVotes')
        .where('settled', isEqualTo: false)
        .get();

    var settledCount = 0;
    var hitCount = 0;

    for (final voteDoc in pendingSnap.docs) {
      final caseId = voteDoc.id;
      final choice = voteDoc.data()['choice'] as String?;
      if (choice == null) continue;

      final closedCase = await closeIfExpired(caseId);
      if (closedCase == null || closedCase.status != 'closed') continue;

      final didSettle = await _db.runTransaction<bool>((tx) async {
        final freshVote = await tx.get(voteDoc.reference);
        if (!freshVote.exists ||
            (freshVote.data()?['settled'] as bool?) == true) {
          return false;
        }
        tx.update(voteDoc.reference, {
          'settled': true,
          'caseWinner': closedCase.winner,
          'settledAt': FieldValue.serverTimestamp(),
        });
        return true;
      });

      if (!didSettle) continue;
      settledCount++;

      if (closedCase.winner == 'left' || closedCase.winner == 'right') {
        final isHit = choice == closedCase.winner;
        if (isHit) hitCount++;

        await UserService.instance.addReward(
          uid: uid,
          validJudgedDelta: 1,
          hitDelta: isHit ? 1 : 0,
          xpDelta: isHit ? PolicyConfig.xpHitBonus : 0,
          pointsDelta: isHit ? PolicyConfig.pointsHitBonus : 0,
          streakResult: isHit,
        );
      }
    }

    return (settledCount: settledCount, hitCount: hitCount);
  }
}