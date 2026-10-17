import 'package:intl/intl.dart';

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

/// Extract a profile image path that may be a nested object ({url}) or a path.
String? _extractProfile(dynamic value) {
  if (value == null) return null;
  if (value is Map) {
    return _extractProfile(value['url'] ?? value['path'] ?? value['secure_url']);
  }
  final path = value.toString();
  return path.isEmpty ? null : path;
}

/// Resolve a preview string for a message that may only contain attachments.
String _previewFromMessage(dynamic lastMsg) {
  if (lastMsg is Map) {
    final content = lastMsg['content']?.toString() ?? '';
    if (content.isNotEmpty) return content;
    final attachments = lastMsg['attachments'];
    if (attachments is List && attachments.isNotEmpty) {
      final first = attachments.first;
      if (first is Map) {
        final name = first['filename']?.toString();
        if (name != null && name.isNotEmpty) return '📎 $name';
      }
      return '📎 Attachment';
    }
  }
  return 'No messages yet';
}

/// Chat item model representing a conversation in chat list

class ChatItem {
  final String id;
  final String recipientId;
  final String recipientName;
  final String recipientInitial;
  final String? recipientAvatar;
  final String? recipientRole;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final String? courseId;
  final String? courseName;

  ChatItem({
    required this.id,
    required this.recipientId,
    required this.recipientName,
    required this.recipientInitial,
    this.recipientAvatar,
    this.recipientRole,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.courseId,
    this.courseName,
  });

  factory ChatItem.fromJson(Map<String, dynamic> json, String? currentUserId) {
    // Handle different API response formats

    // For chats with otherParticipants array (most common)
    if (json['otherParticipants'] != null) {
      final otherParticipants = json['otherParticipants'] as List;
      if (otherParticipants.isNotEmpty) {
        final participant = otherParticipants[0];
        final firstName = participant['firstName']?.toString() ?? '';
        final lastName = participant['lastName']?.toString() ?? '';
        final name =
            participant['name']?.toString() ?? '$firstName $lastName'.trim();
        final displayName = name.isEmpty ? 'Unknown User' : name;

        final lastMsg = json['lastMessage'];
        final lastMessageTime = _parseTimestamp(
          lastMsg?['timestamp'] ??
              lastMsg?['createdAt'] ??
              json['updatedAt'],
        );

        return ChatItem(
          id: json['_id']?.toString() ?? json['chatId']?.toString() ?? '',
          recipientId: participant['_id']?.toString() ?? '',
          recipientName: displayName,
          recipientInitial: displayName.isNotEmpty
              ? displayName[0].toUpperCase()
              : '?',
          recipientAvatar: _extractProfile(
            participant['profile'] ??
                participant['profileImage'] ??
                participant['avatar'],
          ),
          recipientRole: participant['role']?.toString(),
          lastMessage: _previewFromMessage(lastMsg),
          lastMessageTime: lastMessageTime,
          unreadCount: int.tryParse('${json['unreadCount'] ?? 0}') ?? 0,
          courseId:
              json['courseId']?.toString() ??
              json['course']?['_id']?.toString(),
          courseName:
              json['courseName']?.toString() ??
              json['course']?['title']?.toString(),
        );
      }
    }

    // For chats with recipient/otherUser object
    final recipientData = json['recipient'] ?? json['otherUser'] ?? {};
    final firstName = recipientData['firstName']?.toString() ?? '';
    final lastName = recipientData['lastName']?.toString() ?? '';
    final name =
        recipientData['username']?.toString() ??
        recipientData['name']?.toString() ??
        '$firstName $lastName'.trim();
    final displayName = name.isEmpty ? 'Unknown' : name;

    return ChatItem(
      id: json['_id']?.toString() ?? json['chatId']?.toString() ?? '',
      recipientId:
          recipientData['_id']?.toString() ??
          json['recipientId']?.toString() ??
          '',
      recipientName: displayName,
      recipientInitial: displayName.isNotEmpty
          ? displayName[0].toUpperCase()
          : '?',
      recipientAvatar: _extractProfile(
        recipientData['profile'] ??
            recipientData['profileImage'] ??
            recipientData['avatar'],
      ),
      recipientRole: recipientData['role']?.toString(),
      lastMessage: json['lastMessage'] is Map
          ? _previewFromMessage(json['lastMessage'])
          : (json['lastMessage']?.toString() ?? 'No messages yet'),
      lastMessageTime: _parseTimestamp(
        json['lastMessageTime'] ?? json['updatedAt'],
      ),
      unreadCount: int.tryParse('${json['unreadCount'] ?? 0}') ?? 0,
      courseId:
          json['courseId']?.toString() ?? json['course']?['_id']?.toString(),
      courseName:
          json['courseName']?.toString() ??
          json['course']?['title']?.toString(),
    );
  }

  /// Formatted time string for display
  String get formattedTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(
      lastMessageTime.year,
      lastMessageTime.month,
      lastMessageTime.day,
    );

    if (messageDate == today) {
      return DateFormat('HH:mm').format(lastMessageTime);
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(messageDate).inDays < 7) {
      return DateFormat('EEEE').format(lastMessageTime);
    } else {
      return DateFormat('MMM d').format(lastMessageTime);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'chatId': id,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'recipientAvatar': recipientAvatar,
      'recipientRole': recipientRole,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
      'courseId': courseId,
      'courseName': courseName,
    };
  }

  ChatItem copyWith({
    String? id,
    String? recipientId,
    String? recipientName,
    String? recipientInitial,
    String? recipientAvatar,
    String? recipientRole,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    String? courseId,
    String? courseName,
  }) {
    return ChatItem(
      id: id ?? this.id,
      recipientId: recipientId ?? this.recipientId,
      recipientName: recipientName ?? this.recipientName,
      recipientInitial: recipientInitial ?? this.recipientInitial,
      recipientAvatar: recipientAvatar ?? this.recipientAvatar,
      recipientRole: recipientRole ?? this.recipientRole,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
    );
  }
}
