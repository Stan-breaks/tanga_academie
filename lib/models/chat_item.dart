/// Chat item model representing a conversation in chat list
class ChatItem {
  final String chatId;
  final String recipientId;
  final String recipientName;
  final String? recipientAvatar;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final String? courseId;
  final String? courseName;
  final String? recipientType; // 'instructor', 'student', 'admin'

  ChatItem({
    required this.chatId,
    required this.recipientId,
    required this.recipientName,
    this.recipientAvatar,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.courseId,
    this.courseName,
    this.recipientType,
  });

  factory ChatItem.fromJson(Map<String, dynamic> json) {
    // Handle various API response formats
    final recipientData = json['recipient'] ?? json['otherUser'] ?? {};
    
    return ChatItem(
      chatId: json['_id']?.toString() ?? json['chatId']?.toString() ?? '',
      recipientId: recipientData['_id']?.toString() ?? 
                   json['recipientId']?.toString() ?? '',
      recipientName: recipientData['username']?.toString() ?? 
                     json['recipientName']?.toString() ?? 'Unknown',
      recipientAvatar: recipientData['avatar']?.toString() ?? 
                       json['recipientAvatar']?.toString(),
      lastMessage: json['lastMessage']?.toString(),
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.tryParse(json['lastMessageTime'].toString())
          : (json['updatedAt'] != null
              ? DateTime.tryParse(json['updatedAt'].toString())
              : null),
      unreadCount: int.tryParse(json['unreadCount']?.toString() ?? '0') ?? 0,
      courseId: json['courseId']?.toString() ?? 
                json['course']?['_id']?.toString(),
      courseName: json['courseName']?.toString() ?? 
                  json['course']?['title']?.toString(),
      recipientType: recipientData['role']?.toString() ?? 
                     json['recipientType']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chatId': chatId,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'recipientAvatar': recipientAvatar,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'unreadCount': unreadCount,
      'courseId': courseId,
      'courseName': courseName,
      'recipientType': recipientType,
    };
  }

  ChatItem copyWith({
    String? chatId,
    String? recipientId,
    String? recipientName,
    String? recipientAvatar,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    String? courseId,
    String? courseName,
    String? recipientType,
  }) {
    return ChatItem(
      chatId: chatId ?? this.chatId,
      recipientId: recipientId ?? this.recipientId,
      recipientName: recipientName ?? this.recipientName,
      recipientAvatar: recipientAvatar ?? this.recipientAvatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      recipientType: recipientType ?? this.recipientType,
    );
  }
}
