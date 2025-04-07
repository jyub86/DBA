import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';

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

class _YoutubePlayerScreenState extends State<YoutubePlayerScreen>
    with WidgetsBindingObserver {
  late YoutubePlayerController _controller;
  bool _isFullScreen = false;
  bool _isReady = false;
  Timer? _positionTimer;
  Timer? _pipCheckTimer;
  static const platform = MethodChannel('com.bupyungdongbuchurch.dba/pip');
  bool _isPipModeReady = false;
  bool _isPlaying = false;
  DateTime? _lastLifecycleChange;
  bool _isBeingDisposed = false;
  bool _pipSupported = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 화면 가로 모드 강제
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initPlayer();

    // 초기화 후 약간의 지연을 두고 PIP 모드 준비
    // (화면이 완전히 렌더링된 후에 준비하기 위함)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (Platform.isAndroid) {
        _checkPipSupport();
      }
    });

    // 화면에 포커스가 있는지 확인하는 리스너 추가
    final focusManager = FocusManager.instance;
    focusManager.addListener(() {
      if (!focusManager.primaryFocus!.hasFocus &&
          _isPipModeReady &&
          _isPlaying) {
        debugPrint('화면 포커스 상실 - PIP 모드 시도');
        _enterPipMode();
      }
    });

    // PIP 모드 주기적 체크 타이머 (비디오가 재생 중일 때만 동작)
    _pipCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_controller.value.isPlaying && !_isPlaying) {
        setState(() {
          _isPlaying = true;
        });
        debugPrint('타이머: 재생 상태 true로 업데이트');

        // 재생이 시작될 때 PIP 모드 준비
        if (Platform.isAndroid && !_isPipModeReady) {
          _preparePipMode();
        }
      } else if (!_controller.value.isPlaying && _isPlaying) {
        setState(() {
          _isPlaying = false;
        });
        debugPrint('타이머: 재생 상태 false로 업데이트');
      }
    });

    // 화면 전환 효과가 끝나고 PIP 준비를 위해 추가 지연
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && !_isBeingDisposed) {
        // 키보드 포커스 제거 (숨겨진 문제의 원인이 될 수 있음)
        FocusScope.of(context).unfocus();

        if (Platform.isAndroid) {
          // 강제로 모든 백그라운드 이벤트 핸들러 재확인
          WidgetsBinding.instance
              .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isBeingDisposed) return;

    final now = DateTime.now();
    final lastChangeTime = _lastLifecycleChange;
    _lastLifecycleChange = now;

    // 너무 빈번한 호출 방지 (100ms 이내 재호출 무시)
    if (lastChangeTime != null &&
        now.difference(lastChangeTime).inMilliseconds < 100) {
      debugPrint('너무 빈번한 라이프사이클 변경 - 무시');
      return;
    }

    // 항상 플레이어 상태 재확인
    if (_controller.value.isPlaying != _isPlaying) {
      setState(() {
        _isPlaying = _controller.value.isPlaying;
      });
      debugPrint('라이프사이클 변경: 재생 상태 업데이트 $_isPlaying');
    }

    debugPrint(
        '앱 라이프사이클 상태 변경: $state, PIP 준비상태: $_isPipModeReady, 재생 상태: $_isPlaying');

    // 앱이 백그라운드로 이동할 때 PIP 모드 활성화 시도
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_isPipModeReady && _isPlaying) {
        // 재생 중인 경우에만 PIP 모드 시도
        debugPrint('백그라운드로 이동 - PIP 모드 시도 (상태: $state)');

        // 즉시 시도
        _enterPipMode();

        // 약간의 지연을 두고 여러 번 시도 (일부 기기에서 즉시 호출이 무시될 수 있음)
        for (var i = 1; i <= 3; i++) {
          Future.delayed(Duration(milliseconds: 100 * i), () {
            if (mounted && !_isBeingDisposed) {
              _enterPipMode();
            }
          });
        }
      } else {
        debugPrint('PIP 모드 조건 불충족 - 백그라운드 전환 (상태: $state)');
      }
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('앱이 다시 활성화되었습니다');

      // 앱이 다시 활성화될 때 PIP 모드가 준비되어 있는지 확인
      if (Platform.isAndroid && !_isPipModeReady && _isPlaying) {
        _preparePipMode();
      }
    }
  }

  // PIP 모드 준비 메서드 (네이티브에 플레이어 활성화 알림)
  Future<void> _preparePipMode() async {
    if (Platform.isAndroid && !_isBeingDisposed && _pipSupported) {
      try {
        final bool success = await platform.invokeMethod('preparePipMode');
        debugPrint('PIP 모드 준비 완료: $success');
        if (mounted) {
          setState(() {
            _isPipModeReady = success;
          });
        }
      } catch (e) {
        debugPrint('PIP 모드 준비 실패: $e');
      }
    }
  }

  // PIP 모드 취소 메서드
  Future<void> _cancelPipMode() async {
    if (Platform.isAndroid && !_isBeingDisposed) {
      try {
        final bool success = await platform.invokeMethod('cancelPipMode');
        debugPrint('PIP 모드 취소: $success');
        if (mounted) {
          setState(() {
            _isPipModeReady = false;
          });
        }
      } catch (e) {
        debugPrint('PIP 모드 취소 실패: $e');
      }
    }
  }

  // PIP 모드 진입 메서드
  Future<void> _enterPipMode() async {
    if (Platform.isAndroid &&
        _isPipModeReady &&
        _isPlaying &&
        !_isBeingDisposed &&
        _pipSupported) {
      debugPrint('PIP 모드 진입 시도');
      try {
        final bool result = await platform.invokeMethod('enterPipMode');
        debugPrint('PIP 모드 진입 결과: $result');
        if (!result && mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIP 모드를 지원하지 않는 기기이거나 권한이 없습니다.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        debugPrint('PIP 모드 진입 실패: $e');
        if (mounted && !_isBeingDisposed) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PIP 모드 진입에 실패했습니다. 오류: $e'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      debugPrint(
          'PIP 모드 진입 조건 불충족: Android=${Platform.isAndroid}, Ready=$_isPipModeReady, '
          'Playing=$_isPlaying, Disposed=$_isBeingDisposed, Supported=$_pipSupported');
    }
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

    // 플레이어가 준비되면 로그를 출력
    _controller.addListener(() {
      if (_isBeingDisposed) return;

      // 재생 상태가 변경되면 상태 업데이트
      if (_controller.value.isPlaying != _isPlaying && mounted) {
        setState(() {
          _isPlaying = _controller.value.isPlaying;
        });
        debugPrint('재생 상태 변경: $_isPlaying');

        // 재생 상태가 변경될 때 PIP 모드 준비 상태 업데이트
        if (_isPlaying &&
            Platform.isAndroid &&
            !_isPipModeReady &&
            _pipSupported) {
          _preparePipMode();
        }
      }

      if (_controller.value.isReady && !_isReady && mounted) {
        debugPrint('YouTube 플레이어 준비 완료');
        setState(() {
          _isReady = true;
        });
      }
    });
  }

  // PIP 지원 여부 확인
  Future<void> _checkPipSupport() async {
    if (Platform.isAndroid && !_isBeingDisposed) {
      try {
        final bool isSupported = await platform.invokeMethod('isPipSupported');
        debugPrint('PIP 지원 여부: $isSupported');

        if (isSupported) {
          setState(() {
            _pipSupported = true;
          });
          _preparePipMode();
        } else if (mounted) {
          setState(() {
            _pipSupported = false;
          });
          // PIP를 지원하지 않는 경우 사용자에게 알림
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이 기기는 Picture-in-Picture 모드를 지원하지 않습니다.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        debugPrint('PIP 지원 여부 확인 실패: $e');
      }
    }
  }

  @override
  void dispose() {
    debugPrint('YouTube 플레이어 화면 종료');
    _isBeingDisposed = true;

    // PIP 모드 취소
    _cancelPipMode();

    // 타이머 정리
    _pipCheckTimer?.cancel();
    _positionTimer?.cancel();

    WidgetsBinding.instance.removeObserver(this);

    // 화면 세로 모드로 복원
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isPipModeReady || !_isPlaying,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        if (_isFullScreen) {
          // 전체화면 종료
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
          setState(() {
            _isFullScreen = false;
          });
          return;
        }

        // 안드로이드에서 뒤로가기 시 PIP 모드 시도
        if (Platform.isAndroid &&
            _isPipModeReady &&
            _isPlaying &&
            _pipSupported) {
          debugPrint('뒤로가기 - PIP 모드 시도');
          await _enterPipMode();

          // 약간의 지연 후 PIP 모드가 활성화되지 않으면 화면 종료
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted && !_isBeingDisposed) {
              Navigator.of(context).pop();
            }
          });
        } else {
          // PIP 모드 조건이 맞지 않으면 화면 종료
          Navigator.of(context).pop();
        }
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
                debugPrint('YouTube 플레이어 onReady 콜백');
                // 플레이어가 준비되었을 때 시작 위치로 이동 (한 번만 실행)
                if (widget.startSeconds > 0 && !_isReady) {
                  setState(() {
                    _isReady = true; // 플래그 설정으로 중복 실행 방지
                  });

                  // 약간의 지연 후 시작 위치로 이동
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted && !_isBeingDisposed) {
                      _controller
                          .seekTo(Duration(seconds: widget.startSeconds));
                      _controller.play();
                    }
                  });
                }
              },
              onEnded: (metaData) {
                // 영상이 끝나면 이전 화면으로 돌아가기
                debugPrint('YouTube 영상 재생 종료');
                _cancelPipMode(); // PIP 모드 취소
                if (mounted && !_isBeingDisposed) {
                  Navigator.pop(context);
                }
              },
              topActions: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    debugPrint('뒤로가기 버튼 클릭');
                    _cancelPipMode(); // PIP 모드 취소
                    Navigator.pop(context);
                  },
                ),
                const Spacer(),
                // Android에서만 PIP 모드 버튼 표시
                if (Platform.isAndroid)
                  IconButton(
                    icon: const Icon(Icons.picture_in_picture_alt,
                        color: Colors.white),
                    onPressed: () {
                      debugPrint('PIP 버튼 클릭');
                      _enterPipMode();
                    },
                  ),
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
                    debugPrint('전체화면 종료 버튼 클릭');
                    _cancelPipMode(); // PIP 모드 취소
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
