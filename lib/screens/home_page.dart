import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/app_header.dart';
import '../widgets/case_card.dart';
import '../widgets/game_filter.dart';
import '../widgets/verdict_bar.dart';
import 'case_detail_page.dart';

class HomePage extends StatefulWidget { const HomePage({super.key, this.liveOnly = false}); final bool liveOnly; @override State<HomePage> createState() => _HomePageState(); }
class _HomePageState extends State<HomePage> {
  String filter = '전체';
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: appStore,
    builder: (_, __) {
      final items = appStore.cases.where((c) => (filter == '전체' || c.game == filter) && (!widget.liveOnly || c.live)).toList();
      return Scaffold(
        appBar: const AppHeader(), bottomNavigationBar: AppBottomNavigation(index: widget.liveOnly ? 1 : 0),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 18), children: [
          Row(children: [const Expanded(child: Text('오늘의 판결 & 실시간', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.redPale, borderRadius: BorderRadius.circular(20)), child: const Text('LIVE 12', style: TextStyle(color: AppColors.red, fontSize: 11, fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 12), GameFilter(value: filter, onChanged: (v) => setState(() => filter = v)),
          if (!widget.liveOnly) ...[const SizedBox(height: 17), _LiveHero(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CaseDetailPage(item: appStore.cases.first))) )],
          const SizedBox(height: 20), const Text('주요 사건', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 8),
          ...items.map((c) => Padding(padding: const EdgeInsets.only(bottom: 9), child: CaseCard(item: c, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CaseDetailPage(item: c)))))),
          const SizedBox(height: 10), const Text('실시간 배심원 피드', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 8),
          const Card(child: ListTile(leading: CircleAvatar(child: Icon(Icons.gavel)), title: Text('판결의신님이 판정에 참여했어요'), subtitle: Text('시야 없는 바론은 무리한 판단입니다.'), trailing: Text('방금', style: TextStyle(color: AppColors.muted, fontSize: 11)))),
        ]),
      );
    },
  );
}
class _LiveHero extends StatelessWidget { const _LiveHero({required this.onTap}); final VoidCallback onTap; @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(14)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text('실시간 긴급 판정', style: TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.w900)), Spacer(), Text('1,248명 참여', style: TextStyle(color: Colors.white60, fontSize: 11))]), SizedBox(height: 16), Text('바론 앞 한타, 이니시는 누구의 판단이었나?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)), SizedBox(height: 5), Text('리그 오브 레전드 · 마감까지 00:38:12', style: TextStyle(color: Colors.white60, fontSize: 12)), SizedBox(height: 15), VerdictBar(left: 62, right: 38)]))); }
