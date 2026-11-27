import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Firebase Cloud Messaging(FCM) 권한 요청, FID 등록 동기화 및 포그라운드 수신 관리
class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  static const _webVapidKey = String.fromEnvironment('FCM_VAPID_KEY');

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ValueNotifier<bool> isPushAuthorized = ValueNotifier<bool>(false);

  StreamSubscription<String>? _registeredSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  String? _boundUid;

  /// 포그라운드 푸시 수신 시 콜백 연결 (1회 바인딩)
  void bindForegroundHandler(
    void Function(String title, String body) onMessage,
  ) {
    _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? '겜문철 알림';
      final body = message.notification?.body ?? '';
      if (body.isNotEmpty || title.isNotEmpty) {
        onMessage(title, body);
      }
    });
  }

  /// 이미 브라우저/기기 알림 권한이 허용된 상태라면 조용히 등록 동기화
  Future<void> syncIfAlreadyAuthorized(String uid) async {
    if (_boundUid == uid && isPushAuthorized.value) return;
    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      isPushAuthorized.value = allowed;
      if (allowed) {
        await _registerDevice(uid);
      }
    } catch (e) {
      debugPrint('FCM 권한 상태 확인 건너뜀: $e');
    }
  }

  /// 사용자 클릭으로 푸시 알림 권한 요청 및 FCM 등록
  Future<({bool granted, String message})> requestAndRegister(String uid) async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      isPushAuthorized.value = granted;

      if (!granted) {
        return (
          granted: false,
          message: '브라우저 설정에서 알림 권한을 허용해 주세요.',
        );
      }

      if (kIsWeb && _webVapidKey.isEmpty) {
        return (
          granted: true,
          message: '알림 권한 허용 완료! 웹 푸시 전송은 배포 시 FCM_VAPID_KEY 연결 후 활성화됩니다.',
        );
      }

      await _registerDevice(uid);
      return (
        granted: true,
        message: '푸시 알림이 활성화되었습니다!',
      );
    } catch (e) {
      debugPrint('FCM 등록 실패: $e');
      return (
        granted: false,
        message: '푸시 알림 설정 중 오류가 발생했습니다: $e',
      );
    }
  }

  Future<void> _registerDevice(String uid) async {
    if (kIsWeb && _webVapidKey.isEmpty) return;

    final messaging = FirebaseMessaging.instance;

    // 공식 가이드에 따라 register() 호출 전에 onRegistered 스트림을 먼저 구독
    if (_boundUid != uid) {
      _boundUid = uid;
      await _registeredSub?.cancel();
      _registeredSub = messaging.onRegistered.listen(
        (String installationId) {
          if (installationId.isEmpty) return;
          unawaited(
            _db.collection('users').doc(uid).set(
              {
                'fcmTokens': FieldValue.arrayUnion([installationId]),
              },
              SetOptions(merge: true),
            ),
          );
        },
        onError: (Object err) {
          debugPrint('FCM 등록 스트림 오류: $err');
        },
      );
    }

    await messaging.register(
      vapidKey: kIsWeb ? _webVapidKey : null,
    );
  }
}