import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../models/case_model.dart';
import '../services/auth_service.dart';
import '../services/case_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/verdict_bar.dart';

class VerdictReportPage extends StatefulWidget {
  const VerdictReportPage({super.key, required this.item});
  final GameCase item;

  @override
  State<VerdictReportPage> createState() => _VerdictReportPageState();
}

class _VerdictReportPageState extends State<VerdictReportPage> {
  final _screenshotController = ScreenshotController();
  bool _isExporting = false;

  String _buildSummaryText(CaseRecord record) {
    if (record.totalVotes == 0) {
      return '아직 판정에 참여한 배심원이 없습니다. 첫 번째 배심원으로 참여해 의견을 남겨보세요.';
    }
    if (!record.isClosed) {
      final leading = record.leftVotes == record.rightVotes
          ? '현재 양측 과실 의견이 동률로 팽팽하게 맞서고 있습니다.'
          : record.leftVotes > record.rightVotes
              ? '현재 Party A(신청인) 측 과실 의견이 ${record.leftPercent}%로 앞서고 있습니다.'
              : '현재 Party B(상대방) 측 과실 의견이 ${record.rightPercent}%로 앞서고 있습니다.';
      return '$leading 마감 시 총 ${PolicyConfig.minVotesForValidCase}명 이상 참여하고 60:40 이상으로 갈리면 유효 판결로 확정됩니다.';
    }

    return switch (record.winner) {
      'left' =>
        '총 ${record.totalVotes}명 중 ${record.leftVotes}명(${record.leftPercent}%)이 Party A(신청인)의 주된 과실로 판정하여 신청인 과실로 종결되었습니다.',
      'right' =>
        '총 ${record.totalVotes}명 중 ${record.rightVotes}명(${record.rightPercent}%)이 Party B(상대방)의 주된 과실로 판정하여 상대방 과실로 종결되었습니다.',
      _ =>
        '최소 참여 인원(${PolicyConfig.minVotesForValidCase}명) 미달 또는 60:40 미만 접전(${record.leftPercent}:${record.rightPercent})으로 치열한 논쟁(보류) 처리되었으며, 적중률 계산에서 제외됩니다.',
    };
  }

