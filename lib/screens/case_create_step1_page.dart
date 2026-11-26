import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/moderation_service.dart';
import '../services/video_upload_service.dart';
import '../theme/app_colors.dart';
import '../widgets/moderation_notice.dart';
import 'case_create_step2_page.dart';
import 'home_page.dart';

class CaseDraft {
  String game = '리그 오브 레전드';
  String title = '';
  String type = '판단 미스';
  String tier = '골드';
  String description = '';
  PlatformFile? videoFile;
  int? videoSizeBytes;
}

class CaseCreateStep1Page extends StatefulWidget {
  const CaseCreateStep1Page({super.key});

  @override
  State<CaseCreateStep1Page> createState() => _CaseCreateStep1PageState();
}

class _CaseCreateStep1PageState extends State<CaseCreateStep1Page> {
  final draft = CaseDraft();
  final title = TextEditingController();
  final description = TextEditingController();
  bool _isChecking = false;

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    }
  }

  String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '용량 확인 중';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _pickVideo() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.video);
      if (files.isEmpty) return;

      final picked = files.first;
      final size = await picked.xFile.length();

      if (size > VideoUploadService.maxSizeBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('영상은 최대 100MB까지 업로드할 수 있습니다.'),
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        draft.videoFile = picked;
        draft.videoSizeBytes = size;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('영상 선택 중 오류가 발생했습니다: $e')),
      );
    }
  }

  Future<void> _goNext() async {
    if (_isChecking) return;
    final trimmedTitle = title.text.trim();
    final trimmedDesc = description.text.trim();

    if (trimmedTitle.isEmpty || trimmedDesc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사건 제목과 상황 설명을 모두 입력해 주세요.')),
      );
      return;
    }

    draft.title = trimmedTitle;
    draft.description = trimmedDesc;

    setState(() => _isChecking = true);
    try {
      final titleCheck = await ModerationService.instance.check(
        trimmedTitle,
        context: ModerationContext.caseTitle,
      );
      if (!mounted) return;
      final titlePassed = await handleModeration(context, titleCheck);
      if (!mounted || !titlePassed) return;

      final detailCheck = await ModerationService.instance.check(
        trimmedDesc,
        context: ModerationContext.caseDescription,
      );
      if (!mounted) return;
      final detailPassed = await handleModeration(context, detailCheck);
      if (!mounted || !detailPassed) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CaseCreateStep2Page(draft: draft)),
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final selectedVideo = draft.videoFile;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            '사건 등록',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _handleBack,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _Progress(step: 1),
            const SizedBox(height: 20),
            const Text(
              '기본 정보와 영상을 입력해 주세요',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            const _Label('게임 종목'),
            DropdownButtonFormField<String>(
              initialValue: draft.game,
              items: const [
                DropdownMenuItem(value: '리그 오브 레전드', child: Text('리그 오브 레전드')),
                DropdownMenuItem(value: '발로란트', child: Text('발로란트')),
                DropdownMenuItem(value: '오버워치 2', child: Text('오버워치 2')),
              ],
              onChanged: (v) => setState(() => draft.game = v!),
            ),
            const SizedBox(height: 12),
            const _Label('사건 제목'),
            TextField(
              controller: title,
              onChanged: (v) => draft.title = v,
              decoration: const InputDecoration(
                hintText: '사건을 한 줄로 요약해 주세요',
              ),
            ),
            const SizedBox(height: 12),
            const _Label('사건 종류 · 티어'),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: draft.type,
                    items: const [
                      DropdownMenuItem(value: '판단 미스', child: Text('판단 미스')),
                      DropdownMenuItem(value: '게임 매너', child: Text('게임 매너')),
                      DropdownMenuItem(value: '플레이 논쟁', child: Text('플레이 논쟁')),
                    ],
                    onChanged: (v) => setState(() => draft.type = v!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: draft.tier,
                    items: const [
                      DropdownMenuItem(value: '아이언~브론즈', child: Text('아이언~브론즈')),
                      DropdownMenuItem(value: '실버', child: Text('실버')),
                      DropdownMenuItem(value: '골드', child: Text('골드')),
                      DropdownMenuItem(value: '플래티넘', child: Text('플래티넘')),
                      DropdownMenuItem(value: '다이아 이상', child: Text('다이아 이상')),
                    ],
                    onChanged: (v) => setState(() => draft.tier = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _Label('영상 증거 (MP4 · MOV · 최대 100MB)'),
            InkWell(
              onTap: _isChecking ? null : _pickVideo,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: selectedVideo != null
                      ? AppColors.redPale
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        selectedVideo != null ? AppColors.red : AppColors.line,
                    width: selectedVideo != null ? 1.5 : 1,
                  ),
                ),
                child: selectedVideo == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.upload_file_outlined,
                            color: AppColors.red,
                            size: 34,
                          ),
                          SizedBox(height: 8),
                          Text(
                            '클릭해서 게임 클립 영상을 선택하세요',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'MP4, MOV, WebM 지원 · 최대 100MB',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppColors.red,
                            child: Icon(
                              Icons.videocam_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedVideo.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${_formatSize(draft.videoSizeBytes)} · 탭하여 영상 변경',
                                  style: const TextStyle(
                                    color: AppColors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '선택 취소',
                            onPressed: () => setState(() {
                              draft.videoFile = null;
                              draft.videoSizeBytes = null;
                            }),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 14),
            const _Label('사건 배경 및 상황'),
            TextField(
              controller: description,
              onChanged: (v) => draft.description = v,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '사건이 발생한 상황을 자세히 설명해 주세요.',
              ),
            ),
            const SizedBox(height: 23),
            FilledButton(
              onPressed: _isChecking ? null : _goNext,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(_isChecking ? '내용 검토 중...' : '다음 단계'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Container(height: 5, color: AppColors.red)),
          const SizedBox(width: 5),
          Expanded(child: Container(height: 5, color: AppColors.line)),
          const SizedBox(width: 10),
          Text(
            '$step / 2',
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
      );
}