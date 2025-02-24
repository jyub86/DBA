import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class YoutubePlayerScreen extends StatefulWidget {
  final String videoId;

  const YoutubePlayerScreen({
    super.key,
    required this.videoId,
  });

  @override
  State<YoutubePlayerScreen> createState() => _YoutubePlayerScreenState();
}

class _YoutubePlayerScreenState extends State<YoutubePlayerScreen>
    with WidgetsBindingObserver {
  late YoutubePlayerController _controller;
  bool _isDisposed = false;
  bool _isIOS = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isIOS = Theme.of(context).platform == TargetPlatform.iOS;
  }

  void _initializePlayer() {
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      params: const YoutubePlayerParams(
        showControls: true,
        mute: false,
        showFullscreenButton: false,
        enableJavaScript: true,
        strictRelatedVideos: true,
        showVideoAnnotations: false,
        playsInline: false,
        enableCaption: false,
        interfaceLanguage: 'ko',
        enableKeyboard: false,
        pointerEvents: PointerEvents.auto,
      ),
    );

    _controller.setFullScreenListener((isFullScreen) {
      if (_isIOS) {
        if (!isFullScreen && mounted && !_isDisposed) {
          _handleClose();
        }
      } else {
        if (!isFullScreen && mounted && !_isDisposed) {
          Navigator.pop(context);
        }
      }
    });
  }

  Future<void> _handleClose() async {
    if (!_isDisposed) {
      if (mounted) {
        await _controller.pauseVideo();
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _handleClose();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: YoutubePlayer(
                  controller: _controller,
                  aspectRatio: 16 / 9,
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _handleClose,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);

    if (mounted) {
      _controller.pauseVideo();
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _controller.close();
      }
    });

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱 생명주기 변화 감지용 메서드 유지
  }
}
