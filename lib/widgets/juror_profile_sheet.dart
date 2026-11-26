import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import 'user_avatar.dart';

/// 다른 배심원의 아바타·닉네임 탭 시 미니 프로필 바텀시트 표시
Future<void> showJurorProfileSheet(
  BuildContext context, {
  required String uid,
  String? fallbackNickname,
}) async {
  if (uid.isEmpty) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => _JurorProfileSheetBody(
      uid: uid,
      fallbackNickname: fallbackNickname,
    ),
  );
}

class _JurorProfileSheetBody extends StatelessWidget {
  const _JurorProfileSheetBody({
    required this.uid,
    this.fallbackNickname,
  });

  final String uid;
  final String? fallbackNickname;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg =
        isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.background;
    final borderColor = theme.dividerColor;

    return SafeArea(
      child: StreamBuilder<UserProfile?>(
        stream: UserService.instance.watchUser(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final profile = snapshot.data;
          if (profile == null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person_off_outlined,
                    size: 40,
                    color: AppColors.muted,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${fallbackNickname ?? '배심원'} 정보를 찾을 수 없습니다.',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 18),
                LevelUserAvatar(
                  level: profile.level,
                  photoUrl: profile.photoUrl,
                  radius: 36,
                  showLevelPill: true,
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      profile.nickname,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    UserTitleBadge(
                      titleItem: profile.equippedTitleItem,
                      compact: false,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Lv.${profile.level} · ${profile.title}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (profile.currentStreak >= 2 || profile.bestStreak >= 2) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF97316)),
                    ),
                    child: Text(
                      profile.currentStreak >= 2
                          ? '🔥 ${profile.currentStreak}연속 적중 중 (최고 ${profile.bestStreak}연속)'
                          : '🔥 최고 ${profile.bestStreak}연속 적중 기록',
                      style: const TextStyle(
                        color: Color(0xFFEA580C),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: '판정 적중률',
                        value: profile.accuracyText,
                        bg: cardBg,
                        borderColor: borderColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStat(
                        label: '참여 판결',
                        value: '${profile.totalVotes}건',
                        bg: cardBg,
                        borderColor: borderColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStat(
                        label: '누적 포인트',
                        value: '${profile.totalEarnedPoints} P',
                        bg: cardBg,
                        borderColor: borderColor,
                      ),
                    ),
                  ],
                ),
                if (profile.gameAccounts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '등록된 게임 티어',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: profile.gameAccounts.entries.map((entry) {
                        final acc = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Text(
                                acc.gameId,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: acc.isHighTier
                                      ? AppColors.redPale
                                      : borderColor.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  acc.tier,
                                  style: TextStyle(
                                    color: acc.isHighTier
                                        ? AppColors.red
                                        : AppColors.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                if (profile.favoriteGames.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: profile.favoriteGames
                          .map(
                            (g) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.redPale,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '#$g',
                                style: const TextStyle(
                                  color: AppColors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.bg,
    required this.borderColor,
  });

  final String label;
  final String value;
  final Color bg;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.red,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}