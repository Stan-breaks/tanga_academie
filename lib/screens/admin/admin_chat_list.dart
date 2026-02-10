import 'package:flutter/material.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/core/utils/chat.dart';
import 'package:tanga_acadamie/models/models.dart';
import 'package:tanga_acadamie/screens/shared/chat_page.dart';

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
    _currentUserId = await getCurrentUserId();
    await Future.wait([_fetchUserChats(), _fetchAllUsers()]);
  }

  Future<void> _fetchUserChats() async {
    final result = await fetchUserChats();
    if (result.isSuccess) {
      setState(() {
        _chats = (result.data as List)
            .map((chat) => ChatItem.fromJson(chat, _currentUserId))
            .toList();
        _isLoading = false;
        _error = null;
      });
    } else {
      setState(() {
        _error = result.error;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAllUsers() async {
    final result = await fetchAdminContacts();
    if (result.isSuccess) {
      setState(() {
        _users = (result.data as List)
            .where((user) => user['_id'] != _currentUserId)
            .map((user) => UserContact.fromJson(user))
            .toList();
      });
    }
  }

  Future<void> _startNewChat(String userId) async {
    final result = await startChat(participantId: userId);
    if (result.isSuccess) {
      final chatData = result.data;
      final chatId = chatData['_id'] ?? chatData['chatId'];

      setState(() {
        _showUserList = false;
      });

      if (chatId != null && _currentUserId != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(chatId: chatId, userId: _currentUserId!),
          ),
        ).then((_) => _fetchUserChats());
      }
    } else {
      _showErrorSnackbar(result.error ?? 'Failed to start chat');
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
        builder: (context) => ChatPage(chatId: chat.id, userId: _currentUserId!),
      ),
    ).then((_) => _fetchUserChats());
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
        if (_error != null) ...[
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
          const SizedBox(height: 16),
        ],

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
                        Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text('No users available', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) => _buildUserItem(_users[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserItem(UserContact user) {
    final roleColor = _getRoleColor(user.role);
    
    return InkWell(
      onTap: () => _startNewChat(user.id),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: roleColor.withAlpha(25),
              backgroundImage: user.profile.isNotEmpty ? NetworkImage(user.profile) : null,
              child: user.profile.isEmpty
                  ? Text(
                      user.initial,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: roleColor),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          user.role.toUpperCase(),
                          style: TextStyle(fontSize: 10, color: roleColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (user.email.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            user.email,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
              child: const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.blueGrey),
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
        separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: Colors.grey.shade200),
        itemBuilder: (context, index) => _buildChatItem(_chats[index]),
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
              backgroundImage: chat.recipientAvatar != null && chat.recipientAvatar!.isNotEmpty
                  ? NetworkImage('${ApiConfig.baseUrl}${chat.recipientAvatar}')
                  : null,
              child: chat.recipientAvatar == null || chat.recipientAvatar!.isEmpty
                  ? Text(
                      chat.recipientInitial,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    )
                  : null,
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
                          chat.recipientName,
                          style: TextStyle(
                            fontWeight: chat.unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
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
                          color: chat.unreadCount > 0 ? Colors.blueGrey : Colors.grey.shade500,
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
                            color: chat.unreadCount > 0 ? Colors.black87 : Colors.grey.shade600,
                            fontWeight: chat.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (chat.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${chat.unreadCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
            child: Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 20),
          Text(
            'No conversations yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
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
