import 'package:tanga_acadamie/api_config.dart';

/// Attachment model for chat messages
class MessageAttachment {
  final String url;
  final String? filename;
  final String? fileType;
  final int? fileSize;

  MessageAttachment({
    required this.url,
    this.filename,
    this.fileType,
    this.fileSize,
  });

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      url: (json['url'] ?? json['path'] ?? '').toString(),
      filename: json['filename']?.toString() ?? json['name']?.toString(),
      fileType: json['fileType']?.toString() ?? json['mimetype']?.toString(),
      fileSize: int.tryParse(json['fileSize']?.toString() ?? ''),
    );
  }

  /// Whether this attachment should be rendered as an image.
  bool get isImage {
    final type = fileType?.toLowerCase() ?? '';
    if (type.startsWith('image/')) return true;
    final name = (filename ?? url).toLowerCase();
    return RegExp(r'\.(png|jpe?g|gif|webp|bmp|heic)$').hasMatch(name);
  }

  /// Absolute URL for the attachment.
  String get fullUrl => ApiConfig.getImageUrl(url);
}

/// Message model for chat functionality
class Message {
  final String id;
  final String content;
  final String senderId;
  final String? senderUsername;
  final String? senderProfile;
  final DateTime createdAt;
  final bool isRead;
  final List<String> readBy;
  final List<MessageAttachment> attachments;

  Message({
    required this.id,
    required this.content,
    required this.senderId,
    this.senderUsername,
    this.senderProfile,
    required this.createdAt,
    this.isRead = false,
    this.readBy = const [],
    this.attachments = const [],
  });

  /// Backwards-compatible alias for [createdAt].
  DateTime get timestamp => createdAt;

  factory Message.fromJson(Map<String, dynamic> json) {
    // Handle both 'sender' object and direct 'senderId'
    String senderId;
    String? senderUsername;
    String? senderProfile;

    if (json['sender'] != null && json['sender'] is Map) {
      final sender = json['sender'] as Map;
      senderId = (sender['_id'] ?? sender['id'])?.toString() ?? '';
      senderUsername =
          sender['username']?.toString() ?? sender['name']?.toString();
      senderProfile = _resolveProfile(sender['profile'] ?? sender['profileImage']);
    } else {
      senderId =
          json['senderId']?.toString() ?? json['sender']?.toString() ?? '';
      senderUsername = json['senderUsername']?.toString();
      senderProfile = _resolveProfile(
        json['senderProfile'] ?? json['profile'] ?? json['profileImage'],
      );
    }

    return Message(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      senderId: senderId,
      senderUsername: senderUsername,
      senderProfile: senderProfile,
      createdAt: _parseTimestamp(json['createdAt'] ?? json['timestamp']),
      isRead: json['isRead'] == true,
      readBy: _parseIdList(json['readBy']),
      attachments: _parseAttachments(json['attachments']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'content': content,
      'senderId': senderId,
      'senderUsername': senderUsername,
      'senderProfile': senderProfile,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'readBy': readBy,
      'attachments': attachments
          .map((a) => {
                'url': a.url,
                'filename': a.filename,
                'fileType': a.fileType,
                'fileSize': a.fileSize,
              })
          .toList(),
    };
  }

  Message copyWith({
    String? id,
    String? content,
    String? senderId,
    String? senderUsername,
    String? senderProfile,
    DateTime? createdAt,
    bool? isRead,
    List<String>? readBy,
    List<MessageAttachment>? attachments,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      senderId: senderId ?? this.senderId,
      senderUsername: senderUsername ?? this.senderUsername,
      senderProfile: senderProfile ?? this.senderProfile,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      readBy: readBy ?? this.readBy,
      attachments: attachments ?? this.attachments,
    );
  }
}

/// Parse timestamps that may be ISO strings, or integer seconds/milliseconds.
DateTime _parseTimestamp(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is num) {
    final n = value.toInt();
    return DateTime.fromMillisecondsSinceEpoch(
      n < 100000000000 ? n * 1000 : n,
    );
  }

  final raw = value.toString().trim();
  if (raw.isEmpty) return DateTime.now();

  final asInt = int.tryParse(raw);
  if (asInt != null) {
    return DateTime.fromMillisecondsSinceEpoch(
      asInt < 100000000000 ? asInt * 1000 : asInt,
    );
  }

  return DateTime.tryParse(raw) ?? DateTime.now();
}

List<String> _parseIdList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((e) => e is Map ? (e['_id'] ?? e['id'])?.toString() : e.toString())
      .whereType<String>()
      .toList();
}

List<MessageAttachment> _parseAttachments(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((a) => MessageAttachment.fromJson(Map<String, dynamic>.from(a)))
      .toList();
}

/// Resolve a profile value that may be a nested object ({url}) or a path.
String? _resolveProfile(dynamic value) {
  if (value == null) return null;
  if (value is Map) {
    return _resolveProfile(value['url'] ?? value['path'] ?? value['secure_url']);
  }
  final path = value.toString();
  if (path.isEmpty) return null;
  return ApiConfig.getImageUrl(path);
}
