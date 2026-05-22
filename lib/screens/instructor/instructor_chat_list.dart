import 'package:flutter/material.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/core/utils/chat.dart';
import 'package:tanga_acadamie/models/models.dart';
import 'package:tanga_acadamie/screens/shared/chat_page.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';

class InstructorChatList extends StatefulWidget {
  const InstructorChatList({super.key});

  @override
  State<InstructorChatList> createState() => _InstructorChatListState();
}

class _InstructorChatListState extends State<InstructorChatList> {
  List<ChatItem> _chats = [];
  List<CourseWithStudents> _coursesWithStudents = [];
  List<AdminContact> _admins = [];
  bool _isLoading = true;
  bool _showStudentList = false;
  bool _showAdminList = false;
  String? _error;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _currentUserId = await getCurrentUserId();
    await Future.wait([
      _fetchUserChats(),
      _fetchStudentsContacts(),
      _fetchAdminsContacts(),
    ]);
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

  Future<void> _fetchStudentsContacts() async {
    final result = await fetchStudentContacts();
    if (result.isSuccess) {
      setState(() {
        _coursesWithStudents = (result.data as List)
            .map((course) => CourseWithStudents.fromJson(course))
            .where((course) => course.students.isNotEmpty)
            .toList();
      });
    }
  }

  Future<void> _fetchAdminsContacts() async {
    final result = await fetchAdminsForInstructor();
    if (result.isSuccess) {
      setState(() {
        _admins = (result.data as List)
            .map((admin) => AdminContact.fromJson(admin))
            .toList();
      });
    }
  }

  Future<void> _startNewChat(
    String userId,
    String userType,
    String? courseId,
  ) async {
    final result = await startChat(
      participantId: userId,
      userType: userType,
      courseId: courseId,
    );

    if (result.isSuccess) {
      final chatData = result.data;
      final chatId = chatData['_id'] ?? chatData['chatId'];

      setState(() {
        _showStudentList = false;
        _showAdminList = false;
      });

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
      _showErrorSnackbar(result.error ?? (isFr ? 'Échec du démarrage du chat' : 'Failed to start chat'));
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
    ).then((_) => _fetchUserChats());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        color: Colors.blueAccent,
        onRefresh: () async {
          await Future.wait([
            _fetchUserChats(),
            _fetchStudentsContacts(),
            _fetchAdminsContacts(),
          ]);
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

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Action buttons row
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: _showStudentList ? Icons.close : Icons.school,
                label: _showStudentList
                    ? (isFr ? 'Masquer' : 'Hide Students')
                    : (isFr ? 'Message étudiants' : 'Message Students'),
                color: Colors.green,
                onPressed: () {
                  setState(() {
                    if (_showAdminList) _showAdminList = false;
                    _showStudentList = !_showStudentList;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: _showAdminList ? Icons.close : Icons.admin_panel_settings,
                label: _showAdminList
                    ? (isFr ? 'Masquer' : 'Hide Admins')
                    : (isFr ? 'Message admin' : 'Message Admin'),
                color: Colors.purple,
                onPressed: () {
                  setState(() {
                    if (_showStudentList) _showStudentList = false;
                    _showAdminList = !_showAdminList;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Student List
        if (_showStudentList) ...[
          _buildStudentsList(),
          const SizedBox(height: 16),
        ],

        // Admin List
        if (_showAdminList) ...[_buildAdminsList(), const SizedBox(height: 16)],

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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
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

  Widget _buildStudentsList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                isFr
                    ? 'Sélectionnez un étudiant'
                    : 'Select a student to message',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _coursesWithStudents.isEmpty
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
                          isFr
                              ? 'Aucun étudiant inscrit'
                              : 'No students enrolled yet',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _coursesWithStudents.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) =>
                        _buildCourseWithStudents(_coursesWithStudents[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseWithStudents(CourseWithStudents courseWithStudents) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.book,
                  size: 18,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  courseWithStudents.courseTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${courseWithStudents.students.length} ${isFr ? 'étudiant${courseWithStudents.students.length == 1 ? "" : "s"}' : 'student${courseWithStudents.students.length == 1 ? "" : "s"}'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          // Students list
          ...courseWithStudents.students.map(
            (student) =>
                _buildStudentItem(student, courseWithStudents.courseId),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentItem(StudentContact student, String courseId) {
    return InkWell(
      onTap: () => _startNewChat(student.id, 'Student', courseId),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.green.withAlpha(25),
              backgroundImage: student.profile.isNotEmpty
                  ? NetworkImage(student.profile)
                  : null,
              child: student.profile.isEmpty
                  ? Text(
                      student.initial,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.green,
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
                    student.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (student.email.isNotEmpty)
                    Text(
                      student.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 16,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminsList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.admin_panel_settings,
                color: Colors.purple,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isFr ? 'Contacter l\'administration' : 'Contact Administration',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _admins.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isFr
                              ? 'Aucun admin disponible'
                              : 'No admins available',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _admins.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) =>
                        _buildAdminItem(_admins[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminItem(AdminContact admin) {
    return InkWell(
      onTap: () => _startNewChat(admin.id, 'Admin', null),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.purple.withAlpha(25),
              backgroundImage: admin.profile.isNotEmpty
                  ? NetworkImage(admin.profile)
                  : null,
              child: admin.profile.isEmpty
                  ? Text(
                      admin.initial,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.purple,
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
                    admin.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (admin.email.isNotEmpty)
                    Text(
                      admin.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 18,
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ),
    );
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
              backgroundColor: Colors.blueAccent.withAlpha(25),
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
                        color: Colors.blueAccent,
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
                              ? Colors.blueAccent
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
                            color: Colors.blueAccent,
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
            isFr ? 'Aucune conversation' : 'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFr
                ? 'Démarrez une conversation avec les étudiants ou les admins'
                : 'Start a conversation with students or admins using the buttons above',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
