import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/logger_service.dart';
import '../constants/supabase_constants.dart';

class KakaoLoginWebView extends StatefulWidget {
  final String initialUrl;

  const KakaoLoginWebView({
    super.key,
    required this.initialUrl,
  });

  @override
  State<KakaoLoginWebView> createState() => _KakaoLoginWebViewState();
}

class _KakaoLoginWebViewState extends State<KakaoLoginWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: _handlePageStarted,
          onPageFinished: _handlePageFinished,
          onWebResourceError: _handleWebResourceError,
          onNavigationRequest: _handleNavigationRequest,
        ),
      )
      ..loadRequest(
        Uri.parse(widget.initialUrl),
        headers: _getRequestHeaders(),
      );
  }

  void _handlePageStarted(String url) {
    if (!mounted) return;
    setState(() => _isLoading = true);
  }

  void _handlePageFinished(String url) {
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _handleWebResourceError(WebResourceError error) {
    // 무시해도 되는 에러 목록
    final ignorableErrors = [
      '프레임 로드 중단됨',
      'net::ERR_ABORTED',
      'Frame load interrupted'
    ];

    // 무시해도 되는 에러인 경우 로깅하지 않음
    if (ignorableErrors.contains(error.description)) {
      return;
    }

    // 실제 에러인 경우에만 로깅
    LoggerService.error('웹뷰 에러: ${error.description}', error, null);
  }

  Future<NavigationDecision> _handleNavigationRequest(
      NavigationRequest request) async {
    final url = request.url;

    // Supabase 콜백 URL 처리
    if (url.startsWith('${SupabaseConstants.projectUrl}/auth/v1/callback')) {
      return NavigationDecision.navigate;
    }

    // 앱 스킴 URL 처리
    if (url.startsWith(SupabaseConstants.redirectUrl)) {
      if (_isRedirecting) return NavigationDecision.prevent;
      _isRedirecting = true;

      try {
        await _handleAuthCallback(url);
        return NavigationDecision.prevent;
      } catch (e, stackTrace) {
        _handleError(e, stackTrace);
        return NavigationDecision.prevent;
      } finally {
        _isRedirecting = false;
      }
    }

    return NavigationDecision.navigate;
  }

  Future<void> _handleAuthCallback(String url) async {
    final code = Uri.parse(url).queryParameters['code'];
    if (code == null) throw Exception('인증 코드가 없습니다.');

    Supabase.instance.client.auth.exchangeCodeForSession(code);

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _handleError(Object error, StackTrace? stackTrace) {
    LoggerService.error('세션 생성 중 오류 발생', error, stackTrace);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 처리 중 오류가 발생했습니다.')),
      );
    }
  }

  Map<String, String> _getRequestHeaders() {
    return {
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 상단 드래그 핸들
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 앱바
          Container(
            height: 56,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Stack(
              children: [
                // 닫기 버튼
                Positioned(
                  left: 4,
                  top: 0,
                  bottom: 0,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                    splashRadius: 24,
                  ),
                ),
                // 타이틀
                const Center(
                  child: Text(
                    '카카오 로그인',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 웹뷰
          Expanded(
            child: ClipRRect(
              child: _buildWebView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const ColoredBox(
            color: Colors.white,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.clearCache();
    super.dispose();
  }
}
