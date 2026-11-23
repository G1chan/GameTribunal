import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// 이메일 회원가입 (닉네임 함께 저장)
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(nickname.trim());
    await credential.user?.reload();
    return credential;
  }

  /// 이메일 로그인
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// 비밀번호 재설정 메일 전송
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Google 로그인 (웹: 팝업 / 모바일: 네이티브)
  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      provider.setCustomParameters({'prompt': 'select_account'});
      return await _auth.signInWithPopup(provider);
    }

    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return await _auth.signInWithCredential(credential);
  }

  /// Apple 로그인 (추후 Apple 개발자 계정 연동 시 동작)
  Future<UserCredential?> signInWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
      accessToken: appleCredential.authorizationCode,
    );

    final userCredential = await _auth.signInWithCredential(oauthCredential);

    final fullName = [
      appleCredential.familyName,
      appleCredential.givenName,
    ].where((e) => e != null && e.isNotEmpty).join();

    if (fullName.isNotEmpty && userCredential.user?.displayName == null) {
      await userCredential.user?.updateDisplayName(fullName);
    }

    return userCredential;
  }

  /// 로그아웃
  Future<void> signOut() async {
    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }
    await _auth.signOut();
  }

  /// Firebase 에러 코드를 한국어 안내 문구로 변환
  String getErrorMessage(FirebaseAuthException e) {
    return switch (e.code) {
      'invalid-email' => '이메일 형식이 올바르지 않습니다.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        '이메일 또는 비밀번호가 일치하지 않습니다.',
      'email-already-in-use' => '이미 가입된 이메일 주소입니다.',
      'weak-password' => '비밀번호는 6자 이상으로 설정해 주세요.',
      'too-many-requests' => '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.',
      'network-request-failed' => '네트워크 연결을 확인해 주세요.',
      _ => e.message ?? '인증 중 오류가 발생했습니다. (${e.code})',
    };
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}