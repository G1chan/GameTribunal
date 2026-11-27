import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ai_moderation_engine.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Gemma 온디바이스 AI 모델 다운로드 진행 상태를 시각적으로 보여주는 다이얼로그
Future<bool> showAiModelDownloadDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _AiDownloadDialog(),
  );
  return result == true;
}

class _AiDownloadDialog extends StatefulWidget {
  const _AiDownloadDialog();

  @override
  State<_AiDownloadDialog> createState() => _AiDownloadDialogState();
}

class _AiDownloadDialogState extends State<_AiDownloadDialog> {
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _startIfNeeded();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _elapsedSeconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!AiModerationEngine.instance.status.value.isBusy) {
        _timer?.cancel();
        return;
      }
      setState(() => _elapsedSeconds++);
    });
  }

  void _startIfNeeded() {
    final current = AiModerationEngine.instance.status.value;
    if (current.stage == AiEngineStage.ready) return;
    _startTimer();
    unawaited(
      AiModerationEngine.instance.downloadAndActivate().catchError((_) {}),
    );
  }

  String _formatElapsed(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AiEngineStatus>(
      valueListenable: AiModerationEngine.instance.status,
      builder: (context, status, _) {
        final isReady = status.stage == AiEngineStage.ready;
        final isError = status.stage == AiEngineStage.error;
        final isBusy = status.isBusy;

        return AlertDialog(
          title: Row(
            children: [
              Icon(
                isReady
                    ? Icons.check_circle_rounded
                    : (isError
                        ? Icons.error_outline_rounded
                        : Icons.psychology_alt_rounded),
                color: isReady
                    ? const Color(0xFF10B981)
                    : (isError ? const Color(0xFFEF4444) : AppColors.primary),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Gemma 온디바이스 AI',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.message,
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: isError ? 0 : status.progress,
                  minHeight: 8,
                  backgroundColor: context.redPaleColor,
                  color: isReady ? const Color(0xFF10B981) : AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isBusy
                        ? '경과 시간 ${_formatElapsed(_elapsedSeconds)}'
                        : (isReady ? '로컬 캐싱 완료' : '준비 실패'),
                    style: TextStyle(
                      color: context.mutedColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    isReady
                        ? '100%'
                        : (status.progress != null
                            ? '${(status.progress! * 100).round()}%'
                            : '다운로드 중...'),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _StepItem(
                label: 'LiteRT-LM 추론 엔진 초기화',
                done: status.stage == AiEngineStage.downloading || isReady,
                active: status.stage == AiEngineStage.initializing,
              ),
              const SizedBox(height: 6),
              _StepItem(
                label: 'Gemma 모델 다운로드 및 로컬 캐싱',
                done: isReady,
                active: status.stage == AiEngineStage.downloading,
              ),
              if (isError && status.errorDetail != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.fieldColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.lineColor),
                  ),
                  child: Text(
                    status.errorDetail!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.mutedColor, fontSize: 11),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (isBusy)
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('백그라운드에서 계속'),
              ),
            if (isError) ...[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('닫기'),
              ),
              FilledButton(
                onPressed: _startIfNeeded,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('다시 시도'),
              ),
            ],
            if (isReady)
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                ),
                child: const Text('완료'),
              ),
          ],
        );
      },
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.label,
    required this.done,
    required this.active,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (done)
          const Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: Color(0xFF10B981),
          )
        else if (active)
          const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          )
        else
          Icon(
            Icons.radio_button_unchecked,
            size: 16,
            color: context.mutedColor,
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active || done ? FontWeight.w800 : FontWeight.w500,
              color: active || done ? context.inkColor : context.mutedColor,
            ),
          ),
        ),
      ],
    );
  }
}