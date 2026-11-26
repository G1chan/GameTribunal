import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/case_service.dart';
import '../services/moderation_service.dart';
import '../services/user_service.dart';
import '../services/video_upload_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/moderation_notice.dart';
import 'case_create_step1_page.dart';
import 'home_page.dart';

class CaseCreateStep2Page extends StatefulWidget {
  const CaseCreateStep2Page({super.key, required this.draft});
  final CaseDraft draft;

  @override
  State<CaseCreateStep2Page> createState() => _CaseCreateStep2PageState();
}

class _CaseCreateStep2PageState extends State<CaseCreateStep2Page> {
  final a = TextEditingController();
  final b = TextEditingController();
  final issues = <String>{'진입 타이밍'};
  String deadline = '24시간';
  bool _isSubmitting = false;
  String _submitLabel = '사건 등록하기';

  @override
  void dispose() {
    a.dispose();
    b.dispose();
    super.dispose();
  }

  Duration _deadlineDuration() {
    return switch (deadline) {
      '6시간' => const Duration(hours: 6),
      '3일' => const Duration(days: 3),
      _ => const Duration(hours: 24),
    };
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final partyA = a.text.trim();
    final partyB = b.text.trim();
    if (partyA.isEmpty || partyB.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신청인과 상대방 주장을 모두 입력해 주세요.')),
      );
      return;
    }

    final firebaseUser = AuthService.instance.currentUser;
    if (firebaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitLabel = '내용 검토 중...';
    });

    try {
      final partyACheck = await ModerationService.instance.check(
        partyA,
        context: ModerationContext.partyStatement,
      );
      if (!mounted) return;
      final aPassed = await handleModeration(context, partyACheck);
      if (!mounted || !aPassed) return;

      final partyBCheck = await ModerationService.instance.check(
        partyB,
        context: ModerationContext.partyStatement,
      );
      if (!mounted) return;
      final bPassed = await handleModeration(context, partyBCheck);
      if (!mounted || !bPassed) return;

      String? videoUrl;
      String? thumbnailUrl;

      final videoFile = widget.draft.videoFile;
      if (videoFile != null) {
        setState(() => _submitLabel = '영상 업로드 중...');
        final uploaded = await VideoUploadService.instance.uploadVideo(
          videoFile,
        );
        videoUrl = uploaded.videoUrl;
        thumbnailUrl = uploaded.thumbnailUrl;
      }

      if (!mounted) return;
      setState(() => _submitLabel = '사건 등록 중...');

      final profile = await UserService.instance.ensureUserDocument(firebaseUser);

      await CaseService.instance.createCase(
        authorUid: firebaseUser.uid,
        authorNickname: profile.nickname,
        game: widget.draft.game,
        title: widget.draft.title,
        type: widget.draft.type,
        tier: widget.draft.tier,
        description: widget.draft.description,
        partyAStatement: partyA,
        partyBStatement: partyB,
        issues: issues.toList(),
        duration: _deadlineDuration(),
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '사건이 등록되었습니다! (+${PolicyConfig.xpCreateCase} XP, +${PolicyConfig.pointsCreateCase} P)',
          ),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사건 등록 실패: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitLabel = '사건 등록하기';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoFile = widget.draft.videoFile;

    return Scaffold(
      appBar: const AppHeader(title: '사건 등록', back: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _StepTwoProgress(),
          const SizedBox(height: 20),
          const Text(
            '쟁점과 심사 방식을 설정해 주세요',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          if (videoFile != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.redPale,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.videocam_rounded,
                    color: AppColors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '첨부 영상: ${videoFile.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            'Party A · 신청인 주장',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: a,
            maxLines: 3,
            decoration: const InputDecoration(hintText: '신청인 측 주장을 작성하세요'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Party B · 상대방 주장',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: b,
            maxLines: 3,
            decoration: const InputDecoration(hintText: '상대방 측 주장을 작성하세요'),
          ),
          const SizedBox(height: 16),
          const Text('핵심 쟁점', style: TextStyle(fontWeight: FontWeight.w800)),
          Wrap(
            spacing: 7,
            children: ['진입 타이밍', '시야 확보', '스킬 사용', '콜 판단']
                .map(
                  (x) => FilterChip(
                    label: Text(x),
                    selected: issues.contains(x),
                    onSelected: (v) => setState(
                      () => v ? issues.add(x) : issues.remove(x),
                    ),
                    selectedColor: AppColors.redPale,
                    checkmarkColor: AppColors.red,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          const Text('투표 마감 기간', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '6시간', label: Text('6시간')),
              ButtonSegment(value: '24시간', label: Text('24시간')),
              ButtonSegment(value: '3일', label: Text('3일')),
            ],
            selected: {deadline},
            onSelectionChanged: (s) => setState(() => deadline = s.first),
          ),
          const SizedBox(height: 14),
          const Text('보상 및 판정 정책', style: TextStyle(fontWeight: FontWeight.w800)),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: AppColors.redPale,
              child: Icon(Icons.monetization_on_outlined, color: AppColors.red),
            ),
            title: Text('블라인드 다수결 · 60:40 유효 판결'),
            subtitle: Text(
              '사건 제보 +30 XP / +10 P · 배심원 투표 +5 P · 적중 보너스 +15 P',
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(_submitLabel),
          ),
        ],
      ),
    );
  }
}

class _StepTwoProgress extends StatelessWidget {
  const _StepTwoProgress();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Container(height: 5, color: AppColors.red)),
          const SizedBox(width: 5),
          Expanded(child: Container(height: 5, color: AppColors.red)),
          const SizedBox(width: 10),
          const Text(
            '2 / 2',
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
}