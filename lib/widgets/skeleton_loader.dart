import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 부드러운 Shimmer 애니메이션을 제공하는 공통 스켈레톤 박스
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = 8,
    this.isCircle = false,
  });

  final double width;
  final double height;
  final double radius;
  final bool isCircle;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.12);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final slide = (_controller.value * 2.4) - 1.2;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius:
                widget.isCircle ? null : BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(slide - 0.8, 0),
              end: Alignment(slide + 0.8, 0),
              colors: [baseColor, highlightColor, baseColor],
            ),
          ),
        );
      },
    );
  }
}

/// 홈 / 실시간 사건 피드 스켈레톤
class HomeFeedSkeleton extends StatelessWidget {
  const HomeFeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const Row(
          children: [
            SkeletonBox(width: 170, height: 24, radius: 6),
            Spacer(),
            SkeletonBox(width: 64, height: 24, radius: 14),
          ],
        ),
        const SizedBox(height: 12),
        const SkeletonBox(height: 44, radius: 12),
        const SizedBox(height: 10),
        const Row(
          children: [
            SkeletonBox(width: 62, height: 32, radius: 16),
            SizedBox(width: 8),
            SkeletonBox(width: 82, height: 32, radius: 16),
            SizedBox(width: 8),
            SkeletonBox(width: 72, height: 32, radius: 16),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.lineColor),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 110, height: 14),
              SizedBox(height: 12),
              SkeletonBox(height: 140, radius: 10),
              SizedBox(height: 12),
              SkeletonBox(width: 240, height: 18),
              SizedBox(height: 8),
              SkeletonBox(width: 160, height: 13),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < 3; i++) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.lineColor),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonBox(width: 120, height: 13),
                    Spacer(),
                    SkeletonBox(width: 58, height: 18, radius: 10),
                  ],
                ),
                SizedBox(height: 10),
                SkeletonBox(width: 260, height: 17),
                SizedBox(height: 10),
                SkeletonBox(height: 34, radius: 8),
                SizedBox(height: 10),
                Row(
                  children: [
                    SkeletonBox(width: 22, height: 22, isCircle: true),
                    SizedBox(width: 8),
                    SkeletonBox(width: 80, height: 12),
                    Spacer(),
                    SkeletonBox(width: 96, height: 12),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// MY 프로필 화면 스켈레톤
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.lineColor),
          ),
          child: const Column(
            children: [
              Row(
                children: [
                  SkeletonBox(width: 68, height: 68, isCircle: true),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 130, height: 20),
                        SizedBox(height: 8),
                        SkeletonBox(width: 100, height: 14),
                        SizedBox(height: 8),
                        SkeletonBox(width: 170, height: 13),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              SkeletonBox(height: 8, radius: 6),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SkeletonBox(height: 92, radius: 12),
        const SizedBox(height: 10),
        const Row(
          children: [
            Expanded(child: SkeletonBox(height: 62, radius: 10)),
            SizedBox(width: 8),
            Expanded(child: SkeletonBox(height: 62, radius: 10)),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Expanded(child: SkeletonBox(height: 46, radius: 10)),
            SizedBox(width: 8),
            Expanded(child: SkeletonBox(height: 46, radius: 10)),
          ],
        ),
      ],
    );
  }
}

/// 랭킹 화면 스켈레톤 (2단계 랭킹 화면 마무리에서 사용)
class RankingSkeleton extends StatelessWidget {
  const RankingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SkeletonBox(width: 88, height: 112, radius: 12),
            SkeletonBox(width: 96, height: 136, radius: 12),
            SkeletonBox(width: 88, height: 100, radius: 12),
          ],
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < 6; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.lineColor),
            ),
            child: const Row(
              children: [
                SkeletonBox(width: 24, height: 18),
                SizedBox(width: 12),
                SkeletonBox(width: 38, height: 38, isCircle: true),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 110, height: 14),
                      SizedBox(height: 6),
                      SkeletonBox(width: 80, height: 11),
                    ],
                  ),
                ),
                SkeletonBox(width: 56, height: 16),
              ],
            ),
          ),
      ],
    );
  }
}