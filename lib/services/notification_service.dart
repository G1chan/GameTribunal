import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'user_service.dart';

/// 개인 활동 인앱 알림 모델 (users/{uid}/notifications/{id})
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.caseId,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.actorNickname,
  });

  final String id;
  final String type; // 'reply' | 'comment' | 'closed'
  final String caseId;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final String? actorNickname;

  String get badgeLabel => switch (type) {
        'reply' => '대댓글',
        'comment' => '새 의견',
        'closed' => '판정 종결',
        _ => '알림',
      };

  factory AppNotification.fromDoc(DocumentSnapshot<JsonMap> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final ts = data['createdAt'] as Timestamp?;
    return AppNotification(
      id: doc.id,
      type: (data['type'] as String?) ?? 'notice',
      caseId: (data['caseId'] as String?) ?? '',
      title: (data['title'] as String?) ?? '새 알림',
      body: (data['body'] as String?) ?? '',
      read: (data['read'] as bool?) ?? false,
      createdAt: ts?.toDate() ?? DateTime.now(),
      actorNickname: data['actorNickname'] as String?,
    );
  }
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<JsonMap> _userNotifications(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  /// 내 활동 알림 실시간 구독 (최신 30건)
  Stream<List<AppNotification>> watchMyNotifications(String uid) {
    return _userNotifications(uid)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs.map(AppNotification.fromDoc).toList());
  }

  /// 특정 유저에게 인앱 알림 전송 (본인에게는 전송하지 않음)
  Future<void> sendNotification({
    required String recipientUid,
    required String actorUid,
    required String type,
    required String caseId,
    required String title,
    required String body,
    String? actorNickname,
  }) async {
    if (recipientUid.isEmpty || recipientUid == actorUid) return;
    try {
      await _userNotifications(recipientUid).add({
        'type': type,
        'caseId': caseId,
        'title': title,
        'body': body,
        'actorNickname': actorNickname,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('인앱 알림 전송 건너뜀: $e');
    }
  }

  /// 안 읽은 내 활동 알림 전체 읽음 처리
  Future<void> markAllRead(String uid) async {
    try {
      final unreadSnap = await _userNotifications(uid)
          .where('read', isEqualTo: false)
          .get();
      if (unreadSnap.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in unreadSnap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('알림 읽음 처리 건너뜀: $e');
    }
  }
}