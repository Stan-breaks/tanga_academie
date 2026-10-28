import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TangaChatScreen extends StatefulWidget {
  const TangaChatScreen({super.key, this.name, this.email});

  final String? name, email;

  @override
  State<TangaChatScreen> createState() => _TangaChatScreenState();
}

class _TangaChatScreenState extends State<TangaChatScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    final uri = Uri.https('app.expressdesignagency.com', '/chat/ed_Oihex0F5GteB', {
      if (widget.name != null && widget.name!.isNotEmpty) 'name': widget.name!,
      if (widget.email != null && widget.email!.isNotEmpty) 'email': widget.email!,
    });

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (req) {
            final u = Uri.parse(req.url);
            if (u.host == 'app.expressdesignagency.com') {
              return NavigationDecision.navigate;
            }
            launchUrl(u, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistance Tanga Académie'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
