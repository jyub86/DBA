import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class YoutubePlayerScreen extends StatefulWidget {
  final String videoId;
  final int startSeconds;

  const YoutubePlayerScreen({
    super.key,
    required this.videoId,
    this.startSeconds = 0, // 기본값은 0초
  });

  @override
  State<YoutubePlayerScreen> createState() => _YoutubePlayerScreenState();
}

class _YoutubePlayerScreenState extends State<YoutubePlayerScreen> {
  late YoutubePlayerController _controller;
  bool _isFullScreen = false;
  bool _isReady = false;
  Timer? _positionTimer;

  @override
  void initState() {
    super.initState();
    // 화면 가로 모드 강제
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initPlayer();
  }

  void _initPlayer() {
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        hideControls: false,
        disableDragSeek: false,
        loop: false,
        isLive: false,
        forceHD: true,
        enableCaption: false,
        useHybridComposition: true,
      ),
    );
  }

  @override
  void dispose() {
    // 화면 세로 모드로 복원
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // 타이머 정리
    _positionTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isFullScreen) {
          // 전체화면 종료
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
          setState(() {
            _isFullScreen = false;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: YoutubePlayerBuilder(
            onEnterFullScreen: () {
              setState(() {
                _isFullScreen = true;
              });
            },
            onExitFullScreen: () {
              setState(() {
                _isFullScreen = false;
              });
            },
            player: YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.red,
              progressColors: const ProgressBarColors(
                playedColor: Colors.red,
                handleColor: Colors.redAccent,
              ),
              onReady: () {
                // 플레이어가 준비되었을 때 시작 위치로 이동 (한 번만 실행)
                if (widget.startSeconds > 0 && !_isReady) {
                  setState(() {
                    _isReady = true; // 플래그 설정으로 중복 실행 방지
                  });

                  // 약간의 지연 후 시작 위치로 이동
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) {
                      _controller
                          .seekTo(Duration(seconds: widget.startSeconds));
                      _controller.play();
                    }
                  });
                }
              },
              onEnded: (metaData) {
                // 영상이 끝나면 이전 화면으로 돌아가기
                Navigator.pop(context);
              },
              topActions: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                const Spacer(),
              ],
              bottomActions: [
                const SizedBox(width: 8.0),
                const CurrentPosition(),
                const SizedBox(width: 8.0),
                const ProgressBar(
                  isExpanded: true,
                  colors: ProgressBarColors(
                    playedColor: Colors.red,
                    handleColor: Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 8.0),
                const RemainingDuration(),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(
                    Icons.fullscreen_exit,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    // 전체화면 종료 및 이전 화면으로 돌아가기
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            builder: (context, player) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  player,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
