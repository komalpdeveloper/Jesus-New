import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoBackground extends StatefulWidget {
  final String assetPath;
  final Widget? placeholder;

  const VideoBackground({
    super.key,
    required this.assetPath,
    this.placeholder,
  });

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<VideoBackground> {
  VideoPlayerController? _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(VideoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _disposeController();
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.asset(
      widget.assetPath,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    
    _controller!.addListener(() {
      if (_controller!.value.hasError) {
        debugPrint('Video Player Error: ${_controller!.value.errorDescription}');
        if (mounted && !_hasError) {
          setState(() {
            _hasError = true;
          });
        }
      }
    });

    try {
      await _controller!.initialize();
      await _controller!.setVolume(0.0);
      await _controller!.setLooping(true);
      await _controller!.play();
      
      // Ensure it's playing
      if (!_controller!.value.isPlaying) {
        await Future.delayed(const Duration(milliseconds: 100));
        await _controller!.play();
      }
      
      debugPrint("Video playing status: ${_controller!.value.isPlaying}");

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error initializing video background: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _hasError = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || _controller == null || !_controller!.value.isInitialized) {
      return widget.placeholder ?? Container(color: Colors.black);
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}
