import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import 'home_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    this.initialGames,
    this.fromProfile = false,
  });

  final List<String>? initialGames;
  final bool fromProfile;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final Set<String> selected;
  bool _isSaving = false;

  final games = const [
    (
      '리그 오브 레전드',
      'assets/images/lol.png',
      Icons.shield_outlined,
      Color(0xFFEAF0FF),
    ),
    (
      '발로란트',
      'assets/images/valorant.png',
      Icons.gps_fixed,
      Color(0xFFFFE8E9),
    ),
    (
      '오버워치 2',
      'assets/images/overwatch.png',
      Icons.sports_esports,
      Color(0xFFFFF0D9),
    ),
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialGames;
    selected = (initial != null && initial.isNotEmpty)
        ? initial.toSet()
        : <String>{'리그 오브 레전드'};
  }

  Future<void> _handleSave() async {
    if (_isSaving || selected.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final uid = AuthService.instance.currentUser?.uid;
      if (uid != null) {
        await UserService.instance.saveFavoriteGames(uid, selected.toList());
      }
      if (!mounted) return;

      if (widget.fromProfile) {
        Navigator.pop(context);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
          (_) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('관심 종목 저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('관심 종목 선택')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '주로 플레이하는 게임을\n선택해 주세요',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  height: 1.28,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '최대 3개까지 선택할 수 있어요.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              ...games.map((g) {
                final pick = selected.contains(g.$1);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _isSaving
                        ? null
                        : () => setState(() {
                              if (pick) {
                                selected.remove(g.$1);
                              } else if (selected.length < 3) {
                                selected.add(g.$1);
                              }
                            }),
                    child: Container(
                      height: 92,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: pick ? AppColors.red : AppColors.line,
                          width: pick ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: g.$4,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.asset(
                                g.$2,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  g.$3,
                                  color: AppColors.ink,
                                  size: 30,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              g.$1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (pick)
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.red,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              FilledButton(
                onPressed:
                    (selected.isEmpty || _isSaving) ? null : _handleSave,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.red,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(_isSaving ? '저장 중...' : '선택 완료'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}