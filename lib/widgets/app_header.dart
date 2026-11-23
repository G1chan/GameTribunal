import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
class AppHeader extends StatelessWidget implements PreferredSizeWidget { const AppHeader({super.key, this.title = '겜문철', this.back = false, this.actions}); final String title; final bool back; final List<Widget>? actions;
  @override Widget build(BuildContext context) => AppBar(leading: back ? IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19)) : null, title: Row(children: [Container(width: 25, height: 25, decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(7)), child: const Icon(Icons.gavel_rounded, size: 16, color: Colors.white)), const SizedBox(width: 7), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))]), actions: actions ?? [IconButton(onPressed: () {}, icon: const Badge(smallSize: 7, child: Icon(Icons.notifications_none_rounded)))]);
  @override Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
