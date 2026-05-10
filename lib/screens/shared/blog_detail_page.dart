import 'package:flutter/material.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/models/blog.dart';
import 'package:tanga_acadamie/services/blog_service.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';

/// Full-screen blog reading page.
/// Receives a slug to fetch content, and optional preview data for instant display.
class BlogDetailPage extends StatefulWidget {
  final String slug;
  final String? previewTitle;
  final String? previewImage;

  const BlogDetailPage({
    super.key,
    required this.slug,
    this.previewTitle,
    this.previewImage,
  });

  @override
  State<BlogDetailPage> createState() => _BlogDetailPageState();
}

class _BlogDetailPageState extends State<BlogDetailPage> {
  late Future<Blog> _blogFuture;

  @override
  void initState() {
    super.initState();
    _blogFuture = BlogService.fetchBlogBySlug(widget.slug);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: FutureBuilder<Blog>(
        future: _blogFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          } else if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }
          return _buildContent(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    final previewImageUrl = widget.previewImage != null
        ? ApiConfig.getImageUrl(widget.previewImage)
        : null;

    return CustomScrollView(
      slivers: [
        _buildAppBar(
          title: widget.previewTitle ?? '',
          imageUrl: previewImageUrl,
        ),
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: Colors.blueAccent,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  isFr ? 'Chargement de l\'article...' : 'Loading article...',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(title: isFr ? 'Erreur' : 'Error'),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 56, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    isFr
                        ? 'Impossible de charger l\'article'
                        : 'Could not load article',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _blogFuture = BlogService.fetchBlogBySlug(widget.slug);
                      });
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(isFr ? 'Réessayer' : 'Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(Blog blog) {
    final imageUrl = ApiConfig.getImageUrl(blog.coverImage);
    final hasImage = imageUrl.isNotEmpty;

    return CustomScrollView(
      slivers: [
        _buildAppBar(
          title: blog.title,
          imageUrl: hasImage ? imageUrl : null,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category badge
                if (blog.category.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      blog.category,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueAccent.shade700,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),

                // Title
                Text(
                  blog.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Author info row
                _buildAuthorRow(blog),
                const SizedBox(height: 14),

                // Stats row
                _buildStatsRow(blog),
                const SizedBox(height: 8),

                const Divider(height: 32),

                // Tags
                if (blog.tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: blog.tags
                        .map((tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                '#$tag',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),

        // Blog content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            child: _buildRenderedContent(blog.content),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthorRow(Blog blog) {
    final authorImageUrl =
        blog.author?.profile != null
            ? ApiConfig.getImageUrl(blog.author!.profile)
            : '';
    final hasAuthorImage = authorImageUrl.isNotEmpty;

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.blueAccent.shade100,
          backgroundImage:
              hasAuthorImage ? NetworkImage(authorImageUrl) : null,
          child: !hasAuthorImage
              ? Icon(Icons.person, size: 20, color: Colors.blueAccent.shade700)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                blog.author?.fullName ?? (isFr ? 'Anonyme' : 'Anonymous'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (blog.author?.skill != null &&
                  blog.author!.skill!.isNotEmpty)
                Text(
                  blog.author!.skill!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(Blog blog) {
    final date = _formatDate(blog.createdAt);
    return Row(
      children: [
        Icon(Icons.calendar_today_outlined,
            size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          date,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 20),
        Icon(Icons.visibility_outlined,
            size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          '${blog.views} ${isFr ? 'vues' : 'views'}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 20),
        Icon(Icons.timer_outlined, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          _estimateReadTime(blog.content),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  /// Renders blog content as styled text paragraphs.
  /// Handles basic HTML-like content by stripping tags and splitting into paragraphs.
  Widget _buildRenderedContent(String content) {
    if (content.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            isFr ? 'Aucun contenu disponible' : 'No content available',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ),
      );
    }

    // Strip HTML tags for plain text rendering
    final plainText = content
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<p[^>]*>'), '\n')
        .replaceAll(RegExp(r'</p>'), '\n')
        .replaceAll(RegExp(r'<h[1-6][^>]*>'), '\n\n')
        .replaceAll(RegExp(r'</h[1-6]>'), '\n')
        .replaceAll(RegExp(r'<li[^>]*>'), '\n• ')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    final paragraphs =
        plainText.split(RegExp(r'\n\n+')).where((p) => p.trim().isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((para) {
        final trimmed = para.trim();
        // Detect heading-like paragraphs (short, no period, starts uppercase)
        final isHeading = trimmed.length < 80 &&
            !trimmed.endsWith('.') &&
            trimmed.isNotEmpty &&
            trimmed[0] == trimmed[0].toUpperCase();

        return Padding(
          padding: EdgeInsets.only(bottom: isHeading ? 8 : 16),
          child: Text(
            trimmed,
            style: TextStyle(
              fontSize: isHeading ? 18 : 15,
              fontWeight: isHeading ? FontWeight.bold : FontWeight.normal,
              height: 1.7,
              color: isHeading ? Colors.black87 : Colors.grey.shade800,
            ),
          ),
        );
      }).toList(),
    );
  }

  SliverAppBar _buildAppBar({String? title, String? imageUrl}) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: Colors.blueAccent.shade700,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(40),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          title ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _buildHeaderPlaceholder(),
              )
            else
              _buildHeaderPlaceholder(),
            // Dark gradient overlay for readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(150),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blueAccent.shade200,
            Colors.blueAccent.shade700,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.article_outlined,
          size: 60,
          color: Colors.white.withAlpha(120),
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoDate);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  String _estimateReadTime(String content) {
    final words = content
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    final minutes = (words / 200).ceil();
    if (minutes <= 1) return isFr ? '1 min de lecture' : '1 min read';
    return isFr ? '$minutes min de lecture' : '$minutes min read';
  }
}
