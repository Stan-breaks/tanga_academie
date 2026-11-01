import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// The in-app support chat.
///
/// The chat itself is a web app hosted by our chatbot provider. It is rendered
/// inside a WebView, so any WebView failure (TLS/certificate rejection, DNS,
/// WebKit content-process crash, ...) used to leave the user looking at a
/// silent blank screen. This screen now surfaces those failures, retries the
/// recoverable ones, and offers an "open in browser" fallback.
class TangaChatScreen extends StatefulWidget {
  const TangaChatScreen({super.key, this.name, this.email});

  final String? name, email;

  @override
  State<TangaChatScreen> createState() => _TangaChatScreenState();
}

class _TangaChatScreenState extends State<TangaChatScreen> {
  static const String _chatHost = 'app.expressdesignagency.com';
  static const String _chatPath = '/chat/ed_Oihex0F5GteB';
  static const Color _pageBackground = Color(0xFFF7F4F0);

  late final Uri _chatUri;
  late final WebViewController _controller;

  bool _isLoading = true;
  int _progress = 0;
  String? _errorMessage;
  bool _isCertificateError = false;
  bool _loadStarted = false;
  int _contentProcessRetries = 0;
  Timer? _blankCheckTimer;
  Timer? _loadTimeoutTimer;

  @override
  void initState() {
    super.initState();

    _chatUri = Uri.https(_chatHost, _chatPath, {
      if (widget.name != null && widget.name!.isNotEmpty) 'name': widget.name!,
      if (widget.email != null && widget.email!.isNotEmpty)
        'email': widget.email!,
      // Keep the bot in the same language as the app (French by default),
      // even when the phone itself is set to another language.
      'lang': currentLanguage,
    });

    _controller = _createController();

    // Loading before the UIKit view has a real frame can give WKWebView a
    // zero-sized viewport on iOS (the full-page chat then renders 0px high,
    // i.e. blank). Starting on the first post-frame callback makes sure the
    // platform view already has its final size.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadChat();
    });
  }

  @override
  void dispose() {
    _blankCheckTimer?.cancel();
    _loadTimeoutTimer?.cancel();
    super.dispose();
  }

  WebViewController _createController() {
    final PlatformWebViewControllerCreationParams params;
    if (Platform.isIOS) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_pageBackground)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (_) {
            if (!mounted) return;
            _blankCheckTimer?.cancel();
            _startLoadTimeout();
            setState(() {
              _isLoading = true;
              _progress = 0;
              _errorMessage = null;
              _isCertificateError = false;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            _loadTimeoutTimer?.cancel();
            setState(() => _isLoading = false);
            _scheduleBlankCheck();
          },
          onWebResourceError: _handleWebResourceError,
          onHttpError: (error) {
            debugPrint(
              '[TangaChat] HTTP ${error.response?.statusCode} '
              '${error.request?.uri}',
            );
          },
          onNavigationRequest: _handleNavigationRequest,
        ),
      );

    // Note: certificate rejections also arrive through onWebResourceError
    // (failedSslHandshake), which is handled below. iOS shows a blank WKWebView
    // (not an error page) for those, so surfacing that error is what turns the
    // silent blank screen into an explanation.

    return controller;
  }

  Future<void> _loadChat() async {
    _loadStarted = true;
    _startLoadTimeout();
    try {
      await _controller.loadRequest(_chatUri);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = isFr
            ? 'Le module de discussion n’a pas pu démarrer.'
            : 'The chat module could not be started.';
      });
    }
  }

  void _startLoadTimeout() {
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = Timer(const Duration(seconds: 25), () {
      if (!mounted || !_isLoading) return;
      _showError(
        isFr
            ? 'Le service d’assistance met trop de temps à répondre. '
                  'Vérifiez votre connexion internet puis réessayez.'
            : 'The support service is taking too long to respond. '
                  'Check your internet connection and try again.',
      );
    });
  }

  void _handleWebResourceError(WebResourceError error) {
    if (!mounted) return;

    final type = error.errorType;
    final code = error.errorCode;
    final isIos = Platform.isIOS;

    // The iOS implementation reports NSURLError codes and leaves errorType
    // null for network/TLS failures, so both forms have to be handled.
    // https://developer.apple.com/documentation/foundation/nsurlerrordomain
    const iosCertificateCodes = <int>{
      -1200, // NSURLErrorSecureConnectionFailed
      -1201, // NSURLErrorServerCertificateHasBadDate
      -1202, // NSURLErrorServerCertificateUntrusted
      -1203, // NSURLErrorServerCertificateNotYetValid
      -1204, // NSURLErrorClientCertificateRejected
      -1205, // NSURLErrorClientCertificateRequired
      -1020, // NSURLErrorAppTransportSecurityRequiresSecureConnection
    };
    const iosConnectionCodes = <int>{
      -1001, // NSURLErrorTimedOut
      -1003, // NSURLErrorCannotFindHost
      -1004, // NSURLErrorCannotConnectToHost
      -1005, // NSURLErrorNetworkConnectionLost
      -1009, // NSURLErrorNotConnectedToInternet
    };

    final isCertificateError =
        type == WebResourceErrorType.failedSslHandshake ||
        (isIos && iosCertificateCodes.contains(code));
    final isConnectionError =
        type == WebResourceErrorType.connect ||
        type == WebResourceErrorType.hostLookup ||
        type == WebResourceErrorType.timeout ||
        type == WebResourceErrorType.io ||
        (isIos && iosConnectionCodes.contains(code));

    // A terminated WebKit content process leaves a white WKWebView. Try to
    // recover automatically once before showing the error state.
    if (type == WebResourceErrorType.webContentProcessTerminated) {
      if (_contentProcessRetries == 0) {
        _contentProcessRetries++;
        _controller.reload();
        return;
      }
      _showError(
        isFr
            ? 'Le module de discussion a planté. Touchez « Réessayer ».'
            : 'The chat module crashed. Tap “Retry”.',
      );
      return;
    }

    // A rejected certificate is the classic silent-blank cause on iOS.
    if (isCertificateError) {
      _isCertificateError = true;
      _showError(
        isFr
            ? 'La connexion sécurisée à l’assistance a échoué '
                  '(certificat TLS du site).'
            : 'The secure connection to support failed '
                  '(website TLS certificate).',
        technicalDetail: '${error.errorCode}: ${error.description}',
      );
      return;
    }

    // Only treat connection problems as fatal while the main page is loading.
    // Sub-resource errors (fonts, images, analytics) must not blank the chat.
    if (_isLoading && isConnectionError) {
      _showError(
        isFr
            ? 'Impossible de joindre l’assistance. '
                  'Vérifiez votre connexion internet puis réessayez.'
            : 'Unable to reach support. Check your internet connection '
                  'and try again.',
        technicalDetail: '${error.errorCode}: ${error.description}',
      );
    }
  }

  void _showError(String message, {String? technicalDetail}) {
    if (!mounted) return;
    _blankCheckTimer?.cancel();
    _loadTimeoutTimer?.cancel();
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
    if (technicalDetail != null) {
      debugPrint('[TangaChat] WebView error: $technicalDetail');
    }
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;

    // The chat page and the browser-internal URLs WKWebView uses while it
    // boots (about:blank, data:, blob:) must never be blocked: cancelling the
    // first navigation is another way to end up with an empty iOS WebView.
    if (uri.host == _chatHost ||
        uri.scheme == 'about' ||
        uri.scheme == 'data' ||
        uri.scheme == 'blob') {
      return NavigationDecision.navigate;
    }

    // Anything else (WhatsApp, the provider's site, ...) opens in the phone's
    // browser instead of replacing the chat inside the WebView.
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
    }
    return NavigationDecision.prevent;
  }

  /// The page is a small loader that injects the actual chat into a shadow
  /// root. If that never happens we would otherwise keep showing a blank page.
  /// This check turns that case into a visible, retryable error, and also
  /// repairs the full-page panel if iOS gave it a zero height.
  void _scheduleBlankCheck() {
    _blankCheckTimer?.cancel();
    _blankCheckTimer = Timer(const Duration(seconds: 10), () async {
      if (!mounted || _errorMessage != null) return;
      final Object result;
      try {
        result = await _controller.runJavaScriptReturningResult('''
          (function () {
            var host = document.getElementById('edcb-root');
            if (!host) return 'missing';
            if (!host.shadowRoot) return 'no-shadow';
            var panel = host.shadowRoot.querySelector('.panel');
            if (!panel) return 'missing-panel';
            var rect = panel.getBoundingClientRect();
            if (rect.height < 100) {
              // iOS sometimes keeps the full-page panel at zero height when
              // the WebView viewport was not ready. Restore a usable height.
              panel.style.setProperty('height', window.innerHeight + 'px', 'important');
              panel.style.setProperty('width', '100vw', 'important');
              return 'repaired';
            }
            return 'ok';
          })();
        ''');
      } catch (_) {
        return;
      }

      final value = result.toString().replaceAll('"', '');
      if (value != 'ok' && value != 'repaired' && mounted) {
        _showError(
          isFr
              ? 'Le module de discussion n’a pas pu s’afficher. '
                    'Touchez « Réessayer ».'
              : 'The chat module could not be displayed. Tap “Retry”.',
          technicalDetail: 'blank check: $value',
        );
      }
    });
  }

  Future<void> _retry() async {
    _contentProcessRetries = 0;
    _blankCheckTimer?.cancel();
    _loadTimeoutTimer?.cancel();
    setState(() {
      _errorMessage = null;
      _isCertificateError = false;
      _isLoading = true;
      _progress = 0;
    });
    if (!_loadStarted) {
      await _loadChat();
    } else {
      await _controller.reload();
    }
  }

  Future<void> _openInBrowser() async {
    final launched = await launchUrl(
      _chatUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFr
                ? 'Impossible d’ouvrir le navigateur.'
                : 'Could not open the browser.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        title: Text(
          isFr ? 'Assistance Tanga Académie' : 'Tanga Academie Support',
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: isFr ? 'Recharger' : 'Reload',
            onPressed: _retry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: WebViewWidget(controller: _controller)),
            if (_isLoading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _progress > 0 && _progress < 100
                      ? _progress / 100
                      : null,
                  minHeight: 2,
                  color: AppColors.primary,
                  backgroundColor: AppColors.primary.withAlpha(25),
                ),
              ),
            if (_errorMessage != null)
              Positioned.fill(child: _buildErrorState()),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: _pageBackground,
      padding: const EdgeInsets.all(28),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.error50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isCertificateError
                      ? Icons.lock_outline_rounded
                      : Icons.support_agent_rounded,
                  color: AppColors.error600,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isFr
                    ? 'Assistance momentanément indisponible'
                    : 'Support temporarily unavailable',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: Text(isFr ? 'Réessayer' : 'Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _openInBrowser,
                icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                label: Text(
                  isFr ? 'Ouvrir dans le navigateur' : 'Open in browser',
                ),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
