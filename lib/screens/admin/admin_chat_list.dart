import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/screens/shared/chat_page.dart';
import 'package:tanga_acadamie/storage_service.dart';

class AdminChatList extends StatefulWidget {
  const AdminChatList({super.key});

  @override
  State<AdminChatList> createState() => _AdminChatListState();
}

class _AdminChatListState extends State<AdminChatList> {
  List<ChatItem> _chats = [];
  List<UserContact> _users = [];
  bool _isLoading = true;
  bool _showUserList = false;
  String? _error;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _getCurrentUserId();
    await Future.wait([_fetchUserChats(), _fetchAllUsers()]);
  }

  Future<void> _getCurrentUserId() async {
    try {
      final token = await getToken();
      if (token != null) {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = json.decode(
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
          );
          _currentUserId = payload['id'] ?? payload['userId'];
        }
      }
    } catch (e) {
      debugPrint('Error getting user ID: $e');
    }
  }

  Future<void> _fetchUserChats() async {
    try {
      final token = await getToken();
      if (token == null) {
        setState(() {
          _error = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/chats/user-chats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _chats = (data['data'] as List)
              .map((chat) => ChatItem.fromJson(chat, _currentUserId))
              .toList();
          _isLoading = false;
          _error = null;
        });
      } else {
        setState(() {
          _error = 'Failed to load chats';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching chats: $e');
      setState(() {
        _error = 'Error loading chats';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAllUsers() async {
    try {
      final token = await getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/chats/admin/contacts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final users = data['data'] as List? ?? data as List? ?? [];
        setState(() {
          _users = users
              .where((user) => user['_id'] != _currentUserId)
              .map((user) => UserContact.fromJson(user))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
    }
  }

  Future<void> _startChat(String userId) async {
    try {
      final token = await getToken();
      if (token == null) return;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/chats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'participantId': userId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final chatData = data['data'];
        final chatId = chatData['_id'] ?? chatData['chatId'];

        setState(() {
          _showUserList = false;
        });

        if (chatId != null && _currentUserId != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ChatPage(chatId: chatId, userId: _currentUserId!),
            ),
          ).then((_) {
            _fetchUserChats();
          });
        }
      } else {
        _showErrorSnackbar('Failed to start chat');
      }
    } catch (e) {
      debugPrint('Error starting chat: $e');
      _showErrorSnackbar('Error starting chat');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _openChat(ChatItem chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChatPage(chatId: chat.id, userId: _currentUserId!),
      ),
    ).then((_) {
      _fetchUserChats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        color: Colors.blueGrey,
        onRefresh: () async {
          await Future.wait([_fetchUserChats(), _fetchAllUsers()]);
        },
        child: _isLoading ? _buildLoadingState() : _buildBody(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Colors.blueGrey,
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading messages...',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // New Chat Button
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _showUserList = !_showUserList;
            });
          },
          icon: Icon(_showUserList ? Icons.close : Icons.add),
          label: Text(_showUserList ? 'Hide Users' : 'New Conversation'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: Colors.blueGrey,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
        ),
        const SizedBox(height: 16),

        // User List
        if (_showUserList) ...[_buildUsersList(), const SizedBox(height: 16)],

        // Error Message
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withAlpha(76)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade400),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ),
        if (_error != null) const SizedBox(height: 16),

        // Section Header
        _buildSectionHeader(),
        const SizedBox(height: 16),

        // Chat List
        _chats.isEmpty ? _buildEmptyState() : _buildChatList(),
      ],
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blueGrey.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.chat, color: Colors.blueGrey, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recent Conversations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (_chats.isNotEmpty)
                Text(
                  '${_chats.length} ${_chats.length == 1 ? 'chat' : 'chats'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUsersList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      constraints: const BoxConstraints(maxHeight: 350),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select a user to message',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No users available',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      return _buildUserItem(_users[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserItem(UserContact user) {
    return InkWell(
      onTap: () => _startChat(user.id),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _getRoleColor(user.role).withAlpha(25),
              backgroundImage: user.profile.isNotEmpty
                  ? NetworkImage(user.profile)
                  : null,
              child: user.profile.isEmpty
                  ? Text(
                      user.name[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _getRoleColor(user.role),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleColor(user.role).withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          user.role.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: _getRoleColor(user.role),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (user.email.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            user.email,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 20,
                color: Colors.blueGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purple;
      case 'instructor':
        return Colors.blue;
      case 'student':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildChatList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _chats.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, indent: 72, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          return _buildChatItem(_chats[index]);
        },
      ),
    );
  }

  Widget _buildChatItem(ChatItem chat) {
    return InkWell(
      onTap: () => _openChat(chat),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.blueGrey.withAlpha(25),
              child: Text(
                chat.otherUserInitial,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.otherUserName,
                          style: TextStyle(
                            fontWeight: chat.unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        chat.formattedTime,
                        style: TextStyle(
                          fontSize: 12,
                          color: chat.unreadCount > 0
                              ? Colors.blueGrey
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: chat.unreadCount > 0
                                ? Colors.black87
                                : Colors.grey.shade600,
                            fontWeight: chat.unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (chat.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${chat.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new conversation using the button above',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// Models
class ChatItem {
  final String id;
  final String otherUserName;
  final String otherUserInitial;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;

  ChatItem({
    required this.id,
    required this.otherUserName,
    required this.otherUserInitial,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
  });

  factory ChatItem.fromJson(Map<String, dynamic> json, String? currentUserId) {
    final otherParticipants = json['otherParticipants'] as List;
    final otherParticipant = otherParticipants[0];
    final name =
        otherParticipant['name'] ??
        '${otherParticipant['firstName'] ?? ''} ${otherParticipant['lastName'] ?? ''}'
            .trim();

    final lastMsg = json['lastMessage'];
    final lastMessageContent = lastMsg?['content'] ?? 'No messages yet';
    final lastMessageTime = lastMsg?['timestamp'] != null
        ? DateTime.parse(lastMsg['timestamp'])
        : DateTime.now();

    return ChatItem(
      id: json['_id'] ?? json['chatId'] ?? '',
      otherUserName: name.isEmpty ? 'Unknown User' : name,
      otherUserInitial: name.isNotEmpty ? name[0].toUpperCase() : '?',
      lastMessage: lastMessageContent,
      lastMessageTime: lastMessageTime,
      unreadCount: json['unreadCount'] ?? 0,
    );
  }

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
}

class UserContact {
  final String id;
  final String name;
  final String profile;
  final String email;
  final String role;

  UserContact({
    required this.id,
    required this.name,
    required this.profile,
    required this.email,
    required this.role,
  });

  factory UserContact.fromJson(Map<String, dynamic> json) {
    final firstName = json['firstName']?.toString() ?? '';
    final lastName = json['lastName']?.toString() ?? '';
    final name = '$firstName $lastName'.trim();
    final profilePath = json['profile']?.toString();

    return UserContact(
      id: json['_id']?.toString() ?? '',
      name: name.isEmpty ? 'Unknown User' : name,
      profile: profilePath != null && profilePath.isNotEmpty
          ? '${ApiConfig.baseUrl}$profilePath'
          : '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
    );
  }
}
