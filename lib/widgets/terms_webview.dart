import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TermsWebView extends StatelessWidget {
  final String assetPath;
  final String title;

  const TermsWebView({
    super.key,
    required this.assetPath,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: WebViewWidget(
        controller: WebViewController()
          ..loadFlutterAsset(assetPath)
          ..setJavaScriptMode(JavaScriptMode.unrestricted),
      ),
    );
  }
}
