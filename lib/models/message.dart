/// Message model for chat functionality
class Message {
  final String id;
  final String content;
  final String senderId;
  final String? senderUsername;
  final DateTime createdAt;
  final bool isRead;

  Message({
    required this.id,
    required this.content,
    required this.senderId,
    this.senderUsername,
    required this.createdAt,
    this.isRead = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // Handle both 'sender' object and direct 'senderId'
    String senderId;
    String? senderUsername;
    
    if (json['sender'] != null && json['sender'] is Map) {
      senderId = json['sender']['_id']?.toString() ?? '';
      senderUsername = json['sender']['username']?.toString();
    } else {
      senderId = json['senderId']?.toString() ?? json['sender']?.toString() ?? '';
      senderUsername = json['senderUsername']?.toString();
    }

    return Message(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      senderId: senderId,
      senderUsername: senderUsername,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['isRead'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'content': content,
      'senderId': senderId,
      'senderUsername': senderUsername,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  Message copyWith({
    String? id,
    String? content,
    String? senderId,
    String? senderUsername,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      senderId: senderId ?? this.senderId,
      senderUsername: senderUsername ?? this.senderUsername,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
