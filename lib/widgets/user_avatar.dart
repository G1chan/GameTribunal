import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/shop_item.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';

class _BorderTierStyle {
  const _BorderTierStyle({
    required this.name,
    required this.colors,
    required this.glowColor,
    required this.accentColor,
    required this.hasBottomGem,
    required this.hasTopCrest,
    required this.hasWings,
    required this.crestIcon,
  });

  final String name;
  final List<Color> colors;
  final Color glowColor;
  final Color accentColor;
  final bool hasBottomGem;
  final bool hasTopCrest;
  final bool hasWings;
  final IconData crestIcon;

  static _BorderTierStyle forLevel(int level) {
    if (level >= 20) {
      return const _BorderTierStyle(
        name: '챌린저 골드 (Lv.20+)',
        colors: [
          Color(0xFFFFE57F),
          Color(0xFFF59E0B),
          Color(0xFF38BDF8),
          Color(0xFFFFF8E1),
          Color(0xFFF59E0B),
          Color(0xFFFFE57F),
        ],
        glowColor: Color(0xFFF59E0B),
        accentColor: Color(0xFFD97706),
        hasBottomGem: true,
        hasTopCrest: true,
        hasWings: true,
        crestIcon: Icons.workspace_premium_rounded,
      );
    }
    if (level >= 10) {
      return const _BorderTierStyle(
        name: '크림슨 루비 (Lv.10~19)',
        colors: [
          Color(0xFFFF8A80),
          Color(0xFFDC2626),
          Color(0xFFFCA5A5),
          Color(0xFF991B1B),
          Color(0xFFFF8A80),
        ],
        glowColor: Color(0xFFEF4444),
        accentColor: Color(0xFFDC2626),
        hasBottomGem: true,
        hasTopCrest: true,
        hasWings: false,
        crestIcon: Icons.diamond_rounded,
      );
    }
    if (level >= 5) {
      return const _BorderTierStyle(
        name: '사파이어 블루 (Lv.5~9)',
        colors: [
          Color(0xFF93C5FD),
          Color(0xFF2563EB),
          Color(0xFFE0F2FE),
          Color(0xFF1D4ED8),
          Color(0xFF93C5FD),
        ],
        glowColor: Color(0xFF3B82F6),
        accentColor: Color(0xFF2563EB),
        hasBottomGem: true,
        hasTopCrest: false,
        hasWings: false,
        crestIcon: Icons.auto_awesome_rounded,
      );
    }
    return const _BorderTierStyle(
      name: '실버 견습 (Lv.1~4)',
      colors: [
        Color(0xFFE2E8F0),
        Color(0xFF94A3B8),
        Color(0xFFFFFFFF),
        Color(0xFF64748B),
        Color(0xFFE2E8F0),
      ],
      glowColor: Color(0xFF94A3B8),
      accentColor: Color(0xFF64748B),
      hasBottomGem: false,
      hasTopCrest: false,
      hasWings: false,
      crestIcon: Icons.shield_outlined,
    );
  }
}

/// 롤 스타일의 회전 광택(Shimmer)과 돌출 장식이 레벨에 따라 진화하는 프로필 아바타
class LevelUserAvatar extends StatefulWidget {
  const LevelUserAvatar({
    super.key,
    required this.level,
    this.photoUrl,
    this.radius = 24,
    this.showEmblems = true,
    this.showLevelPill = false,
  });

  final int level;
  final String? photoUrl;
  final double radius;
  final bool showEmblems;
  final bool showLevelPill;

  @override
  State<LevelUserAvatar> createState() => _LevelUserAvatarState();
}

