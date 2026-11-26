import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/moderation_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/moderation_notice.dart';
import 'login.dart';
import 'shop_page.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key, required this.initialNickname});
  final String initialNickname;

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  late final TextEditingController _nicknameController;
  bool _isSaving = false;
  bool _isSendingReset = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.initialNickname);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _saveNickname(UserProfile? profile) async {
    if (_isSaving) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final tickets = profile?.nicknameTickets ?? 0;
    if (tickets < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('닉네임 변경권이 없습니다. 포인트 상점에서 구매해 주세요.'),
        ),
      );
      return;
    }

    final nextName = _nicknameController.text.trim();
    if (nextName.length < 2 || nextName.length > 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임은 2자 이상 16자 이하로 입력해 주세요.')),
      );
      return;
    }

    if (profile != null && nextName == profile.nickname) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 닉네임과 동일합니다.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final modCheck = await ModerationService.instance.check(
        nextName,
        context: ModerationContext.caseTitle,
      );
      if (!mounted) return;
      final passed = await handleModeration(context, modCheck);
      if (!mounted || !passed) return;

      await UserService.instance.updateNickname(
        user.uid,
        nextName,
        requireTicket: true,
      );
      await user.updateDisplayName(nextName);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임 변경권 1장을 사용해 닉네임이 변경되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('닉네임 변경 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_isSendingReset) return;
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('등록된 이메일 정보가 없습니다.')),
      );
      return;
    }

    setState(() => _isSendingReset = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$email 주소로 비밀번호 재설정 메일을 보냈습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('재설정 메일 발송 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (_isDeleting) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('정말 회원 탈퇴할까요?'),
        content: const Text(
          '탈퇴 시 보유 포인트, 레벨, 적중률 및 활동 내역이 모두 삭제되며 복구할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await UserService.instance.deleteUserDocument(user.uid);
      await user.delete();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.code == 'requires-recent-login'
          ? '보안을 위해 다시 로그인한 직후 회원 탈퇴를 진행해 주세요.'
          : '회원 탈퇴 실패: ${e.message ?? e.code}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원 탈퇴 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '이메일 정보 없음';
    final isPasswordUser =
        user?.providerData.any((p) => p.providerId == 'password') ?? false;

    return Scaffold(
      appBar: const AppHeader(title: '개인정보 및 계정 설정', back: true),
      body: StreamBuilder<UserProfile?>(
        stream: user != null
            ? UserService.instance.watchUser(user.uid)
            : const Stream<UserProfile?>.empty(),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final tickets = profile?.nicknameTickets ?? 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '계정 정보',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.redPale,
                    child: Icon(
                      Icons.mail_outline_rounded,
                      color: AppColors.red,
                    ),
                  ),
                  title: const Text(
                    '로그인 이메일',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  subtitle: Text(email),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '배심원 닉네임 변경',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: tickets > 0 ? AppColors.redPale : AppColors.line,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '변경권 $tickets장 보유',
                      style: TextStyle(
                        color: tickets > 0 ? AppColors.red : AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nicknameController,
                maxLength: 16,
                decoration: const InputDecoration(
                  hintText: '새 닉네임을 입력해 주세요 (2~16자)',
                ),
              ),
              const SizedBox(height: 8),
              if (tickets > 0)
                FilledButton(
                  onPressed: _isSaving ? null : () => _saveNickname(profile),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.red,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    _isSaving ? '변경 중...' : '닉네임 변경권 1장 사용하여 저장',
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ShopPage(initialTab: 0),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: AppColors.red),
                  ),
                  icon: const Icon(Icons.storefront_rounded, size: 18),
                  label: const Text('포인트 상점에서 닉네임 변경권 구매하기 (30 P)'),
                ),
              const SizedBox(height: 24),
              const Text(
                '보안 및 계정 관리',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (isPasswordUser)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.lock_reset_rounded),
                    title: const Text('비밀번호 재설정 메일 보내기'),
                    subtitle: Text('$email 주소로 재설정 링크 발송'),
                    trailing: _isSendingReset
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _isSendingReset ? null : _sendPasswordReset,
                  ),
                )
              else
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.verified_user_outlined),
                    title: Text('소셜 계정으로 로그인됨'),
                    subtitle: Text('비밀번호는 연결된 구글/애플 계정에서 관리됩니다.'),
                  ),
                ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.person_remove_outlined,
                    color: AppColors.red,
                  ),
                  title: const Text(
                    '회원 탈퇴',
                    style: TextStyle(
                      color: AppColors.red,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: const Text('계정과 활동 기록을 영구적으로 삭제합니다.'),
                  trailing: _isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right, color: AppColors.red),
                  onTap: _isDeleting ? null : _deleteAccount,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}