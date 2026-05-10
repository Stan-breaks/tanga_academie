import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/models/models.dart';
import 'package:tanga_acadamie/storage_service.dart';

/// Service for chat-related API calls and socket management
class ChatService {
  io.Socket? _socket;
  String? _token;
  String? _currentUserId;

  /// Initialize the service with authentication
  Future<void> initialize() async {
    _token = await getToken();
    final user = await getUser();
    _currentUserId = user['id']?.toString();
  }

  String? get currentUserId => _currentUserId;
  String? get token => _token;

  /// Initialize socket connection
  io.Socket initSocket({
    required String chatId,
    required Function(Message) onMessageReceived,
    required Function(bool) onTypingChanged,
    Function()? onConnected,
    Function()? onDisconnected,
    Function(dynamic)? onError,
  }) {
    _socket?.dispose();

    _socket = io.io(
      ApiConfig.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': _token})
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket!.onConnect((_) {
      _socket!.emit('join_chat', chatId);
      onConnected?.call();
    });

    _socket!.on('receive_message', (data) {
      try {
        final message = Message.fromJson(data);
        onMessageReceived(message);
      } catch (e) {
        debugPrint('Error parsing received message: $e');
      }
    });

    _socket!.on('typing', (data) {
      if (data['isTyping'] != null) {
        onTypingChanged(data['isTyping'] == true);
      }
    });

    _socket!.onDisconnect((_) {
      onDisconnected?.call();
    });

    _socket!.onConnectError((data) {
      onError?.call(data);
    });

    _socket!.connect();
    return _socket!;
  }

  /// Dispose socket connection
  void disposeSocket() {
    _socket?.dispose();
    _socket = null;
  }

  /// Emit typing status
  void emitTyping(String chatId, bool isTyping) {
    _socket?.emit('typing', {'chatId': chatId, 'isTyping': isTyping});
  }

  /// Fetch messages for a chat
  Future<List<Message>> fetchMessages(String chatId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/chats/$chatId/messages'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final messagesList = (data['data'] ?? data['messages'] ?? []) as List;
      return messagesList.map((m) => Message.fromJson(m)).toList();
    } else {
      throw Exception('Failed to fetch messages');
    }
  }

  /// Send a message
  Future<Message?> sendMessage(String chatId, String content) async {
    // First emit via socket for real-time delivery
    _socket?.emit('send_message', {'chatId': chatId, 'content': content});

    // Also send via HTTP for persistence
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/chats/$chatId/messages'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'content': content}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return Message.fromJson(data['data'] ?? data);
      }
    } catch (e) {
      debugPrint('HTTP send failed, relying on socket: $e');
    }
    return null;
  }

  /// Fetch user's chat list
  Future<List<ChatItem>> fetchUserChats() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/chats'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final chatsList = (data['data'] ?? data['chats'] ?? []) as List;
      return chatsList
          .map((c) => ChatItem.fromJson(c as Map<String, dynamic>, null))
          .toList();
    } else {
      throw Exception('Failed to fetch chats');
    }
  }

  /// Start a new chat
  Future<String?> startChat({
    required String userId,
    String? courseId,
    String? userType,
  }) async {
    final body = <String, dynamic>{'recipientId': userId};
    if (courseId != null) body['courseId'] = courseId;
    if (userType != null) body['recipientType'] = userType;

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/chats'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      return data['data']?['_id']?.toString() ??
          data['chat']?['_id']?.toString() ??
          data['_id']?.toString();
    } else {
      throw Exception('Failed to start chat');
    }
  }

  /// Fetch instructor contacts (for students)
  Future<List<InstructorContact>> fetchInstructorContacts() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/chats/contacts/instructors'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final contactsList = (data['data'] ?? data['instructors'] ?? []) as List;
      return contactsList.map((c) => InstructorContact.fromJson(c)).toList();
    } else {
      throw Exception('Failed to fetch instructor contacts');
    }
  }

  /// Fetch student contacts (for instructors)
  Future<List<CourseWithStudents>> fetchStudentContacts() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/chats/contacts/students'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final coursesList = (data['data'] ?? data['courses'] ?? []) as List;
      return coursesList.map((c) => CourseWithStudents.fromJson(c)).toList();
    } else {
      throw Exception('Failed to fetch student contacts');
    }
  }

  /// Fetch admin contacts
  Future<List<AdminContact>> fetchAdminContacts() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/chats/contacts/admins'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final contactsList = (data['data'] ?? data['admins'] ?? []) as List;
      return contactsList.map((c) => AdminContact.fromJson(c)).toList();
    } else {
      throw Exception('Failed to fetch admin contacts');
    }
  }
}