class _LevelUserAvatarState extends State<LevelUserAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _BorderTierStyle.forLevel(widget.level);
    final ringThickness = (widget.radius * 0.14).clamp(2.4, 5.0);
    final outerSize = (widget.radius + ringThickness) * 2;
    final hasPhoto = widget.photoUrl != null && widget.photoUrl!.isNotEmpty;
    final showDecor = widget.showEmblems && widget.radius >= 16;

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (showDecor && style.hasWings) ...[
            Positioned(
              left: -widget.radius * 0.22,
              child: _SideWing(
                color: style.accentColor,
                size: widget.radius * 0.42,
                isLeft: true,
              ),
            ),
            Positioned(
              right: -widget.radius * 0.22,
              child: _SideWing(
                color: style.accentColor,
                size: widget.radius * 0.42,
                isLeft: false,
              ),
            ),
          ],
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                width: outerSize,
                height: outerSize,
                padding: EdgeInsets.all(ringThickness),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: style.colors,
                    transform: GradientRotation(_controller.value * math.pi * 2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: style.glowColor.withValues(
                        alpha: widget.level >= 10 ? 0.55 : 0.30,
                      ),
                      blurRadius: widget.level >= 20 ? 12 : 7,
                      spreadRadius: widget.level >= 10 ? 1 : 0,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              padding: const EdgeInsets.all(1.5),
              child: ClipOval(
                child: hasPhoto
                    ? Image.network(
                        widget.photoUrl!,
                        fit: BoxFit.cover,
                        width: widget.radius * 2,
                        height: widget.radius * 2,
                        errorBuilder: (_, __, ___) => _FallbackAvatarBody(
                          radius: widget.radius,
                          accentColor: style.accentColor,
                        ),
                      )
                    : _FallbackAvatarBody(
                        radius: widget.radius,
                        accentColor: style.accentColor,
                      ),
              ),
            ),
          ),
          if (showDecor && style.hasTopCrest)
            Positioned(
              top: -widget.radius * 0.24,
              child: Container(
                padding: EdgeInsets.all(widget.radius * 0.08),
                decoration: BoxDecoration(
                  color: style.accentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: style.glowColor.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Icon(
                  style.crestIcon,
                  size: (widget.radius * 0.36).clamp(9.0, 16.0),
                  color: Colors.white,
                ),
              ),
            ),
          if (widget.showLevelPill)
            Positioned(
              bottom: -widget.radius * 0.18,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: style.accentColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  'Lv.${widget.level}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            )
          else if (showDecor && style.hasBottomGem)
            Positioned(
              bottom: -widget.radius * 0.12,
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: (widget.radius * 0.24).clamp(6.0, 10.0),
                  height: (widget.radius * 0.24).clamp(6.0, 10.0),
                  decoration: BoxDecoration(
                    color: style.accentColor,
                    border: Border.all(color: Colors.white, width: 1.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SideWing extends StatelessWidget {
  const _SideWing({
    required this.color,
    required this.size,
    required this.isLeft,
  });

  final Color color;
  final double size;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: isLeft ? -0.35 : 0.35,
      child: Icon(
        isLeft ? Icons.keyboard_double_arrow_left_rounded : Icons.keyboard_double_arrow_right_rounded,
        size: size,
        color: color,
      ),
    );
  }
}

class _FallbackAvatarBody extends StatelessWidget {
  const _FallbackAvatarBody({
    required this.radius,
    required this.accentColor,
  });

  final double radius;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.redPale,
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: radius * 1.15,
        color: accentColor,
      ),
    );
  }
}

/// 장착 중인 특별 칭호 배지 위젯
class UserTitleBadge extends StatelessWidget {
  const UserTitleBadge({
    super.key,
    required this.titleItem,
    this.compact = false,
  });

  final ShopItem? titleItem;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final item = titleItem;
    if (item == null || item.badgeText == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: item.accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: item.accentColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            item.fallbackIcon,
            size: compact ? 11 : 13,
            color: item.accentColor,
          ),
          const SizedBox(width: 3),
          Text(
            item.badgeText!,
            style: TextStyle(
              color: item.accentColor,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// uid만으로 실시간 프사 + 레벨 테두리를 구독해 표시하는 위젯 (토론·홈 카드용)
class LiveUserAvatar extends StatelessWidget {
  const LiveUserAvatar({
    super.key,
    required this.uid,
    this.radius = 18,
    this.showEmblems = true,
  });

  final String uid;
  final double radius;
  final bool showEmblems;

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return LevelUserAvatar(level: 1, radius: radius, showEmblems: false);
    }
    return StreamBuilder<UserProfile?>(
      stream: UserService.instance.watchUser(uid),
      builder: (context, snapshot) {
        final user = snapshot.data;
        return LevelUserAvatar(
          level: user?.level ?? 1,
          photoUrl: user?.photoUrl,
          radius: radius,
          showEmblems: showEmblems,
        );
      },
    );
  }
}

/// uid만으로 실시간 장착 칭호를 구독해 표시하는 위젯 (토론·사건 상세용)
class LiveUserTitleBadge extends StatelessWidget {
  const LiveUserTitleBadge({
    super.key,
    required this.uid,
    this.compact = true,
  });

  final String uid;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<UserProfile?>(
      stream: UserService.instance.watchUser(uid),
      builder: (context, snapshot) {
        return UserTitleBadge(
          titleItem: snapshot.data?.equippedTitleItem,
          compact: compact,
        );
      },
    );
  }
}