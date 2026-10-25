import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';

class AnnouncementCard extends StatefulWidget {
  final Map<String, dynamic> announcement;

  const AnnouncementCard({super.key, required this.announcement});

  @override
  State<AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<AnnouncementCard> {
  static const String _boxName = 'announcementsBox';

  bool _isRead = false;

  // Announcements are rendered as a list of cards; each card used to open this
  // box independently. Opening once and reusing it removes a per-card await.
  static Box? _readBox;

  static Future<Box> _openReadBox() async {
    return _readBox ??= await Hive.openBox(_boxName);
  }

  String get _id =>
      widget.announcement['_id']?.toString() ??
      widget.announcement['id']?.toString() ??
      '';

  @override
  void initState() {
    super.initState();
    _isRead = widget.announcement['isRead'] == true;
    _loadReadState();
  }

  Future<void> _loadReadState() async {
    if (_id.isEmpty) return;
    try {
      final box = await _openReadBox();
      final stored = box.get(_id) == true;
      if (!mounted) return;
      if (stored && !_isRead) {
        setState(() => _isRead = true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final announcement = widget.announcement;
    final priority = announcement['priority'] ?? 'medium';
    final priorityColor = _getPriorityColor(priority);
    final isRead = _isRead;
    final createdAt = announcement['createdAt'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: priorityColor.withAlpha(50),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Priority badge + timestamp
              Row(
                children: [
                  // Priority indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getPriorityIcon(priority),
                          size: 14,
                          color: priorityColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          priority.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: priorityColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Timestamp
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  // Unread indicator
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                announcement['title'] ?? 'Untitled Announcement',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),

              // Content preview
              Text(
                announcement['content'] ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textDark,
                  height: 1.4,
                ),
              ),

              // Course info (if available)
              if (announcement['courseId'] != null ||
                  announcement['courseName'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          announcement['courseName'] ?? 'Course',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markRead(String id) async {
    // Persist the read state locally so it survives rebuilds and restarts.
    try {
      final box = await _openReadBox();
      await box.put(id, true);
    } catch (_) {}

    try {
      final token = await getToken();
      await http.put(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/announcements/announcements/$id/read',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {}
  }

  void _showDetail(BuildContext context) {
    final announcement = widget.announcement;
    if (!_isRead && _id.isNotEmpty) {
      setState(() => _isRead = true);
      _markRead(_id);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) {
          final detailPriorityColor = _getPriorityColor(
            announcement['priority'] ?? 'medium',
          );
          return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: detailPriorityColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            (announcement['priority'] ?? 'medium')
                                .toString()
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: detailPriorityColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(announcement['createdAt']),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      announcement['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                        height: 1.3,
                      ),
                    ),
                    if (announcement['courseName'] != null ||
                        announcement['courseId'] != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 16,
                            color: AppColors.textLight,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            announcement['courseName']?.toString() ?? '',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    Divider(color: AppColors.borderLight),
                    const SizedBox(height: 16),
                    Text(
                      announcement['content'] ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textDark,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
        },
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return AppColors.error;
      case 'medium':
        return AppColors.warning;
      case 'low':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Icons.priority_high;
      case 'medium':
        return Icons.remove;
      case 'low':
        return Icons.arrow_downward;
      default:
        return Icons.info_outline;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';

    try {
      DateTime dateTime;
      if (date is String) {
        dateTime = DateTime.parse(date);
      } else if (date is DateTime) {
        dateTime = date;
      } else {
        return '';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return isFr ? 'À l\'instant' : 'Just now';
      } else if (difference.inMinutes < 60) {
        return isFr
            ? 'Il y a ${difference.inMinutes}m'
            : '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return isFr
            ? 'Il y a ${difference.inHours}h'
            : '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return isFr
            ? 'Il y a ${difference.inDays}j'
            : '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return '';
    }
  }
}
