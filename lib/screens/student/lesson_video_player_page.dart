import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:tanga_acadamie/api_config.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io' show Platform;

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
  WebViewController? _webViewController;
  bool _isLoading = true;
  bool _isCompleted = false;
  String _videoType = 'none'; // 'vimeo', 'video', 'none'

  @override
  void initState() {
    super.initState();
    _initializeVideo();
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

    // Priority 1: Check for Vimeo (vimeoId or embedCode)
    if (video['vimeoId'] != null || video['embedCode'] != null) {
      _initializeVimeo(video);
      return;
    }

    // Priority 2: Check for URL (MP4 or M3U8)
    final url = video['url'];
    
    if (url != null && url.toString().isNotEmpty) {
      _initializeWebViewVideo(url.toString());
      return;
    }

    setState(() {
      _videoType = 'none';
      _isLoading = false;
    });
  }

  void _initializeVimeo(Map<String, dynamic> video) {
    // Check if platform supports WebView
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      setState(() {
        _videoType = 'none';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _videoType = 'vimeo';
      _isLoading = false;
    });

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadHtmlString(_getVimeoHtml(video));
  }

  void _initializeWebViewVideo(String url) {
    final fullUrl = url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';

    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      setState(() {
        _videoType = 'none';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _videoType = 'video';
      _isLoading = false;
    });

    // Determine if it's HLS or MP4
    final isHls = url.contains('.m3u8');
    
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadHtmlString(_getVideoPlayerHtml(fullUrl, isHls));
  }

  String _getVimeoHtml(Map<String, dynamic> video) {
    String vimeoContent;
    
    if (video['embedCode'] != null) {
      vimeoContent = video['embedCode'];
    } else if (video['vimeoId'] != null) {
      vimeoContent = '''
        <iframe 
          src="https://player.vimeo.com/video/${video['vimeoId']}?autoplay=0" 
          width="100%" 
          height="100%" 
          frameborder="0" 
          allow="autoplay; fullscreen; picture-in-picture" 
          allowfullscreen>
        </iframe>
      ''';
    } else {
      vimeoContent = '<p style="color: white;">No video available</p>';
    }

    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          * { margin: 0; padding: 0; }
          body { background: #000; }
          iframe { 
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
          }
        </style>
      </head>
      <body>
        $vimeoContent
      </body>
      </html>
    ''';
  }

  String _getVideoPlayerHtml(String videoUrl, bool isHls) {
    if (isHls) {
      // HLS video player using hls.js
      return '''
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            * { margin: 0; padding: 0; }
            body { 
              background: #000; 
              display: flex;
              justify-content: center;
              align-items: center;
              height: 100vh;
            }
            video {
              width: 100%;
              height: 100%;
              object-fit: contain;
            }
          </style>
          <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
        </head>
        <body>
          <video id="video" controls playsinline></video>
          <script>
            var video = document.getElementById('video');
            var videoSrc = '$videoUrl';
            
            if (Hls.isSupported()) {
              var hls = new Hls({
                debug: false,
                enableWorker: true,
                lowLatencyMode: true,
                backBufferLength: 90
              });
              hls.loadSource(videoSrc);
              hls.attachMedia(video);
              hls.on(Hls.Events.MANIFEST_PARSED, function() {
                console.log('HLS manifest loaded');
              });
              hls.on(Hls.Events.ERROR, function(event, data) {
                console.error('HLS error:', data);
              });
            } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
              // For Safari/iOS native HLS support
              video.src = videoSrc;
            } else {
              console.error('HLS not supported');
            }
          </script>
        </body>
        </html>
      ''';
    } else {
      // Regular MP4 video player
      return '''
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            * { margin: 0; padding: 0; }
            body { 
              background: #000; 
              display: flex;
              justify-content: center;
              align-items: center;
              height: 100vh;
            }
            video {
              width: 100%;
              height: 100%;
              object-fit: contain;
            }
          </style>
        </head>
        <body>
          <video id="video" controls playsinline>
            <source src="$videoUrl" type="video/mp4">
            Your browser does not support the video tag.
          </video>
          <script>
            var video = document.getElementById('video');
            video.addEventListener('error', function(e) {
              console.error('Video error:', e);
            });
            video.addEventListener('loadedmetadata', function() {
              console.log('Video loaded successfully');
            });
          </script>
        </body>
        </html>
      ''';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.lesson['title'] ?? 'Lesson',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          // Video Player Section
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildVideoPlayer(),
          ),
          
          // Lesson Content Section
          Expanded(
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lesson Info
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.chapter['title'] ?? 'Chapter',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.lesson['title'] ?? 'Lesson',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Video Duration
                          if (widget.lesson['video']?['duration'] != null)
                            Row(
                              children: [
                                Icon(Icons.access_time, 
                                  size: 18, 
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _formatDuration(widget.lesson['video']['duration']),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    
                    const Divider(height: 1),
                    
                    // Mark Complete Button
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isCompleted ? null : () {
                            setState(() {
                              _isCompleted = true;
                            });
                            widget.onComplete?.call();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Lesson marked as complete!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          icon: Icon(_isCompleted ? Icons.check_circle : Icons.check_circle_outline),
                          label: Text(_isCompleted ? 'Completed' : 'Mark as Complete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isCompleted ? Colors.green : Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Quiz Button (if available)
                    if (widget.lesson['quiz'] != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // Navigate to quiz
                            },
                            icon: const Icon(Icons.quiz),
                            label: const Text('Take Quiz'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.orange.shade400, width: 2),
                              foregroundColor: Colors.orange.shade700,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    
                    const Divider(height: 1),
                    
                    // Navigation Buttons
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          if (widget.onPrevious != null)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: widget.onPrevious,
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Previous'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          if (widget.onPrevious != null && widget.onNext != null)
                            const SizedBox(width: 12),
                          if (widget.onNext != null)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: widget.onNext,
                                label: const Text('Next Lesson'),
                                icon: const Icon(Icons.arrow_forward),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
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
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_videoType == 'none') {
      return _buildNoVideoPlaceholder();
    }

    // Both Vimeo and regular videos use WebView
    return WebViewWidget(controller: _webViewController!);
  }

  Widget _buildNoVideoPlaceholder() {
    final isDesktop = !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
    
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off,
              size: 64,
              color: Colors.grey.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              isDesktop 
                ? 'Video player not supported on desktop\nPlease test on Android, iOS, or Web'
                : 'No video available',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 16,
              ),
            ),
            if (isDesktop) ...[
              const SizedBox(height: 12),
              Text(
                'Run: flutter run -d chrome',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(dynamic duration) {
    if (duration == null) return '';
    final minutes = (duration / 60).floor();
    final seconds = (duration % 60).floor();
    return '$minutes:${seconds.toString().padLeft(2, '0')} min';
  }
}

