import 'package:flutter/material.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/models/blog.dart';
import 'package:tanga_acadamie/services/admin_blog_service.dart';
import 'package:tanga_acadamie/screens/admin/admin_blog_form_page.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';

class AdminBlogsPage extends StatefulWidget {
  const AdminBlogsPage({super.key});

  @override
  State<AdminBlogsPage> createState() => _AdminBlogsPageState();
}

class _AdminBlogsPageState extends State<AdminBlogsPage> {
  String _selectedStatus = 'all';
  List<Blog> _blogs = [];
  bool _isLoading = true;
  String? _error;

  List<Map<String, String>> get _statusFilters => [
    {'id': 'all', 'label': isFr ? 'Tous' : 'All'},
    {'id': 'published', 'label': isFr ? 'Publiés' : 'Published'},
    {'id': 'draft', 'label': isFr ? 'Brouillons' : 'Drafts'},
    {'id': 'archived', 'label': isFr ? 'Archivés' : 'Archived'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchBlogs();
  }

  Future<void> _fetchBlogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await AdminBlogService.fetchAllBlogs(
        status: _selectedStatus == 'all' ? null : _selectedStatus,
        limit: 50,
      );
      setState(() {
        _blogs = result['blogs'] as List<Blog>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  int _getStatusCount(String status) {
    if (status == 'all') return _blogs.length;
    return _blogs.where((b) => b.status == status).length;
  }

  List<Blog> get _filteredBlogs {
    if (_selectedStatus == 'all') return _blogs;
    return _blogs.where((b) => b.status == _selectedStatus).toList();
  }

  Future<void> _deleteBlog(String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFr ? 'Supprimer l\'article' : 'Delete Blog'),
        content: Text(
          isFr
              ? 'Êtes-vous sûr de vouloir supprimer "$title" ?'
              : 'Are you sure you want to delete "$title"?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isFr ? 'Annuler' : 'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(isFr ? 'Supprimer' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await AdminBlogService.deleteBlog(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFr
                  ? 'Article supprimé avec succès'
                  : 'Blog deleted successfully',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      _fetchBlogs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${isFr ? 'Erreur' : 'Error'}: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _navigateToForm({Blog? blog}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminBlogFormPage(blog: blog)),
    );
    if (result == true) {
      _fetchBlogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isFr ? 'Gérer les articles' : 'Manage Blogs'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      backgroundColor: Colors.grey.shade50,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(),
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.add),
        label: Text(isFr ? 'Nouveau' : 'New Blog'),
      ),
      body: Column(
        children: [
          _buildStatusFilterBar(),
          Expanded(
            child: RefreshIndicator(
              color: Colors.blueAccent,
              onRefresh: _fetchBlogs,
              child: _isLoading
                  ? _buildLoadingState()
                  : _error != null
                  ? _buildErrorState()
                  : _buildBlogList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _statusFilters.map((filter) {
            final isSelected = _selectedStatus == filter['id'];
            final count = _getStatusCount(filter['id']!);
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedStatus = filter['id']!;
                  });
                },
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blueAccent
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected
                          ? Colors.blueAccent
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _getStatusIcon(filter['id']!, isSelected),
                      const SizedBox(width: 6),
                      Text(
                        filter['label']!,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade700,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withAlpha(50)
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _getStatusIcon(String status, bool isSelected) {
    Color color = isSelected ? Colors.white : Colors.grey.shade600;
    IconData icon;
    switch (status) {
      case 'published':
        icon = Icons.check_circle;
        color = isSelected ? Colors.white : Colors.green;
        break;
      case 'draft':
        icon = Icons.edit_note;
        color = isSelected ? Colors.white : Colors.orange;
        break;
      case 'archived':
        icon = Icons.archive;
        color = isSelected ? Colors.white : Colors.grey;
        break;
      default:
        icon = Icons.article;
    }
    return Icon(icon, size: 16, color: color);
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Colors.blueAccent,
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            isFr ? 'Chargement des articles...' : 'Loading blogs...',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              isFr ? 'Erreur de chargement' : 'Error loading blogs',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchBlogs,
              icon: const Icon(Icons.refresh),
              label: Text(isFr ? 'Réessayer' : 'Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlogList() {
    final blogs = _filteredBlogs;

    if (blogs.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: blogs.length,
      itemBuilder: (context, index) {
        return _buildBlogCard(blogs[index]);
      },
    );
  }

  Widget _buildBlogCard(Blog blog) {
    final imageUrl = ApiConfig.getImageUrl(blog.imageUrl);
    final hasImage = imageUrl.isNotEmpty;
    final date = _formatDate(blog.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showBlogActions(blog),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: hasImage
                      ? Image.network(
                          imageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              _buildThumbnailPlaceholder(),
                        )
                      : _buildThumbnailPlaceholder(),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status + Category row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(blog.status),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              blog.status.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (blog.category.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withAlpha(20),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                blog.category,
                                style: TextStyle(
                                  color: Colors.blueAccent.shade700,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Title
                      Text(
                        blog.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Author + Date + Views
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 13,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              blog.author?.fullName ?? 'Admin',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 11,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            date,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.visibility_outlined,
                            size: 11,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${blog.views}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Chevron
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueAccent.shade100, Colors.blueAccent.shade400],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.article_outlined,
        size: 30,
        color: Colors.white.withAlpha(180),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'published':
        return Colors.green;
      case 'draft':
        return Colors.orange;
      case 'archived':
        return Colors.grey;
      default:
        return Colors.blueAccent;
    }
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;
    Color color;

    switch (_selectedStatus) {
      case 'published':
        message = isFr ? 'Aucun article publié' : 'No published blogs';
        icon = Icons.check_circle_outline;
        color = Colors.green;
        break;
      case 'draft':
        message = isFr ? 'Aucun brouillon' : 'No drafts';
        icon = Icons.edit_note;
        color = Colors.orange;
        break;
      case 'archived':
        message = isFr ? 'Aucun article archivé' : 'No archived blogs';
        icon = Icons.archive_outlined;
        color = Colors.grey;
        break;
      default:
        message = isFr ? 'Aucun article trouvé' : 'No blogs found';
        icon = Icons.article_outlined;
        color = Colors.blueAccent;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: color),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isFr
                ? 'Créez votre premier article'
                : 'Create your first blog post',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void _showBlogActions(Blog blog) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              blog.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Status
            Row(
              children: [
                Text(
                  isFr ? 'Statut : ' : 'Status: ',
                  style: const TextStyle(color: Colors.grey),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(blog.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    blog.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _navigateToForm(blog: blog);
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: Text(isFr ? 'Modifier' : 'Edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteBlog(blog.id, blog.title);
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(isFr ? 'Supprimer' : 'Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoDate);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
