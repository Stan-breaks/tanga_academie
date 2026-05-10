import 'package:flutter/material.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/core/utils/chat.dart';
import 'package:tanga_acadamie/models/models.dart';
import 'package:tanga_acadamie/screens/shared/chat_page.dart';
import 'package:tanga_acadamie/screens/login_page.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';

class StudentChatList extends StatefulWidget {
  const StudentChatList({super.key});

  @override
  State<StudentChatList> createState() => _StudentChatListState();
}

class _StudentChatListState extends State<StudentChatList>
    with SingleTickerProviderStateMixin {
  List<ChatItem> _chats = [];
  List<InstructorContact> _instructors = [];
  bool _isLoading = true;
  bool _showInstructorList = false;
  bool _isAuthenticated = true;
  String? _error;
  String? _currentUserId;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _initialize();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    _currentUserId = await getCurrentUserId();
    if (_currentUserId == null) {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
      return;
    }
    await Future.wait([_fetchUserChats(), _fetchInstructorContacts()]);
  }

  Future<void> _fetchUserChats() async {
    final result = await fetchUserChats();
    if (result.isSuccess) {
      if (mounted) {
        setState(() {
          _chats = (result.data as List)
              .map((chat) => ChatItem.fromJson(chat, _currentUserId))
              .toList();
          _isLoading = false;
          _error = null;
        });
        _animationController.forward();
      }
    } else {
      if (mounted) {
        setState(() {
          _error = result.error;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchInstructorContacts() async {
    final result = await fetchInstructorContacts();
    if (result.isSuccess && mounted) {
      setState(() {
        _instructors = (result.data as List)
            .map((instructor) => InstructorContact.fromJson(instructor))
            .toList();
      });
    }
  }

  Future<void> _startChatWithInstructor(
    String instructorId,
    String courseId,
  ) async {
    final result = await startChat(
      participantId: instructorId,
      userType: 'Student',
      courseId: courseId,
    );

    if (result.isSuccess) {
      final chatData = result.data;
      final chatId = chatData['_id'] ?? chatData['chatId'];

      if (mounted) {
        setState(() {
          _showInstructorList = false;
        });
      }

      if (chatId != null && _currentUserId != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ChatPage(chatId: chatId, userId: _currentUserId!),
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
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _openChat(ChatItem chat) {
    if (_currentUserId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ChatPage(chatId: chat.id, userId: _currentUserId!),
        ),
      ).then((_) => _fetchUserChats());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        color: Colors.blueAccent,
        onRefresh: () async {
          await Future.wait([_fetchUserChats(), _fetchInstructorContacts()]);
        },
        child: _isLoading
            ? _buildLoadingState()
            : !_isAuthenticated
            ? _buildNotLoggedInState()
            : _buildBody(),
      ),
    );
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
            isFr ? 'Chargement des messages...' : 'Loading messages...',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildNotLoggedInState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            isFr
                ? 'Veuillez vous connecter pour voir les messages'
                : 'Please log in to view messages',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              ).then((_) => _initialize());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(isFr ? 'Se connecter' : 'Log In'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // New Message Button
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _showInstructorList = !_showInstructorList;
              });
            },
            icon: Icon(
              _showInstructorList ? Icons.close : Icons.edit_square,
              size: 18,
            ),
            label: Text(
              _showInstructorList
                  ? (isFr ? 'Masquer les instructeurs' : 'Hide Instructors')
                  : (isFr ? 'Nouveau message' : 'New Message'),
              style: const TextStyle(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 16),

          // Instructor List (Expandable)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showInstructorList
                ? _buildInstructorList()
                : const SizedBox(),
          ),

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
          _chats.isEmpty
              ? _buildEmptyState()
              : Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _chats.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        indent: 72,
                        color: Colors.grey.shade200,
                      ),
                      itemBuilder: (context, index) =>
                          _buildChatItem(_chats[index]),
                    ),
                  ),
                ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.chat, color: Colors.blueAccent, size: 22),
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

  Widget _buildInstructorList() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blueAccent.shade100.withAlpha(80),
            Colors.blue.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_add,
                  color: Colors.blueAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isFr
                    ? 'Démarrer une nouvelle conversation'
                    : 'Start a New Conversation',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_instructors.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isFr
                        ? 'Aucun instructeur disponible'
                        : 'No instructors available',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isFr
                        ? 'Inscrivez-vous à des cours pour contacter les instructeurs'
                        : 'Enroll in courses to message instructors',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _instructors.length,
                separatorBuilder: (context, index) => Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  height: 1,
                  color: Colors.blueAccent.withAlpha(25),
                ),
                itemBuilder: (context, index) =>
                    _buildInstructorItem(_instructors[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInstructorItem(InstructorContact instructor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blueAccent.shade200,
                    Colors.blueAccent.shade700,
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withAlpha(80),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  instructor.initial,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    instructor.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.verified,
                        size: 14,
                        color: Colors.green.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isFr ? 'Instructeur' : 'Instructor',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: instructor.courses.map((course) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _startChatWithInstructor(instructor.id, course.id),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blueAccent.withAlpha(50)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withAlpha(20),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.book_outlined,
                        size: 14,
                        color: Colors.blueAccent.shade400,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          course.title,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildChatItem(ChatItem chat) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openChat(chat),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blueAccent.shade100,
                      Colors.blueAccent.shade400,
                    ],
                  ),
                  shape: BoxShape.circle,
                  image:
                      chat.recipientAvatar != null &&
                          chat.recipientAvatar!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(
                            '${ApiConfig.baseUrl}${chat.recipientAvatar}',
                          ),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child:
                    chat.recipientAvatar == null ||
                        chat.recipientAvatar!.isEmpty
                    ? Center(
                        child: Text(
                          chat.recipientInitial,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              // Chat Info
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
                              fontSize: 15,
                              color: Colors.black87,
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
                                ? Colors.blueAccent
                                : Colors.grey.shade500,
                            fontWeight: chat.unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
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
                              fontSize: 13,
                              fontWeight: chat.unreadCount > 0
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (chat.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${chat.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
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

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 56,
              color: Colors.blueAccent.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isFr ? 'Aucune conversation' : 'No conversations yet',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFr
                ? 'Démarrez une conversation avec vos instructeurs !'
                : 'Start a conversation with your instructors!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
