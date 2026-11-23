import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/case_card.dart';
import 'case_detail_page.dart';
class MyCasesPage extends StatefulWidget { const MyCasesPage({super.key}); @override State<MyCasesPage> createState() => _MyCasesPageState(); }
class _MyCasesPageState extends State<MyCasesPage> {
  String tab = '내 의뢰 사건';
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: appStore, builder: (_, __) => Scaffold(
    appBar: const AppHeader(title: '내 사건 & 활동 내역', back: true),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(12)), child: const Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_Stat('등록 사건', '3'), _Stat('참여 투표', '84'), _Stat('보유 포인트', '3,250')])),
      const SizedBox(height: 16),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ['내 의뢰 사건', '참여한 투표', '관심 사건'].map((v) => Padding(padding: const EdgeInsets.only(right: 7), child: ChoiceChip(label: Text(v), selected: tab == v, onSelected: (_) => setState(() => tab = v), selectedColor: AppColors.redPale, labelStyle: TextStyle(color: tab == v ? AppColors.red : AppColors.muted, fontWeight: FontWeight.w800)))).toList())),
      const SizedBox(height: 16), Text(tab == '내 의뢰 사건' ? '진행 중인 판정' : tab, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)), const SizedBox(height: 8),
      ...appStore.cases.map((c) => Padding(padding: const EdgeInsets.only(bottom: 9), child: CaseCard(item: c, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CaseDetailPage(item: c))))))
    ]),
  ));
}
class _Stat extends StatelessWidget { const _Stat(this.label, this.value); final String label, value; @override Widget build(BuildContext context) => Column(children: [Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)), const SizedBox(height: 3), Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11))]); }
