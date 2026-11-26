import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_colors.dart';

/// 외부 화면에서 영상 현재 시간 조회 및 특정 시점 점프(seekTo)를 제어하는 컨트롤러
class CaseVideoPlayerController {
  Duration Function()? _positionGetter;
  Future<void> Function(Duration target, {bool autoPlay})? _seeker;

  Duration get currentPosition => _positionGetter?.call() ?? Duration.zero;

  Future<void> seekTo(Duration target, {bool autoPlay = true}) async {
    await _seeker?.call(target, autoPlay: autoPlay);
  }

  void _attach({
    required Duration Function() positionGetter,
    required Future<void> Function(Duration target, {bool autoPlay}) seeker,
  }) {
    _positionGetter = positionGetter;
    _seeker = seeker;
  }

  void _detach() {
    _positionGetter = null;
    _seeker = null;
  }
}

class CaseVideoPlayer extends StatefulWidget {
  const CaseVideoPlayer({
    super.key,
    required this.videoUrl,
    this.controller,
  });

  final String videoUrl;
  final CaseVideoPlayerController? controller;

  @override
  State<CaseVideoPlayer> createState() => _CaseVideoPlayerState();
}

class _CaseVideoPlayerState extends State<CaseVideoPlayer> {
  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.5];

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  double _currentSpeed = 1.0;
  bool _isLooping = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _attachExternalController();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant CaseVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      _attachExternalController();
    }
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeControllers();
      _initPlayer();
    }
  }

  void _attachExternalController() {
    widget.controller?._attach(
      positionGetter: () {
        final value = _videoController?.value;
        if (value == null || !value.isInitialized) return Duration.zero;
        return value.position;
      },
      seeker: (Duration target, {bool autoPlay = true}) async {
        final vc = _videoController;
        if (vc == null || !vc.value.isInitialized) return;
        final clamped = target < Duration.zero
            ? Duration.zero
            : (target > vc.value.duration ? vc.value.duration : target);
        await vc.seekTo(clamped);
        if (autoPlay && !vc.value.isPlaying) {
          await vc.play();
        }
      },
    );
  }

  void _disposeControllers() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
  }

  Future<void> _initPlayer() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentSpeed = 1.0;
      _isLooping = false;
    });

    try {
      final videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      await videoController.initialize();

      if (!mounted) {
        await videoController.dispose();
        return;
      }

      final chewieController = ChewieController(
        videoPlayerController: videoController,
        autoPlay: false,
        looping: false,
        showOptions: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.red,
          handleColor: AppColors.red,
          bufferedColor: Colors.white38,
          backgroundColor: Colors.white24,
        ),
      );

      setState(() {
        _videoController = videoController;
        _chewieController = chewieController;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '영상을 불러오지 못했습니다. ($e)';
      });
    }
  }

  Future<void> _setSpeed(double speed) async {
    final controller = _videoController;
    if (controller == null) return;
    await controller.setPlaybackSpeed(speed);
    if (mounted) setState(() => _currentSpeed = speed);
  }

  Future<void> _seekBy(Duration offset) async {
    final controller = _videoController;
    if (controller == null) return;
    final value = controller.value;
    if (!value.isInitialized) return;

    final target = value.position + offset;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > value.duration ? value.duration : target);
    await controller.seekTo(clamped);
  }

  Future<void> _toggleLoop() async {
    final controller = _videoController;
    if (controller == null) return;
    final next = !_isLooping;
    await controller.setLooping(next);
    if (mounted) setState(() => _isLooping = next);
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 210,
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.red),
              SizedBox(height: 10),
              Text(
                '증거 영상 불러오는 중...',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || _chewieController == null || _videoController == null) {
      return Container(
        height: 210,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 32),
              const SizedBox(height: 8),
              Text(
                _error ?? '영상을 재생할 수 없습니다.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _initPlayer,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final ratio = _videoController!.value.aspectRatio;
    final safeRatio = (ratio.isFinite && ratio > 0) ? ratio : 16 / 9;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: Colors.black,
            child: AspectRatio(
              aspectRatio: safeRatio,
              child: Chewie(controller: _chewieController!),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _seekBy(const Duration(seconds: -3)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.replay_5_rounded, size: 17),
                label: const Text(
                  '-3초',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _seekBy(const Duration(seconds: 3)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.forward_5_rounded, size: 17),
                label: const Text(
                  '+3초',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _toggleLoop,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  backgroundColor: _isLooping ? AppColors.redPale : null,
                  foregroundColor: _isLooping ? AppColors.red : null,
                  side: BorderSide(
                    color: _isLooping ? AppColors.red : AppColors.line,
                  ),
                ),
                icon: const Icon(Icons.repeat_rounded, size: 17),
                label: Text(
                  _isLooping ? '반복 ON' : '반복 OFF',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.slow_motion_video_rounded,
              size: 16,
              color: AppColors.muted,
            ),
            const SizedBox(width: 5),
            const Text(
              '판독 배속',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _speeds.map((s) {
                    final active = _currentSpeed == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('${s}x'),
                        selected: active,
                        visualDensity: VisualDensity.compact,
                        selectedColor: AppColors.redPale,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: active ? AppColors.red : AppColors.muted,
                        ),
                        onSelected: (_) => _setSpeed(s),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}