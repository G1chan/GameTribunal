import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
class VerdictBar extends StatelessWidget { const VerdictBar({super.key, required this.left, required this.right, this.height = 9, this.labels = true}); final int left, right; final double height; final bool labels;
  @override Widget build(BuildContext context) => Column(children: [if (labels) Row(children: [Text('신청인 $left%', style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w800)), const Spacer(), Text('상대방 $right%', style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w800))]), if (labels) const SizedBox(height: 6), ClipRRect(borderRadius: BorderRadius.circular(20), child: SizedBox(height: height, child: Row(children: [Expanded(flex: left, child: const ColoredBox(color: AppColors.red)), Expanded(flex: right, child: const ColoredBox(color: AppColors.blue))])))]);
}
