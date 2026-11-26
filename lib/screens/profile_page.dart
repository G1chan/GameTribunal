import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../services/ai_moderation_engine.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/video_upload_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/app_header.dart';
import '../widgets/user_avatar.dart';
import 'account_settings_page.dart';
import 'login.dart';
import 'my_cases_page.dart';
import 'onboarding_page.dart';
import 'shop_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _supportedGames = ['리그 오브 레전드', '발로란트', '오버워치 2'];

  bool marketing = false;
  bool _isLoggingOut = false;
  bool _isUploadingPhoto = false;

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await AuthService.instance.signOut();
      appStore.user.nickname = '소환사의 판결';
      appStore.user.points = 0;
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

  Future<void> _changeProfilePhoto(UserProfile profile) async {
    if (_isUploadingPhoto) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '프로필 사진 설정',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.red,
              ),
              title: const Text('사진 선택하여 변경'),
              subtitle: const Text('JPG, PNG, WebP · 최대 10MB'),
              onTap: () => Navigator.pop(sheetCtx, 'pick'),
            ),
            if (profile.photoUrl != null && profile.photoUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(
                  Icons.restore_rounded,
                  color: AppColors.muted,
                ),
                title: const Text('기본 프로필 이미지로 되돌리기'),
                onTap: () => Navigator.pop(sheetCtx, 'reset'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    if (action == 'reset') {
      setState(() => _isUploadingPhoto = true);
      try {
        await UserService.instance.updatePhotoUrl(profile.uid, null);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기본 프로필 이미지로 변경되었습니다.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('프로필 사진 초기화 실패: $e')),
        );
      } finally {
        if (mounted) setState(() => _isUploadingPhoto = false);
      }
      return;
    }

    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty || !mounted) return;

      setState(() => _isUploadingPhoto = true);
      final uploadedUrl =
          await VideoUploadService.instance.uploadProfileImage(files.first);
      await UserService.instance.updatePhotoUrl(profile.uid, uploadedUrl);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 사진이 변경되었습니다!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('프로필 사진 변경 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  ({String asset, IconData icon}) _gameVisual(String gameName) {
    return switch (gameName) {
      '리그 오브 레전드' => (
          asset: 'assets/images/lol.png',
          icon: Icons.shield_outlined,
        ),
      '발로란트' => (
          asset: 'assets/images/valorant.png',
          icon: Icons.gps_fixed,
        ),
      '오버워치 2' => (
          asset: 'assets/images/overwatch.png',
          icon: Icons.sports_esports,
        ),
      _ => (
          asset: '',
          icon: Icons.sports_esports_outlined,
        ),
    };
  }

  Future<void> _openGameAccountDialog({
    required String uid,
    required String gameName,
    GameAccountInfo? current,
  }) async {
    final idController = TextEditingController(text: current?.gameId ?? '');
    var selectedTier = current?.tier ?? '골드';
    if (!GameAccountInfo.tierOptions.contains(selectedTier)) {
      selectedTier = '골드';
    }

    final action = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('$gameName 계정 설정'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: idController,
                    decoration: const InputDecoration(
                      labelText: '인게임 닉네임 (예: 겜문철#KR1)',
                      hintText: '닉네임#태그',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTier,
                    decoration: const InputDecoration(labelText: '현재 티어'),
                    items: GameAccountInfo.tierOptions
                        .map(
                          (t) => DropdownMenuItem(value: t, child: Text(t)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => selectedTier = v);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '플래티넘 이상 티어는 판정 리포트의 상위 티어 배심원 분포에 반영됩니다.',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
              actions: [
                if (current != null)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx, 'remove'),
                    child: const Text(
                      '연동 해제',
                      style: TextStyle(color: AppColors.red),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, 'cancel'),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogCtx, 'save'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.red),
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );

    final enteredId = idController.text.trim();
    idController.dispose();

    if (!mounted || action == null || action == 'cancel') return;

    try {
      if (action == 'remove') {
        await UserService.instance.removeGameAccount(uid: uid, game: gameName);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$gameName 계정 연동이 해제되었습니다.')),
        );
        return;
      }

      if (enteredId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인게임 닉네임을 입력해 주세요.')),
        );
        return;
      }

      await UserService.instance.saveGameAccount(
        uid: uid,
        game: gameName,
        gameId: enteredId,
        tier: selectedTier,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$gameName ($selectedTier) 정보가 저장되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('계정 정보 저장 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = AuthService.instance.currentUser;
    if (firebaseUser == null) {
      return Scaffold(
        appBar: const AppHeader(title: '프로필 & 설정'),
        bottomNavigationBar: const AppBottomNavigation(index: 4),
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (_) => false,
            ),
            child: const Text('로그인하러 가기'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const AppHeader(title: '프로필 & 설정'),
      bottomNavigationBar: const AppBottomNavigation(index: 4),
      body: StreamBuilder<UserProfile?>(
        stream: UserService.instance.watchUser(firebaseUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = snapshot.data ??
              UserProfile(
                uid: firebaseUser.uid,
                nickname: firebaseUser.displayName ?? appStore.user.nickname,
                email: firebaseUser.email ?? '',
                favoriteGames: const <String>[],
                xp: 0,
                level: 1,
                points: 0,
                totalVotes: 0,
                validJudgedCount: 0,
                hitCount: 0,
                onboardingCompleted: false,
              );

          final progress = profile.levelProgress;
          final xpRatio = progress.nextLevelXp > 0
              ? (progress.currentXp / progress.nextLevelXp).clamp(0.0, 1.0)
              : 0.0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _isUploadingPhoto
                              ? null
                              : () => _changeProfilePhoto(profile),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: LevelUserAvatar(
                                  level: profile.level,
                                  photoUrl: profile.photoUrl,
                                  radius: 31,
                                  showLevelPill: true,
                                ),
                              ),
                              if (_isUploadingPhoto)
                                Positioned.fill(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black45,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Positioned(
                                  right: -2,
                                  bottom: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: AppColors.field,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    profile.nickname,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  UserTitleBadge(
                                    titleItem: profile.equippedTitleItem,
                                    compact: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Lv.${profile.level} ·${profile.title}',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (profile.email.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  profile.email,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                children: [
                                  Text(
                                    '판정 적중률 ${profile.accuracyText}',
                                    style: const TextStyle(
                                      color: AppColors.red,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Text(
                                    '·',
                                    style: TextStyle(
                                      color: AppColors.red,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  _RankText(
                                    earnedPoints: profile.totalEarnedPoints,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '다음 레벨까지 XP (레벨업 시 테두리 자동 진화)',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '${progress.currentXp} /${progress.nextLevelXp} XP',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: xpRatio,
                        minHeight: 7,
                        backgroundColor: AppColors.redPale,
                        color: AppColors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _InfoBox('보유 포인트', '${profile.points} P'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InfoBox('참여한 판결', '${profile.totalVotes}건'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ShopPage(initialTab: 0),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.red,
                        minimumSize: const Size.fromHeight(46),
                      ),
                      icon: const Icon(Icons.storefront_rounded, size: 19),
                      label: const Text('포인트 상점'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ShopPage(initialTab: 1),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        foregroundColor: AppColors.ink,
                      ),
                      icon: const Icon(Icons.inventory_2_outlined, size: 19),
                      label: Text(
                        '내 보관함 (${profile.ownedTitles.length + profile.nicknameTickets + profile.boostTickets})',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '관심 게임 종목',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OnboardingPage(
                          initialGames: profile.favoriteGames,
                          fromProfile: true,
                        ),
                      ),
                    ),
                    child: const Text('변경'),
                  ),
                ],
              ),
              Card(
                child: profile.favoriteGames.isEmpty
                    ? const ListTile(
                        leading: CircleAvatar(
                          child: Icon(Icons.sports_esports_outlined),
                        ),
                        title: Text('선택한 관심 게임이 없습니다'),
                        subtitle: Text('우측 변경 버튼에서 최대 3개까지 선택해 주세요.'),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < profile.favoriteGames.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            Builder(
                              builder: (_) {
                                final gameName = profile.favoriteGames[i];
                                final visual = _gameVisual(gameName);
                                return ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: visual.asset.isNotEmpty
                                        ? Image.asset(
                                            visual.asset,
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                CircleAvatar(
                                              child: Icon(visual.icon),
                                            ),
                                          )
                                        : CircleAvatar(
                                            child: Icon(visual.icon),
                                          ),
                                  ),
                                  title: Text(
                                    gameName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    '관심 종목 · 홈 우선 추천 및 새 사건 알림',
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              const Text(
                '연결된 게임 계정 & 티어',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < _supportedGames.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      Builder(
                        builder: (_) {
                          final gameName = _supportedGames[i];
                          final account = profile.gameAccounts[gameName];
                          final visual = _gameVisual(gameName);
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                visual.asset,
                                width: 38,
                                height: 38,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    CircleAvatar(child: Icon(visual.icon)),
                              ),
                            ),
                            title: Text(
                              gameName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              account == null
                                  ? '미등록 · 탭하여 닉네임과 티어를 등록하세요'
                                  : '${account.gameId} ·${account.tier}',
                              style: TextStyle(
                                fontSize: 12,
                                color: account == null
                                    ? AppColors.muted
                                    : AppColors.red,
                                fontWeight: account == null
                                    ? FontWeight.normal
                                    : FontWeight.w700,
                              ),
                            ),
                            trailing: Text(
                              account == null ? '등록' : '수정',
                              style: const TextStyle(
                                color: AppColors.red,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () => _openGameAccountDialog(
                              uid: profile.uid,
                              gameName: gameName,
                              current: account,
                            ),
                          );
                        },
                      ),
                    ],
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
                subtitle: const Text('관심 종목에 새 사건·영상이 올라오면 알림 표시'),
                value: profile.notificationsEnabled,
                activeThumbColor: AppColors.red,
                onChanged: (v) => UserService.instance
                    .updateNotificationSetting(profile.uid, v),
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
                leading: const Icon(
                  Icons.psychology_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('AI 모더레이션 모델 다운로드'),
                subtitle: const Text('Chrome: Gemma 4 E2B 웹 모델 · 약 2GB'),
                trailing: const Icon(Icons.download_rounded),
                onTap: () async {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('AI 모델 다운로드를 시작합니다. 완료까지 기다려 주세요.'),
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
                subtitle: Text('보유 닉네임 변경권 ${profile.nicknameTickets}장'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AccountSettingsPage(
                      initialNickname: profile.nickname,
                    ),
                  ),
                ),
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
          );
        },
      ),
    );
  }
}

class _RankText extends StatefulWidget {
  const _RankText({required this.earnedPoints});
  final int earnedPoints;

  @override
  State<_RankText> createState() => _RankTextState();
}

class _RankTextState extends State<_RankText> {
  late Future<int> _rankFuture;

  @override
  void initState() {
    super.initState();
    _rankFuture = UserService.instance.getUserRank(widget.earnedPoints);
  }

  @override
  void didUpdateWidget(covariant _RankText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.earnedPoints != widget.earnedPoints) {
      _rankFuture = UserService.instance.getUserRank(widget.earnedPoints);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _rankFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text(
            '순위 계산 중...',
            style: TextStyle(
              color: AppColors.red,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          );
        }
        return Text(
          '전체 ${snapshot.data}위',
          style: const TextStyle(
            color: AppColors.red,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        );
      },
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