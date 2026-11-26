import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../models/case_model.dart';
import '../services/ai_moderation_engine.dart';
import '../services/auth_service.dart';
import '../services/case_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/juror_profile_sheet.dart';
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
  bool _isGeneratingAi = false;
  bool _isDownloadingAi = false;
  VerdictAiSummary? _aiSummary;

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

  Future<void> _generateAiSummary(
    CaseRecord record,
    List<CaseComment> topComments,
  ) async {
    if (_isGeneratingAi) return;
    setState(() => _isGeneratingAi = true);
    try {
      final summary = await AiModerationEngine.instance.summarizeVerdict(
        game: record.game,
        title: record.title,
        description: record.description,
        partyAStatement: record.partyAStatement,
        partyBStatement: record.partyBStatement,
        leftPercent: record.leftPercent,
        rightPercent: record.rightPercent,
        totalVotes: record.totalVotes,
        isClosed: record.isClosed,
        topComments: topComments.map((c) => c.content).toList(),
      );
      if (!mounted) return;
      setState(() => _aiSummary = summary);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 요약 생성 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingAi = false);
    }
  }

  Future<void> _activateGemmaModel(
    CaseRecord record,
    List<CaseComment> topComments,
  ) async {
    if (_isDownloadingAi) return;
    setState(() => _isDownloadingAi = true);
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gemma 온디바이스 AI 모델을 준비 중입니다. 잠시 기다려 주세요.'),
        ),
      );
      await AiModerationEngine.instance.downloadAndActivate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gemma AI 활성화 완료! 정밀 요약을 생성합니다.')),
      );
      await _generateAiSummary(record, topComments);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gemma 모델 활성화 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isDownloadingAi = false);
    }
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
      final lines = [
        '[겜문철 · ${record.game}] ${record.title}',
        '상태: ${record.statusLabel} (참여 ${record.totalVotes}명)',
        '과실 비율: 신청인 ${record.leftPercent}% vs 상대방 ${record.rightPercent}%',
        _buildSummaryText(record),
        if (_aiSummary != null) 'AI 요약: ${_aiSummary!.verdictLine}',
      ];

      await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
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
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.lineColor),
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
                          Text(
                            '공정한 판정을 위해 투표 참여 전에는 리포트 비율을 공개하지 않습니다.\n사건 상세 화면에서 먼저 판정에 참여해 주세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.mutedColor,
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
                          (commentSnap.data ?? const <CaseComment>[])
                              .where((c) => !c.isHidden)
                              .toList();
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
                                color: context.bgColor,
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
                                  const SizedBox(height: 12),
                                  _AiVerdictSummaryCard(
                                    summary: _aiSummary,
                                    isGenerating: _isGeneratingAi,
                                    isDownloadingModel: _isDownloadingAi,
                                    isGemmaReady:
                                        AiModerationEngine.instance.isReady,
                                    onGenerate: () => _generateAiSummary(
                                      record,
                                      topComments,
                                    ),
                                    onActivateGemma: () => _activateGemmaModel(
                                      record,
                                      topComments,
                                    ),
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
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                '상위 티어(플래티넘 이상) 배심원 투표 기록이 아직 없습니다. 프로필에서 게임 티어를 등록해 보세요.',
                                style: TextStyle(
                                  color: context.mutedColor,
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
                                          InkWell(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            onTap: () => showJurorProfileSheet(
                                              context,
                                              uid: c.authorUid,
                                              fallbackNickname:
                                                  c.authorNickname,
                                            ),
                                            child: Text(
                                              c.authorNickname,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13,
                                              ),
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
                                            style: TextStyle(
                                              color: context.mutedColor,
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

class _AiVerdictSummaryCard extends StatelessWidget {
  const _AiVerdictSummaryCard({
    required this.summary,
    required this.isGenerating,
    required this.isDownloadingModel,
    required this.isGemmaReady,
    required this.onGenerate,
    required this.onActivateGemma,
  });

  final VerdictAiSummary? summary;
  final bool isGenerating;
  final bool isDownloadingModel;
  final bool isGemmaReady;
  final VoidCallback onGenerate;
  final VoidCallback onActivateGemma;

  @override
  Widget build(BuildContext context) {
    final badgeLabel = summary != null
        ? (summary!.usedOnDeviceModel ? 'Gemma AI 생성' : '빠른 요약')
        : (isGemmaReady ? 'Gemma 준비됨' : '온디바이스 AI');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'AI 3줄 판결 요약',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: context.redPaleColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeLabel,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (summary == null) ...[
              Text(
                '양측 당사자 진술, 투표 비율, 공감 상위 댓글을 종합해 한눈에 보는 판결 요약본을 생성합니다.',
                style: TextStyle(
                  color: context.mutedColor,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isGenerating ? null : onGenerate,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  icon: isGenerating
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.psychology_alt_rounded, size: 18),
                  label: Text(
                    isGenerating ? '판결 요약 분석 중...' : 'AI 3줄 판결 요약 생성',
                  ),
                ),
              ),
            ] else ...[
              _SummaryRow(label: '핵심 쟁점', text: summary!.issueLine),
              const SizedBox(height: 8),
              _SummaryRow(label: '신청인 요지', text: summary!.partyALine),
              const SizedBox(height: 8),
              _SummaryRow(label: '상대방 요지', text: summary!.partyBLine),
              const SizedBox(height: 8),
              _SummaryRow(
                label: '종합 결론',
                text: summary!.verdictLine,
                highlight: true,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: isGenerating ? null : onGenerate,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 15),
                    label: Text(
                      isGenerating ? '생성 중...' : '다시 요약',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (!summary!.usedOnDeviceModel && !isGemmaReady)
                    FilledButton.tonalIcon(
                      onPressed: isDownloadingModel ? null : onActivateGemma,
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.download_rounded, size: 15),
                      label: Text(
                        isDownloadingModel ? '모델 준비 중...' : 'Gemma AI 활성화',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.text,
    this.highlight = false,
  });

  final String label;
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 68,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: highlight
                ? context.redPaleColor
                : context.lineColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: highlight ? AppColors.primary : context.mutedColor,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w500,
              color: highlight ? context.inkColor : context.mutedColor,
            ),
          ),
        ),
      ],
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
                                    color: context.lineColor,
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
                style: TextStyle(height: 1.5, color: context.mutedColor),
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