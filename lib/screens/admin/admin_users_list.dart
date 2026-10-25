import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/core/utils/chat.dart';
import 'package:tanga_acadamie/screens/shared/chat_page.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';

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

  List<Map<String, String>> get _roleFilters => [
    {'id': 'all', 'label': isFr ? 'Tous les utilisateurs' : 'All Users'},
    {'id': 'student', 'label': isFr ? 'Étudiants' : 'Students'},
    {'id': 'instructor', 'label': isFr ? 'Instructeurs' : 'Instructors'},
    {'id': 'admin', 'label': isFr ? 'Admins' : 'Admins'},
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
    if (!mounted) return;
    await _getAllUsers();
  }

  Future<void> _getAllUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await getToken();
      if (!mounted) return;
      if (token == null) {
        setState(() {
          _error = isFr ? 'Non authentifié' : 'Not authenticated';
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
        if (!mounted) return;
        // Normalize {success, users:[...]} / {success, data:[...]} envelopes.
        final raw = data is Map ? (data['users'] ?? data['data']) : data;
        final users = raw is List ? raw : const [];
        setState(() {
          _users = users
              .map((user) => User.fromJson(user as Map<String, dynamic>))
              .toList();
          _filteredUsers = _users;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = isFr ? 'Échec du chargement des utilisateurs' : 'Failed to load users';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
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
      appBar: AppBar(),
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header with search
          _buildHeader(),

          // Role filter pills
          _buildRoleFilters(),

          // User list
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
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
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.people,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFr ? 'Gestion des utilisateurs' : 'User Management',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_users.length} ${isFr ? 'utilisateurs au total' : 'total users'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
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
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _filterUsers(),
              decoration: InputDecoration(
                hintText: isFr
                    ? 'Rechercher des utilisateurs...'
                    : 'Search users...',
                hintStyle: TextStyle(color: AppColors.textLight),
                prefixIcon: Icon(Icons.search, color: AppColors.textLight),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: AppColors.textLight),
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
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
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
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.border,
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
                              : AppColors.textDark,
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
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textDark,
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
    Color color = isSelected ? Colors.white : AppColors.textSecondary;
    IconData icon;

    switch (role) {
      case 'student':
        icon = Icons.school;
        color = isSelected ? Colors.white : AppColors.success;
        break;
      case 'instructor':
        icon = Icons.architecture;
        color = isSelected ? Colors.white : AppColors.primary;
        break;
      case 'admin':
        icon = Icons.admin_panel_settings;
        color = isSelected ? Colors.white : AppColors.secondary;
        break;
      default:
        icon = Icons.people;
    }

    return Icon(icon, size: 16, color: color);
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
            isFr ? 'Chargement des utilisateurs...' : 'Loading users...',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
            Icon(Icons.error_outline, size: 64, color: AppColors.error300),
            const SizedBox(height: 16),
            Text(
              isFr
                  ? 'Erreur de chargement des utilisateurs'
                  : 'Error loading users',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _getAllUsers,
              icon: const Icon(Icons.refresh),
              label: Text(isFr ? 'Réessayer' : 'Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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
                        fullName.isEmpty ? (isFr ? 'Utilisateur inconnu' : 'Unknown User') : fullName,
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
                            color: AppColors.textLight,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
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
                              color: AppColors.textLight,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow
                Icon(Icons.chevron_right, color: AppColors.textHint),
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
        return AppColors.success;
      case 'instructor':
        return AppColors.primary;
      case 'admin':
        return AppColors.secondary;
      default:
        return AppColors.textSecondary;
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
        ? (isFr
              ? 'Aucun utilisateur trouvé'
              : 'No users found matching your search')
        : (isFr
              ? 'Aucun ${_selectedRole == 'all' ? 'utilisateur' : _selectedRole} trouvé'
              : 'No ${_selectedRole == 'all' ? 'users' : '${_selectedRole}s'} found');

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_off_outlined,
              size: 56,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
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
                  color: AppColors.border,
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
              fullName.isEmpty ? (isFr ? 'Utilisateur inconnu' : 'Unknown User') : fullName,
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

            _buildDetailRow(
              Icons.person_outlined,
              isFr ? 'Bio' : 'Bio',
              user.bio,
            ),
            const SizedBox(height: 12),
            // Details
            _buildDetailRow(
              Icons.email_outlined,
              isFr ? 'Email' : 'Email',
              user.email,
            ),
            const SizedBox(height: 12),
            if (formattedDate.isNotEmpty) ...[
              _buildDetailRow(
                Icons.calendar_today,
                isFr ? 'Inscrit le' : 'Joined',
                formattedDate,
              ),
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
                    label: Text(isFr ? 'Message' : 'Message'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
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
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
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
      bio: json['bio'] ?? (isFr ? 'Aucune bio pour le moment' : 'No bio yet'),
      createdAt: json['createdAt'] ?? '',
    );
  }
}
