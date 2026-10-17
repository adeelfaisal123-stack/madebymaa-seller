import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../models/seller_training_video.dart';
import '../utils/app_system_ui.dart';

class SellerTrainingStoriesViewerScreen extends StatefulWidget {
  const SellerTrainingStoriesViewerScreen({
    super.key,
    required this.videos,
    this.initialIndex = 0,
  });

  final List<SellerTrainingVideo> videos;
  final int initialIndex;

  @override
  State<SellerTrainingStoriesViewerScreen> createState() =>
      _SellerTrainingStoriesViewerScreenState();
}

class _SellerTrainingStoriesViewerScreenState
    extends State<SellerTrainingStoriesViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  VideoPlayerController? _controller;
  bool _initializing = true;
  bool _hasError = false;
  double _progress = 0;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.videos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    unawaited(_loadVideo(_currentIndex));
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    unawaited(_disposeController());
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadVideo(int index) async {
    _progressTimer?.cancel();
    await _disposeController();

    if (!mounted) return;
    setState(() {
      _initializing = true;
      _hasError = false;
      _progress = 0;
    });

    final video = widget.videos[index];
    final controller =
        VideoPlayerController.networkUrl(Uri.parse(video.videoUrl));

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      controller
        ..setLooping(false)
        ..addListener(_onVideoTick)
        ..play();

      setState(() {
        _controller = controller;
        _initializing = false;
      });
      _startProgressTimer();
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _hasError = true;
      });
    }
  }

  void _onVideoTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final duration = controller.value.duration.inMilliseconds;
    if (duration <= 0) return;

    final position = controller.value.position.inMilliseconds;
    final nextProgress = (position / duration).clamp(0.0, 1.0);

    if ((nextProgress - _progress).abs() > 0.001 && mounted) {
      setState(() => _progress = nextProgress);
    }

    if (controller.value.position >= controller.value.duration &&
        !controller.value.isPlaying) {
      _goNext(auto: true);
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      _onVideoTick();
    });
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onVideoTick);
      await controller.dispose();
    }
  }

  void _goPrevious() {
    if (_currentIndex <= 0) return;
    HapticFeedback.lightImpact();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _goNext({bool auto = false}) {
    if (_currentIndex >= widget.videos.length - 1) {
      if (auto || _currentIndex == widget.videos.length - 1) {
        Navigator.of(context).maybePop();
      }
      return;
    }

    if (!auto) HapticFeedback.lightImpact();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    unawaited(_loadVideo(index));
  }

  void _onTapDown(TapDownDetails details, double width) {
    final dx = details.globalPosition.dx;
    if (dx < width * 0.35) {
      _goPrevious();
    } else {
      _goNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = AppSystemUi.topInset(context, 8);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.videos.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final video = widget.videos[index];
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) =>
                          _onTapDown(details, constraints.maxWidth),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (index == _currentIndex &&
                              _controller != null &&
                              _controller!.value.isInitialized &&
                              !_hasError)
                            FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: _controller!.value.size.width,
                                height: _controller!.value.size.height,
                                child: VideoPlayer(_controller!),
                              ),
                            )
                          else if (video.thumbnailUrl != null)
                            Image.network(
                              video.thumbnailUrl!,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          if (index == _currentIndex && _initializing)
                            const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          if (index == _currentIndex && _hasError)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Could not play this video.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.exo2(
                                    color: Colors.white70,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            Positioned(
              left: 12,
              right: 12,
              top: topInset,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(widget.videos.length, (index) {
                      final active = index == _currentIndex;
                      final value = active
                          ? _progress
                          : index < _currentIndex
                              ? 1.0
                              : 0.0;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index == widget.videos.length - 1 ? 0 : 4,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: value,
                              minHeight: 3,
                              backgroundColor: Colors.white24,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.videos[_currentIndex].displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.exo2(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
