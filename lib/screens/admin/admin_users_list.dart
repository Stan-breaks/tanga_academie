import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/core/utils/chat.dart';
import 'package:tanga_acadamie/screens/shared/chat_page.dart';
import 'package:tanga_acadamie/screens/shared/custom_appbar.dart';
import 'package:tanga_acadamie/storage_service.dart';

class AdminUsersList extends StatefulWidget {
  const AdminUsersList({super.key});

  @override
  State<AdminUsersList> createState() => _AdminUsersListState();
}

class _AdminUsersListState extends State<AdminUsersList> {
  List<User> _users = [];
  List<User> _filteredUsers = [];
  bool _isLoading = true;
  String? _error;
  String? _currentUserId;
  String _selectedRole = 'all';
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _roleFilters = [
    {'id': 'all', 'label': 'All Users'},
    {'id': 'student', 'label': 'Students'},
    {'id': 'instructor', 'label': 'Instructors'},
    {'id': 'admin', 'label': 'Admins'},
  ];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    _currentUserId = await getCurrentUserId();
    await _getAllUsers();
  }

  Future<void> _getAllUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await getToken();
      if (token == null) {
        setState(() {
          _error = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }

      final response = await get(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/all-users'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _users = (data['users'] as List)
              .map((user) => User.fromJson(user))
              .toList();
          _filteredUsers = _users;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load users';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterUsers() {
    setState(() {
      _filteredUsers = _users.where((user) {
        // Role filter
        final matchesRole =
            _selectedRole == 'all' || user.role == _selectedRole;

        // Search filter
        final searchQuery = _searchController.text.toLowerCase();
        final matchesSearch =
            searchQuery.isEmpty ||
            user.firstName.toLowerCase().contains(searchQuery) ||
            user.lastName.toLowerCase().contains(searchQuery) ||
            user.email.toLowerCase().contains(searchQuery);

        return matchesRole && matchesSearch;
      }).toList();
    });
  }

  int _getRoleCount(String role) {
    if (role == 'all') return _users.length;
    return _users.where((u) => u.role == role).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppbar(isLoggedIn: true),
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Header with search
          _buildHeader(),

          // Role filter pills
          _buildRoleFilters(),

          // User list
          Expanded(
            child: RefreshIndicator(
              color: Colors.blueAccent,
              onRefresh: _getAllUsers,
              child: _isLoading
                  ? _buildLoadingState()
                  : _error != null
                  ? _buildErrorState()
                  : _buildUserList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.people,
                  color: Colors.blueAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'User Management',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_users.length} total users',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search bar
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _filterUsers(),
              decoration: InputDecoration(
                hintText: 'Search users...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey.shade500),
                        onPressed: () {
                          _searchController.clear();
                          _filterUsers();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _roleFilters.map((filter) {
            final isSelected = _selectedRole == filter['id'];
            final count = _getRoleCount(filter['id']!);

            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedRole = filter['id']!;
                  });
                  _filterUsers();
                },
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blueAccent : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected
                          ? Colors.blueAccent
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _getRoleIcon(filter['id']!, isSelected),
                      const SizedBox(width: 6),
                      Text(
                        filter['label']!,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade700,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withAlpha(50)
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _getRoleIcon(String role, bool isSelected) {
    Color color = isSelected ? Colors.white : Colors.grey.shade600;
    IconData icon;

    switch (role) {
      case 'student':
        icon = Icons.school;
        color = isSelected ? Colors.white : Colors.green;
        break;
      case 'instructor':
        icon = Icons.architecture;
        color = isSelected ? Colors.white : Colors.blue;
        break;
      case 'admin':
        icon = Icons.admin_panel_settings;
        color = isSelected ? Colors.white : Colors.purple;
        break;
      default:
        icon = Icons.people;
    }

    return Icon(icon, size: 16, color: color);
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 3),
          SizedBox(height: 20),
          Text(
            'Loading users...',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Error loading users',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _getAllUsers,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList() {
    if (_filteredUsers.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        return _buildUserCard(_filteredUsers[index]);
      },
    );
  }

  Widget _buildUserCard(User user) {
    final fullName = '${user.firstName} ${user.lastName}'.trim();
    final roleColor = _getRoleColor(user.role);

    String formattedDate = '';
    if (user.createdAt.isNotEmpty) {
      try {
        final date = DateTime.parse(user.createdAt);
        formattedDate = DateFormat('MMM d, yyyy').format(date);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showUserDetails(user),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 28,
                  backgroundImage: user.profile.isNotEmpty
                      ? NetworkImage('${ApiConfig.baseUrl}${user.profile}')
                      : null,
                  backgroundColor: roleColor.withAlpha(30),
                  child: user.profile.isEmpty
                      ? Text(
                          fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: roleColor,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),

                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isEmpty ? 'Unknown User' : fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Role badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: roleColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getRoleIconData(user.role),
                                  size: 12,
                                  color: roleColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  user.role.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: roleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (formattedDate.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'student':
        return Colors.green;
      case 'instructor':
        return Colors.blue;
      case 'admin':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIconData(String role) {
    switch (role) {
      case 'student':
        return Icons.school;
      case 'instructor':
        return Icons.architecture;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  Widget _buildEmptyState() {
    String message = _searchController.text.isNotEmpty
        ? 'No users found matching your search'
        : 'No ${_selectedRole == 'all' ? 'users' : '${_selectedRole}s'} found';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_off_outlined,
              size: 56,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(User user) {
    final fullName = '${user.firstName} ${user.lastName}'.trim();
    final roleColor = _getRoleColor(user.role);

    String formattedDate = '';
    if (user.createdAt.isNotEmpty) {
      try {
        final date = DateTime.parse(user.createdAt);
        formattedDate = DateFormat('MMMM d, yyyy • h:mm a').format(date);
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Avatar
            CircleAvatar(
              radius: 50,
              backgroundImage: user.profile.isNotEmpty
                  ? NetworkImage('${ApiConfig.baseUrl}${user.profile}')
                  : null,
              backgroundColor: roleColor.withAlpha(30),
              child: user.profile.isEmpty
                  ? Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 36,
                        color: roleColor,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),

            // Name
            Text(
              fullName.isEmpty ? 'Unknown User' : fullName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: roleColor.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getRoleIconData(user.role), size: 16, color: roleColor),
                  const SizedBox(width: 6),
                  Text(
                    user.role.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: roleColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildDetailRow(Icons.person_outlined, 'Bio', user.bio),
            const SizedBox(height: 12),
            // Details
            _buildDetailRow(Icons.email_outlined, 'Email', user.email),
            const SizedBox(height: 12),
            if (formattedDate.isNotEmpty) ...[
              _buildDetailRow(Icons.calendar_today, 'Joined', formattedDate),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await startChat(participantId: user.id);
                      if (result.isSuccess) {
                        final chatData = result.data;
                        final chatId = chatData['_id'] ?? chatData['chatId'];
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              chatId: chatId,
                              userId: _currentUserId!,
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.message),
                    label: const Text('Message'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                      side: const BorderSide(color: Colors.blueAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class User {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String profile;
  final String bio;
  final String createdAt;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.profile,
    required this.bio,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      profile: json['profile'] ?? '',
      bio: json['bio'] ?? 'No bio yet',
      createdAt: json['createdAt'] ?? '',
    );
  }
}
