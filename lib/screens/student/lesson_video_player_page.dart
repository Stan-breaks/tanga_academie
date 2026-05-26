import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/screens/student/student_quiz_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class LessonVideoPlayerPage extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final Map<String, dynamic> chapter;
  final String courseId;
  final VoidCallback? onComplete;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const LessonVideoPlayerPage({
    super.key,
    required this.lesson,
    required this.chapter,
    required this.courseId,
    this.onComplete,
    this.onNext,
    this.onPrevious,
  });

  @override
  State<LessonVideoPlayerPage> createState() => _LessonVideoPlayerPageState();
}

class _LessonVideoPlayerPageState extends State<LessonVideoPlayerPage> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  String? _vimeoId;
  bool _isLoading = true;
  bool _isCompleted = false;
  bool _isMarkingComplete = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _videoType = 'none';

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _initializeVideo() async {
    final video = widget.lesson['video'];

    if (video == null) {
      setState(() {
        _videoType = 'none';
        _isLoading = false;
      });
      return;
    }

    final url = video['url'];
    final vimeoId = video['vimeoId'];
    final embedCode = video['embedCode'];

    String? videoVimeoId;

    // Check url for vimeo
    if (url != null && url.toString().contains('vimeo')) {
      videoVimeoId = _extractVimeoId(url.toString());
    }

    // Check embedCode for vimeo
    if (videoVimeoId == null &&
        embedCode != null &&
        embedCode.toString().contains('vimeo')) {
      videoVimeoId = _extractVimeoId(embedCode.toString());
    }

    // Use direct vimeoId
    if (videoVimeoId == null &&
        vimeoId != null &&
        vimeoId.toString().trim().isNotEmpty) {
      videoVimeoId = vimeoId.toString().trim();
    }

    // If we have vimeoId, use vimeo player
    if (videoVimeoId != null && videoVimeoId.isNotEmpty) {
      setState(() {
        _videoType = 'vimeo';
        _vimeoId = videoVimeoId;
        _isLoading = false;
      });
      return;
    }

    // Direct video URL (non-vimeo)
    if (url != null && url.toString().trim().isNotEmpty) {
      await _initializeUrlVideo(url.toString().trim());
      return;
    }

    // Fallback to embedCode if not vimeo
    if (embedCode != null && embedCode.toString().trim().isNotEmpty) {
      await _initializeUrlVideo(embedCode.toString().trim());
      return;
    }

    setState(() {
      _videoType = 'none';
      _isLoading = false;
      _hasError = true;
      _errorMessage = isFr ? 'Aucune source vidéo valide trouvée.' : 'No valid video source found.';
    });
  }

  String? _extractVimeoId(String embedCode) {
    final regex = RegExp(r'vimeo\.com/video/(\d+)');
    final match = regex.firstMatch(embedCode);
    return match?.group(1);
  }

  Future<void> _initializeUrlVideo(String url) async {
    try {
      if (url.isEmpty) {
        throw Exception('Video URL is empty');
      }

      final fullUrl = url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';

      setState(() {
        _videoType = 'url';
        _isLoading = true;
        _hasError = false;
      });

      final uri = Uri.tryParse(fullUrl);
      if (uri == null) {
        throw Exception('Invalid video URL format');
      }

      _videoController = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        playbackSpeeds: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0],
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blueAccent,
          handleColor: Colors.blueAccent,
          backgroundColor: Colors.grey.shade600,
          bufferedColor: Colors.grey.shade400,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.blueAccent,
              strokeWidth: 3,
            ),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
                const SizedBox(height: 16),
                Text(
                  isFr ? 'Erreur de lecture vidéo' : 'Error playing video',
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 16),
                ),
              ],
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = isFr ? 'Échec du chargement de la vidéo' : 'Failed to load video';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.black,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          widget.lesson['title'] ?? 'Lesson',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_chewieController != null)
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white70),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isFr ? 'Paramètres vidéo' : 'Video settings'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Video Player Section
          AspectRatio(aspectRatio: 16 / 9, child: _buildVideoPlayer()),

          // Lesson Content Section
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle indicator
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Lesson Info
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withAlpha(25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.chapter['title'] ?? 'Chapter',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.lesson['title'] ?? 'Lesson',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Video Duration
                          if (widget.lesson['video']?['duration'] != null)
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.access_time,
                                    size: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _formatDuration(
                                    widget.lesson['video']['duration'],
                                  ),
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    Divider(height: 1, color: Colors.grey.shade200),

                    // Action Buttons
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Mark Complete Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: (_isCompleted || _isMarkingComplete)
                                  ? null
                                  : () async {
                                      setState(() => _isMarkingComplete = true);
                                      try {
                                        final token = await getToken();
                                        if (token == null) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(isFr ? 'Non authentifié' : 'Not authenticated'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          setState(() => _isMarkingComplete = false);
                                          return;
                                        }
                                        final videoId =
                                            widget.lesson['video']?['_id']?.toString() ??
                                            widget.lesson['video']?['id']?.toString() ??
                                            widget.lesson['_id']?.toString() ??
                                            widget.lesson['id']?.toString() ?? '';
                                        final chapterId =
                                            widget.chapter['_id']?.toString() ??
                                            widget.chapter['id']?.toString() ?? '';
                                        final response = await post(
                                          Uri.parse(
                                            '${ApiConfig.baseUrl}/api/progress/complete-video',
                                          ),
                                          headers: {
                                            "Authorization": "Bearer $token",
                                            "Content-Type": "application/json",
                                          },
                                          body: jsonEncode({
                                            "videoId": videoId,
                                            "chapterId": chapterId,
                                          }),
                                        );
                                        if (!context.mounted) return;
                                        if (response.statusCode == 200 || response.statusCode == 201) {
                                          setState(() {
                                            _isCompleted = true;
                                            _isMarkingComplete = false;
                                          });
                                          widget.onComplete?.call();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(Icons.check_circle, color: Colors.white),
                                                  const SizedBox(width: 12),
                                                  Text(isFr ? 'Leçon terminée !' : 'Lesson completed!'),
                                                ],
                                              ),
                                              backgroundColor: Colors.green.shade600,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          );
                                        } else {
                                          setState(() => _isMarkingComplete = false);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(isFr ? 'Échec de la mise à jour' : 'Failed to mark complete'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) setState(() => _isMarkingComplete = false);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(isFr ? 'Erreur réseau' : 'Network error'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                              icon: _isMarkingComplete
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : Icon(
                                      _isCompleted
                                          ? Icons.check_circle
                                          : Icons.check_circle_outline,
                                      size: 22,
                                    ),
                              label: Text(
                                isFr
                                    ? (_isCompleted
                                          ? 'Terminé'
                                          : 'Marquer comme terminé')
                                    : (_isCompleted
                                          ? 'Completed'
                                          : 'Mark as Complete'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isCompleted
                                    ? Colors.green
                                    : Colors.blueAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),

                          // Quiz Button (if available)
                          if (widget.lesson['quiz'] != null) ...[
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StudentQuizPage(
                                        lesson: widget.lesson,
                                        chapter: widget.chapter,
                                        courseId: widget.courseId,
                                        onCompleted: widget.onComplete,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.quiz, size: 22),
                                label: Text(
                                  isFr ? 'Passer le quiz' : 'Take Quiz',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  side: BorderSide(
                                    color: Colors.orange.shade400,
                                    width: 2,
                                  ),
                                  foregroundColor: Colors.orange.shade600,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    Divider(height: 1, color: Colors.grey.shade200),

                    // Navigation Buttons
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          if (widget.onPrevious != null)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: widget.onPrevious,
                                icon: const Icon(Icons.arrow_back, size: 20),
                                label: Text(isFr ? 'Précédent' : 'Previous'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: BorderSide(color: Colors.grey.shade400),
                                  foregroundColor: Colors.grey.shade700,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          if (widget.onPrevious != null &&
                              widget.onNext != null)
                            const SizedBox(width: 14),
                          if (widget.onNext != null)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: widget.onNext,
                                label: Text(
                                  isFr ? 'Leçon suivante' : 'Next Lesson',
                                ),
                                icon: const Icon(Icons.arrow_forward, size: 20),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.blueAccent,
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (_hasError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  color: Colors.red.shade400,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isFr ? 'Erreur de chargement vidéo' : 'Error loading video',
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_videoType == 'none') {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.videocam_off,
                  size: 48,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isFr ? 'Aucune vidéo disponible' : 'No video available',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isFr
                    ? 'Cette leçon contient uniquement du texte'
                    : 'This lesson has text content only',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_videoType == 'vimeo' && _vimeoId != null) {
      if (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows) {
        final vimeoUrl = Uri.parse('https://vimeo.com/${_vimeoId!}');
        return Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_circle_outline, color: Colors.white70, size: 64),
                const SizedBox(height: 16),
                Text(
                  isFr ? 'Vidéo Vimeo' : 'Vimeo Video',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () =>
                      launchUrl(vimeoUrl, mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_browser),
                  label: Text(isFr ? 'Ouvrir dans le navigateur' : 'Open in browser'),
                ),
              ],
            ),
          ),
        );
      }
      return _buildVimeoWebView(_vimeoId!);
    }

    if (_chewieController != null) {
      return Chewie(controller: _chewieController!);
    }

    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.blueAccent,
          strokeWidth: 3,
        ),
      ),
    );
  }

  Widget _buildVimeoWebView(String vimeoId) {
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
      ..setBackgroundColor(Colors.black)
      ..loadHtmlString('''
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { background: #000; width: 100%; height: 100%; }
            .container { position: relative; width: 100%; height: 100vh; }
            iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: 0; }
          </style>
        </head>
        <body>
          <div class="container">
            <iframe
              src="https://player.vimeo.com/video/$vimeoId?autoplay=0&playsinline=1&title=0&byline=0&portrait=0"
              allow="autoplay; fullscreen; picture-in-picture; clipboard-write; encrypted-media"
              allowfullscreen>
            </iframe>
          </div>
        </body>
        </html>
      ''');

    return WebViewWidget(controller: controller);
  }

  String _formatDuration(dynamic duration) {
    if (duration == null) return '';
    final minutes = (duration / 60).floor();
    final seconds = (duration % 60).floor();
    if (minutes > 0) {
      return '$minutes min ${seconds > 0 ? '$seconds sec' : ''}';
    }
    return '$seconds sec';
  }
}
