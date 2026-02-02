import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/screens/shared/chat_page.dart';
import 'package:tanga_acadamie/storage_service.dart';

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
    await _getCurrentUserId();
    await Future.wait([
      _fetchUserChats(),
      _fetchStudentsContacts(),
      _fetchAdminsContacts(),
    ]);
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
      print('Error getting user ID: $e');
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
      print('Error fetching chats: $e');
      setState(() {
        _error = 'Error loading chats';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchStudentsContacts() async {
    try {
      final token = await getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/chats/instructor/contacts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print(data['data']);
        setState(() {
          _coursesWithStudents = (data['data'] as List)
              .map((course) => CourseWithStudents.fromJson(course))
              .where(
                (course) => course.students.isNotEmpty,
              ) // Only show courses with students
              .toList();
        });
      }
    } catch (e) {
      print('Error fetching instructor contacts: $e');
    }
  }

  Future<void> _fetchAdminsContacts() async {
    try {
      final token = await getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/chats/instructor/admin-contacts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          // Changed from 'admins' to 'data' to match your API response
          _admins = (data['data'] as List)
              .map((admin) => AdminContact.fromJson(admin))
              .toList();
        });
      }
    } catch (e) {
      print('Error fetching admin contacts: $e');
    }
  }

  Future<void> _startChat(
    String userId,
    String userType,
    String? courseId,
  ) async {
    try {
      final token = await getToken();
      if (token == null) return;

      String url = "";
      Map body = {};
      if (userType == "Student") {
        url = '${ApiConfig.baseUrl}/api/chats/course-chat';
        body = {
          'studentId': userId,
          'userType': "Instructor",
          'courseId': courseId,
        };
      } else {
        url = '${ApiConfig.baseUrl}/api/chats';
        body = {'participantId': userId};
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final chatData = data['data'];
        final chatId = chatData['_id'] ?? chatData['chatId'];

        setState(() {
          _showStudentList = false;
          _showAdminList = false;
        });

        if (chatId != null && _currentUserId != null) {
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
        final errorData = json.decode(response.body);
        String errorMessage = 'Failed to start chat';

        if (response.statusCode == 403) {
          if (errorData['message']?.contains('not enrolled') == true) {
            errorMessage = 'You need to enroll in this course first';
          } else if (errorData['message']?.contains('unpublished') == true) {
            errorMessage = 'This course is not yet available';
          } else {
            errorMessage = errorData['message'] ?? errorMessage;
          }
        }

        _showErrorSnackbar(errorMessage);
      }
    } catch (e) {
      print('Error starting chat: $e');
      _showErrorSnackbar('Error starting chat');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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
      appBar: AppBar(title: const Text('Messages'), elevation: 0),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _fetchUserChats(),
            _fetchStudentsContacts(),
            _fetchAdminsContacts(),
          ]);
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          // New Chat Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        if (_showAdminList) {
                          _showAdminList = false;
                        }
                        _showStudentList = !_showStudentList;
                      });
                    },
                    icon: Icon(_showStudentList ? Icons.close : Icons.add),
                    label: Text(
                      _showStudentList ? 'Hide Students' : 'Message Students',
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        if (_showStudentList) {
                          _showStudentList = false;
                        }
                        _showAdminList = !_showAdminList;
                      });
                    },
                    icon: Icon(_showAdminList ? Icons.close : Icons.add),
                    label: Text(
                      _showAdminList ? 'Hide Admin' : 'Message Admin',
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Student List (grouped by course)
          if (_showStudentList) _buildStudentsList(),

          // Admin List
          if (_showAdminList) _buildAdminsList(),

          // Error Message
          if (_error != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withAlpha(76)),
              ),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),

          // Recent Chats Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Recent Conversations',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_chats.isNotEmpty)
                  Text(
                    '${_chats.length} chat${_chats.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),

          // Chat List
          _chats.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _chats.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, indent: 72, color: Colors.grey[300]),
                  itemBuilder: (context, index) {
                    return _buildChatItem(_chats[index]);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildStudentsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: const BoxConstraints(maxHeight: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select a student to message',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _coursesWithStudents.isEmpty
                ? const Center(
                    child: Text(
                      'No students available.\nNo enrolled students yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: _coursesWithStudents.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return _buildCourseWithStudents(
                        _coursesWithStudents[index],
                      );
                    },
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course header
          Row(
            children: [
              Icon(Icons.book, size: 20, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${courseWithStudents.students.length} student${courseWithStudents.students.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          // Students list
          ...courseWithStudents.students
              .map(
                (student) =>
                    _buildStudentItem(student, courseWithStudents.courseId),
              )
              .toList(),
        ],
      ),
    );
  }

  Widget _buildStudentItem(StudentContact student, String courseId) {
    return InkWell(
      onTap: () => _startChat(student.id, "Student", courseId),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue[100],
              backgroundImage: student.profile.isNotEmpty
                  ? NetworkImage(student.profile)
                  : null,
              child: student.profile.isEmpty
                  ? Text(
                      student.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  if (student.email.isNotEmpty)
                    Text(
                      student.email,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chat_bubble_outline,
              size: 20,
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: const BoxConstraints(maxHeight: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select an admin to message',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _admins.isEmpty
                ? const Center(
                    child: Text(
                      'No admins available',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: _admins.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      return _buildAdminItem(_admins[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminItem(AdminContact admin) {
    return InkWell(
      onTap: () => _startChat(admin.id, "Admin", null),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.purple[100],
              backgroundImage: admin.profile.isNotEmpty
                  ? NetworkImage(admin.profile)
                  : null,
              child: admin.profile.isEmpty
                  ? Text(
                      admin.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Admin',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (admin.email.isNotEmpty)
                    Text(
                      admin.email,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chat_bubble_outline,
              size: 20,
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatItem(ChatItem chat) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.blue[100],
        child: Text(
          chat.otherUserInitial,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              chat.otherUserName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (chat.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            chat.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: chat.unreadCount > 0 ? Colors.black87 : Colors.grey[600],
              fontWeight: chat.unreadCount > 0
                  ? FontWeight.w500
                  : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            chat.formattedTime,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
      onTap: () => _openChat(chat),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new conversation above',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
    // Find the other participant
    final participants = json['participants'] as List;
    final otherParticipant = participants.firstWhere(
      (p) => p['_id'] != currentUserId,
      orElse: () => {'_id': '', 'name': 'Unknown User', 'firstName': '?'},
    );

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

// New model to represent a course with its students
class CourseWithStudents {
  final String courseId;
  final String courseTitle;
  final String courseBanner;
  final List<StudentContact> students;

  CourseWithStudents({
    required this.courseId,
    required this.courseTitle,
    required this.courseBanner,
    required this.students,
  });

  factory CourseWithStudents.fromJson(Map<String, dynamic> json) {
    final course = json['course'];
    return CourseWithStudents(
      courseId: course['id'],
      courseTitle: course['title'] ?? 'Untitled Course',
      courseBanner: course['bannerImage'] ?? '',
      students: (json['students'] as List)
          .map((student) => StudentContact.fromJson(student))
          .toList(),
    );
  }
}

class StudentContact {
  final String id;
  final String name;
  final String profile;
  final String email;

  StudentContact({
    required this.id,
    required this.name,
    required this.profile,
    required this.email,
  });

  factory StudentContact.fromJson(Map<String, dynamic> json) {
    return StudentContact(
      id: json['_id'],
      name:
          '${json["firstName"] ?? "Unknown"} ${json["lastName"] ?? "Student"}',
      profile: json["profile"] != null
          ? '${ApiConfig.baseUrl}${json["profile"]}'
          : '',
      email: json['email'] ?? '',
    );
  }
}

class AdminContact {
  final String id;
  final String name;
  final String profile;
  final String email;

  AdminContact({
    required this.id,
    required this.name,
    required this.profile,
    required this.email,
  });

  factory AdminContact.fromJson(Map<String, dynamic> json) {
    return AdminContact(
      id: json["_id"],
      name:
          json["fullName"] ??
          '${json["firstName"] ?? "Unknown"} ${json["lastName"] ?? "Admin"}',
      profile: json["profile"] != null
          ? '${ApiConfig.baseUrl}${json["profile"]}'
          : '',
      email: json['email'] ?? '',
    );
  }
}
