import 'package:flutter/material.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/core/utils/chat.dart';
import 'package:tanga_acadamie/models/models.dart';
import 'package:tanga_acadamie/screens/shared/chat_page.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';
import 'package:tanga_acadamie/core/utils/app_snackbar.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';

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
    if (!mounted) return;
    try {
      await Future.wait([_fetchUserChats(), _fetchAllUsers()]);
    } catch (_) {
      // Individual fetch failures are surfaced through `_fetchUserChats`;
      // never let the combined future reject unhandled from initState.
      if (mounted) {
        setState(() {
          _error = isFr ? 'Échec du chargement des messages' : 'Failed to load messages';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchUserChats() async {
    final result = await fetchUserChats();
    if (!mounted) return;
    if (result.isSuccess) {
      final data = result.data;
      setState(() {
        _chats = (data is List ? data.whereType<Map<String, dynamic>>() : const <Map<String, dynamic>>[])
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
    if (!mounted) return;
    if (result.isSuccess) {
      final data = result.data;
      setState(() {
        _users = (data is List ? data.whereType<Map<String, dynamic>>() : const <Map<String, dynamic>>[])
            .where((user) => user['_id'] != _currentUserId)
            .map((user) => UserContact.fromJson(user))
            .toList();
      });
    }
  }

  Future<void> _startNewChat(String userId) async {
    final result = await startChat(participantId: userId);
    if (!mounted) return;
    if (result.isSuccess) {
      final chatData = result.data;
      final chatId = chatData is Map
          ? (chatData['_id'] ?? chatData['chatId'])
          : null;

      setState(() {
        _showUserList = false;
      });

      if (chatId != null && _currentUserId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ChatPage(chatId: chatId, userId: _currentUserId!),
          ),
        ).then((_) => _fetchUserChats());
      }
    } else {
      _showErrorSnackbar(result.error ?? (isFr ? 'Échec du démarrage du chat' : 'Failed to start chat'));
    }
  }

  void _showErrorSnackbar(String message) {
    AppSnackBar.showError(context, message);
  }

  void _openChat(ChatItem chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChatPage(chatId: chat.id, userId: _currentUserId!),
      ),
    ).then((_) => _fetchUserChats());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          try {
            await Future.wait([_fetchUserChats(), _fetchAllUsers()]);
          } catch (_) {
            // Never let a rejected combined future escape RefreshIndicator.
          }
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
            color: AppColors.primary,
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            isFr ? 'Chargement des messages...' : 'Loading messages...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
          label: Text(
            _showUserList
                ? (isFr ? 'Masquer les utilisateurs' : 'Hide Users')
                : (isFr ? 'Nouvelle conversation' : 'New Conversation'),
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: AppColors.primary,
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
              color: AppColors.error.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withAlpha(76)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.error400),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: AppColors.error700),
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
            color: AppColors.primary.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.chat, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFr ? 'Conversations récentes' : 'Recent Conversations',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              if (_chats.isNotEmpty)
                Text(
                  '${_chats.length} ${_chats.length == 1 ? 'chat' : 'chats'}',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
        border: Border.all(color: AppColors.borderLight),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFr ? 'Sélectionnez un utilisateur' : 'Select a user to message',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                          color: AppColors.textHint,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isFr
                              ? 'Aucun utilisateur disponible'
                              : 'No users available',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) =>
                        _buildUserItem(_users[index]),
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
              backgroundImage: user.profile.isNotEmpty
                  ? NetworkImage(user.profile)
                  : null,
              child: user.profile.isEmpty
                  ? Text(
                      user.initial,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: roleColor,
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
                          color: roleColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          user.role.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: roleColor,
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
                              color: AppColors.textSecondary,
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
                color: AppColors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 20,
                color: AppColors.primary,
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
        return AppColors.secondary;
      case 'instructor':
        return AppColors.primary;
      case 'student':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildChatList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _chats.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, indent: 72, color: AppColors.borderLight),
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
              backgroundColor: AppColors.primary.withAlpha(25),
              backgroundImage:
                  chat.recipientAvatar != null &&
                      chat.recipientAvatar!.isNotEmpty
                  ? NetworkImage('${ApiConfig.baseUrl}${chat.recipientAvatar}')
                  : null,
              child:
                  chat.recipientAvatar == null || chat.recipientAvatar!.isEmpty
                  ? Text(
                      chat.recipientInitial,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
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
                              ? AppColors.primary
                              : AppColors.textLight,
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
                                ? AppColors.textDark
                                : AppColors.textSecondary,
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
                            color: AppColors.primary,
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
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isFr ? 'Aucune conversation' : 'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFr
                ? 'Démarrez une nouvelle conversation'
                : 'Start a new conversation using the button above',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}
