import 'package:flutter/material.dart';
import '../models/moderation_result.dart';
import '../theme/app_colors.dart';
Future<bool> handleModeration(BuildContext context, ModerationResult result) async {
  if (result.action == ModerationAction.allow) return true;
  if (result.action == ModerationAction.warn) return (await showDialog<bool>(context: context, builder: (_) => AlertDialog(backgroundColor: AppColors.surface, title: const Text('표현을 확인해 주세요'), content: Text(result.message), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('수정하기')), FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: AppColors.primary), child: const Text('그래도 등록'))]))) ?? false;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message), backgroundColor: result.action == ModerationAction.review ? AppColors.field : Colors.redAccent));
  return false;
}
