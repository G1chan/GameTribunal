import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../services/ai_moderation_engine.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/app_header.dart';
import 'login.dart';
import 'my_cases_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool push = true;
  bool marketing = false;
  bool _isLoggingOut = false;

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await AuthService.instance.signOut();
      appStore.user.nickname = '소환사의 판결';
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그아웃 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = AuthService.instance.currentUser;
    final displayName = firebaseUser?.displayName?.trim();
    final nickname = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : appStore.user.nickname;

    return Scaffold(
      appBar: const AppHeader(title: '프로필 & 설정'),
      bottomNavigationBar: const AppBottomNavigation(index: 4),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 31,
                  backgroundColor: AppColors.redPale,
                  child: Icon(Icons.person, color: AppColors.red, size: 34),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nickname,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        firebaseUser?.email ?? 'Lv.12 · 신뢰 배심원',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '판정 적중률 91.2%  ·  전체 142위',
                        style: TextStyle(
                          color: AppColors.red,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _InfoBox('보유 포인트', '${appStore.user.points} P')),
              const SizedBox(width: 8),
              const Expanded(child: _InfoBox('활동 배지', '7개')),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '연결된 게임 계정',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(child: Icon(Icons.shield_outlined)),
                  title: Text('Hide on Bush#KR1'),
                  subtitle: Text('리그 오브 레전드 · 다이아몬드'),
                  trailing: Icon(Icons.chevron_right),
                ),
                Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(child: Icon(Icons.gps_fixed)),
                  title: Text('Doomfist#1234'),
                  subtitle: Text('발로란트 · 플래티넘'),
                  trailing: Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '알림 및 개인정보',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('판정 알림'),
            subtitle: const Text('참여 중인 사건의 진행 상황'),
            value: push,
            activeThumbColor: AppColors.red,
            onChanged: (v) => setState(() => push = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('마케팅 알림'),
            value: marketing,
            activeThumbColor: AppColors.red,
            onChanged: (v) => setState(() => marketing = v),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.assignment_outlined),
            title: const Text('내 사건 및 활동 내역'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyCasesPage()),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.psychology_outlined, color: AppColors.primary),
            title: const Text('AI 모더레이션 모델 다운로드'),
            subtitle: const Text('Chrome: Gemma 4 E2B 웹 모델 · 약 2GB'),
            trailing: const Icon(Icons.download_rounded),
            onTap: () async {
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('AI 모델 다운로드를 시작합니다. 완료까지 기다려 주세요.'),
                  ),
                );
                await AiModerationEngine.instance.downloadAndActivate();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Gemma AI 모더레이션이 활성화되었습니다.'),
                  ),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('AI 모델 준비 실패: $error')),
                );
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline),
            title: const Text('개인정보 및 계정 설정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),
          TextButton.icon(
            onPressed: _isLoggingOut ? null : _handleLogout,
            icon: const Icon(Icons.logout, color: AppColors.red),
            label: Text(
              _isLoggingOut ? '로그아웃 중...' : '로그아웃',
              style: const TextStyle(
                color: AppColors.red,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.redPale,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.red,
              ),
            ),
          ],
        ),
      );
}