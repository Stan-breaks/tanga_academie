import 'package:flutter/material.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

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
  bool _isLoading = true;
  bool _isCompleted = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _videoType = 'none'; // 'url', 'vimeo', 'none'

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

    // Priority 1: Check for direct URL (MP4 or M3U8/HLS)
    final url = video['url'];
    
    if (url != null && url.toString().trim().isNotEmpty) {
      await _initializeUrlVideo(url.toString().trim());
      return;
    }

    // Priority 2: Check for Vimeo ID
    final vimeoId = video['vimeoId'];
    if (vimeoId != null && vimeoId.toString().trim().isNotEmpty) {
      await _initializeVimeoVideo(vimeoId.toString().trim());
      return;
    }

    // Priority 3: Check for embed code (extract Vimeo ID)
    final embedCode = video['embedCode'];
    if (embedCode != null && embedCode.toString().isNotEmpty) {
      final extractedId = _extractVimeoId(embedCode.toString());
      if (extractedId != null) {
        await _initializeVimeoVideo(extractedId);
        return;
      }
    }

    // No valid video source found
    setState(() {
      _videoType = 'none';
      _isLoading = false;
      _hasError = true;
      _errorMessage = 'No valid video source found.\n\nAvailable fields: ${video.keys.join(', ')}';
    });
  }

  String? _extractVimeoId(String embedCode) {
    // Extract Vimeo ID from embed code
    final regex = RegExp(r'vimeo\.com/video/(\d+)');
    final match = regex.firstMatch(embedCode);
    return match?.group(1);
  }

  Future<void> _initializeUrlVideo(String url) async {
    try {
      // Validate URL
      if (url.isEmpty) {
        throw Exception('Video URL is empty');
      }

      final fullUrl = url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';
      
      
      setState(() {
        _videoType = 'url';
        _isLoading = true;
        _hasError = false;
      });

      // Validate that it's a proper URL
      final uri = Uri.tryParse(fullUrl);
      if (uri == null) {
        throw Exception('Invalid video URL format: $fullUrl');
      }

      // Initialize video player - supports both MP4 and HLS natively
      _videoController = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      final primaryColor = Theme.of(context).primaryColor;
      await _videoController!.initialize();
      
      
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        // Show playback speed for both HLS and MP4
        playbackSpeeds: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0],
        materialProgressColors: ChewieProgressColors(
          playedColor: primaryColor,
          handleColor: primaryColor,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey.shade300,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error playing video',
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    errorMessage,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
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
          _errorMessage = 'Failed to load video.\n\n${e.toString()}';
        });
      }
    }
  }

  Future<void> _initializeVimeoVideo(String vimeoId) async {
    setState(() {
      _videoType = 'vimeo';
      _isLoading = false;
      _hasError = true;
      _errorMessage = 'Vimeo direct playback not yet implemented.\n\n'
          'Vimeo ID: $vimeoId\n\n'
          'Options:\n'
          '1. Use vimeo_video_player package\n'
          '2. Extract video URL from Vimeo API\n'
          '3. Use WebView (original implementation)';
    });
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

    if (_hasError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error loading video',
                style: TextStyle(color: Colors.grey.shade300, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
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
              Icon(
                Icons.videocam_off,
                size: 64,
                color: Colors.grey.shade700,
              ),
              const SizedBox(height: 16),
              Text(
                'No video available',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_chewieController != null) {
      return Chewie(controller: _chewieController!);
    }

    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
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