  Future<void> _saveReportImage(CaseRecord record) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final Uint8List? bytes = await _screenshotController.capture(
        pixelRatio: 2.0,
      );
      if (bytes == null) {
        throw StateError('리포트 이미지를 캡처하지 못했습니다.');
      }
      final safeName = record.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              name: 'gametribunal_report_$safeName.png',
              mimeType: 'image/png',
            ),
          ],
          text: '[겜문철 판정 리포트] ${record.title} (${record.statusLabel})',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 저장/공유 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _shareResultText(CaseRecord record) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final shareText = [
        '[겜문철 · ${record.game}] ${record.title}',
        '상태: ${record.statusLabel} (참여 ${record.totalVotes}명)',
        '과실 비율: 신청인 ${record.leftPercent}% vs 상대방 ${record.rightPercent}%',
        _buildSummaryText(record),
      ].join('\n');

      await SharePlus.instance.share(ShareParams(text: shareText));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('결과 공유 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;

    return Scaffold(
      appBar: const AppHeader(title: '판정 리포트', back: true),
      body: StreamBuilder<CaseRecord?>(
        stream: CaseService.instance.watchCase(widget.item.id),
        builder: (context, caseSnap) {
          if (caseSnap.connectionState == ConnectionState.waiting &&
              !caseSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final record = caseSnap.data;
          if (record == null) {
            return const Center(child: Text('사건 정보를 찾을 수 없습니다.'));
          }

          return StreamBuilder<String?>(
            stream: uid != null
                ? CaseService.instance.watchMyVote(record.id, uid)
                : const Stream<String?>.empty(),
            builder: (context, voteSnap) {
              final myChoice = voteSnap.data;
              final canViewStats = record.isClosed || myChoice != null;

              if (!canViewStats) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.visibility_off_outlined,
                            size: 44,
                            color: AppColors.red,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '블라인드 투표 진행 중',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '공정한 판정을 위해 투표 참여 전에는 리포트 비율을 공개하지 않습니다.\n사건 상세 화면에서 먼저 판정에 참여해 주세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.muted,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => Navigator.pop(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.red,
                            ),
                            child: const Text('사건 상세로 돌아가기'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return StreamBuilder<List<CaseVoteEntry>>(
                stream: CaseService.instance.watchVotes(record.id),
                builder: (context, votesSnap) {
                  final votes = votesSnap.data ?? const <CaseVoteEntry>[];
                  final highTierVotes =
                      votes.where((v) => v.isHighTier).toList();
                  final highTierLeft =
                      highTierVotes.where((v) => v.choice == 'left').length;
                  final highTierLeftPercent = highTierVotes.isEmpty
                      ? null
                      : ((highTierLeft / highTierVotes.length) * 100).round();

                  return StreamBuilder<List<CaseComment>>(
                    stream: CaseService.instance.watchComments(record.id),
                    builder: (context, commentSnap) {
                      final allComments =
                          commentSnap.data ?? const <CaseComment>[];
                      final rootComments =
                          allComments.where((c) => !c.isReply).toList();
                      rootComments.sort(
                        (a, b) => b.likeCount.compareTo(a.likeCount),
                      );
                      final topComments = rootComments.take(2).toList();

                      final leftComments =
                          allComments.where((c) => c.side == 'left').length;
                      final commentLeftPercent = allComments.isEmpty
                          ? 50
                          : ((leftComments / allComments.length) * 100).round();

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Screenshot(
                            controller: _screenshotController,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: AppColors.field,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: [
                                        const Icon(
                                          Icons.gavel_rounded,
                                          color: Color(0xFFFFC84D),
                                          size: 40,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          record.title,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          record.isClosed
                                              ? record.statusLabel
                                              : '실시간 판정 중간 리포트',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 19,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          '${record.game} · 총 ${record.totalVotes}명 참여 · ${record.remainingTimeText}',
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _VerdictDonutCard(
                                    leftVotes: record.leftVotes,
                                    rightVotes: record.rightVotes,
                                    leftPercent: record.leftPercent,
                                    rightPercent: record.rightPercent,
                                    isClosed: record.isClosed,
                                  ),
                                  const SizedBox(height: 12),
                                  _Section(
                                    title: '판정 요약',
                                    text: _buildSummaryText(record),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '배심원 그룹별 투표 분포',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _Distribution(
                            label: '전체 배심원 (${record.totalVotes}표)',
                            left: record.leftPercent,
                          ),
                          if (highTierLeftPercent != null)
                            _Distribution(
                              label:
                                  '상위 티어 배심원 · 플래티넘 이상 (${highTierVotes.length}표)',
                              left: highTierLeftPercent,
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text(
                                '상위 티어(플래티넘 이상) 배심원 투표 기록이 아직 없습니다. 프로필에서 게임 티어를 등록해 보세요.',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          if (allComments.isNotEmpty)
                            _Distribution(
                              label: '토론 댓글 입장 비율 (${allComments.length}건)',
                              left: commentLeftPercent,
                            ),
                          const SizedBox(height: 14),
                          const Text(
                            '공감 많은 핵심 의견',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (topComments.isEmpty)
                            const _Section(
                              title: '등록된 판결 근거 없음',
                              text: '실시간 토론 탭에서 첫 번째 판결 근거를 남겨보세요.',
                            )
                          else
                            ...topComments.map(
                              (c) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(13),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            c.authorNickname,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '· ${c.sideLabel}',
                                            style: const TextStyle(
                                              color: AppColors.red,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '공감 ${c.likeCount} · 비공감 ${c.dislikeCount}',
                                            style: const TextStyle(
                                              color: AppColors.muted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        c.content,
                                        style: const TextStyle(height: 1.45),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isExporting
                                      ? null
                                      : () => _saveReportImage(record),
                                  icon: const Icon(Icons.image_outlined),
                                  label: Text(
                                    _isExporting ? '처리 중...' : '이미지 저장',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _isExporting
                                      ? null
                                      : () => _shareResultText(record),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.red,
                                  ),
                                  icon: const Icon(Icons.share),
                                  label: const Text('결과 공유'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _VerdictDonutCard extends StatelessWidget {
  const _VerdictDonutCard({
    required this.leftVotes,
    required this.rightVotes,
    required this.leftPercent,
    required this.rightPercent,
    required this.isClosed,
  });

  final int leftVotes;
  final int rightVotes;
  final int leftPercent;
  final int rightPercent;
  final bool isClosed;

  @override
  Widget build(BuildContext context) {
    final total = leftVotes + rightVotes;
    final hasVotes = total > 0;
    final centerLabel = !hasVotes
        ? '0표'
        : (leftPercent >= rightPercent
            ? '신청인\n$leftPercent%'
            : '상대방\n$rightPercent%');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isClosed ? '최종 과실 비율 차트' : '현재 과실 비율 차트',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 124,
                  height: 124,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          startDegreeOffset: -90,
                          sectionsSpace: hasVotes ? 2 : 0,
                          centerSpaceRadius: 36,
                          sections: hasVotes
                              ? [
                                  PieChartSectionData(
                                    value: leftVotes.toDouble(),
                                    color: AppColors.red,
                                    radius: 18,
                                    showTitle: false,
                                  ),
                                  PieChartSectionData(
                                    value: rightVotes.toDouble(),
                                    color: const Color(0xFF2563EB),
                                    radius: 18,
                                    showTitle: false,
                                  ),
                                ]
                              : [
                                  PieChartSectionData(
                                    value: 1,
                                    color: AppColors.line,
                                    radius: 18,
                                    showTitle: false,
                                  ),
                                ],
                        ),
                      ),
                      Text(
                        centerLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 22),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LegendBlock(
                        color: AppColors.red,
                        label: 'Party A · 신청인 과실',
                        value: '$leftVotes표 ($leftPercent%)',
                      ),
                      const SizedBox(height: 18),
                      _LegendBlock(
                        color: const Color(0xFF2563EB),
                        label: 'Party B · 상대방 과실',
                        value: '$rightVotes표 ($rightPercent%)',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendBlock extends StatelessWidget {
  const _LegendBlock({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.text});
  final String title, text;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                text,
                style: const TextStyle(height: 1.5, color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
}

class _Distribution extends StatelessWidget {
  const _Distribution({required this.label, required this.left});
  final String label;
  final int left;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            VerdictBar(left: left, right: 100 - left, labels: false),
          ],
        ),
      );
}