import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:tanga_acadamie/core/utils/app_snackbar.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/models/message.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';
import 'package:tanga_acadamie/core/theme/app_theme.dart';
import 'package:tanga_acadamie/core/widgets/app_network_image.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  final String userId;

  const ChatPage({super.key, required this.chatId, required this.userId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  Socket? socket;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  bool _isLoading = true;
  bool _isConnected = false;
  String _otherUserName = 'Chat';
  String? _profile;
  bool _isTyping = false;
  bool _isOtherTyping = false;
  String? _token;
  List<PlatformFile> _pendingFiles = [];
  Timer? _reconnectTimer;
  Timer? _typingResetTimer;
  Timer? _otherTypingResetTimer;
  bool _shouldReconnect = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reconnect when app comes back to foreground
      if (!_isConnected && _shouldReconnect) {
        _reconnectSocket();
      }
    } else if (state == AppLifecycleState.paused) {
      // Keep socket alive but don't force reconnect
    }
  }

  Future<void> _initialize() async {
    await _loadToken();
    _initSocket();
    await _fetchChatMessages();
  }

  Future<void> _loadToken() async {
    _token = await getToken();
  }

  void _initSocket() {
    if (_token == null) {
      return;
    }

    try {
      socket = io(
        ApiConfig.baseUrl,
        OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(10)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setAuth({'token': _token})
            .build(),
      );

      socket!.onConnect((_) {
        debugPrint('Socket connected');
        if (mounted) {
          setState(() => _isConnected = true);
        }

        socket!.emit('join_chat', widget.chatId);

        _reconnectTimer?.cancel();
      });

      socket!.onDisconnect((_) {
        debugPrint('Socket disconnected');
        if (mounted) {
          setState(() => _isConnected = false);
        }

        if (_shouldReconnect) {
          _scheduleReconnect();
        }
      });

      socket!.onConnectError((error) {
        debugPrint('Socket connection error: $error');
        if (mounted) {
          setState(() => _isConnected = false);
        }

        // Schedule reconnection attempt
        if (_shouldReconnect) {
          _scheduleReconnect();
        }
      });

      socket!.onError((error) {
        debugPrint('Socket error: $error');
      });

      // Listen for new messages - this is the key for real-time updates
      socket!.on('new_message', _handleNewMessage);

      socket!.on('user_typing', (data) {
        if (data['userId'] != widget.userId && mounted) {
          if (data['typing']) {
            setState(() => _isTyping = true);
          } else {
            _typingResetTimer?.cancel();
            _typingResetTimer = Timer(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() => _isTyping = false);
              }
            });
          }
        }
      });

      socket!.connect();
    } catch (e) {
      debugPrint('Socket initialization error: $e');
    }
  }

  void _handleNewMessage(dynamic data) {
    if (!mounted) return;

    debugPrint('Received new message: $data');

    if (data is! Map) return;
    final raw = data['message'] ?? data;
    if (raw is! Map) return;
    final newMessage = Message.fromJson(Map<String, dynamic>.from(raw));

    // Skip our own messages
    if (newMessage.senderId == widget.userId) {
      return;
    }

    final exists = _messages.any(
      (msg) =>
          (msg.id == newMessage.id && msg.id.isNotEmpty) ||
          (msg.senderId == newMessage.senderId &&
              msg.content == newMessage.content &&
              msg.timestamp.difference(newMessage.timestamp).inSeconds.abs() <
                  5),
    );

    if (!exists) {
      setState(() {
        _messages.add(newMessage);
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_shouldReconnect && !_isConnected && mounted) {
        _reconnectSocket();
      }
    });
  }

  void _reconnectSocket() {
    if (socket != null) {
      try {
        socket!.disconnect();
        socket!.dispose();
      } catch (e) {
        debugPrint('Error disposing socket: $e');
      }
    }
    _initSocket();
  }

  Future<void> _fetchChatMessages() async {
    if (_token == null) {
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/chats/${widget.chatId}'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final chatData = data['data'];

        if (mounted) {
          setState(() {
            _messages.clear();
            if (chatData['messages'] != null) {
              for (var msg in chatData['messages']) {
                _messages.add(Message.fromJson(msg));
              }
              _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            }

            if (chatData['participants'] != null) {
              final participants = chatData['participants'] as List;
              final otherParticipant = participants.firstWhere(
                (p) => p['_id'] != widget.userId,
                orElse: () => null,
              );

              if (otherParticipant != null) {
                _otherUserName =
                    otherParticipant['name'] ??
                    '${otherParticipant['firstName'] ?? ''} ${otherParticipant['lastName'] ?? ''}'
                        .trim();
                final profileValue =
                    otherParticipant['profile'] ??
                    otherParticipant['profileImage'];
                final profilePath = profileValue is Map
                    ? (profileValue['url'] ?? profileValue['path'])?.toString()
                    : profileValue?.toString();
                final resolvedProfile = ApiConfig.getImageUrl(profilePath);
                _profile = resolvedProfile.isEmpty ? null : resolvedProfile;
              }
            }

            _isLoading = false;
          });
          _scrollToBottom();
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _token == null) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    final tempMessage = Message(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      senderId: widget.userId,
      content: messageText,
      createdAt: DateTime.now(),
      readBy: [],
    );

    setState(() {
      _messages.add(tempMessage);
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
    _scrollToBottom();

    if (_isConnected && socket != null) {
      socket!.emit('typing_stop', widget.chatId);
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/chats/${widget.chatId}/messages'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'content': messageText}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == tempMessage.id);
            if (index != -1 && data['data']?['_id'] != null) {
              _messages[index] = Message(
                id: data['data']['_id'],
                senderId: widget.userId,
                content: messageText,
                createdAt: tempMessage.timestamp,
                readBy: [],
              );
            }
          });
        }
      } else {
        // Remove failed message
        if (mounted) {
          setState(() {
            _messages.removeWhere((m) => m.id == tempMessage.id);
          });
          AppSnackBar.showError(context, isFr ? 'Échec de l\'envoi du message' : 'Failed to send message');
        }
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      // Remove failed message
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == tempMessage.id);
        });
        AppSnackBar.showError(context, isFr ? 'Erreur lors de l\'envoi du message' : 'Error sending message');
      }
    }
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || !mounted) return;

    final newFiles = result.files.where((f) => f.path != null).toList();
    setState(() {
      _pendingFiles = [..._pendingFiles, ...newFiles].take(5).toList();
    });
  }

  Future<void> _sendMessageWithFiles() async {
    if (_token == null) return;
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty && _pendingFiles.isEmpty) return;

    _messageController.clear();
    final filesToSend = List<PlatformFile>.from(_pendingFiles);
    setState(() => _pendingFiles = []);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/api/chats/${widget.chatId}/messages'),
      );
      request.headers['Authorization'] = 'Bearer $_token';
      request.fields['content'] = messageText;

      for (final file in filesToSend) {
        if (file.path != null) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'attachments',
              file.path!,
              contentType: _contentTypeForExtension(file.extension ?? ''),
            ),
          );
        }
      }

      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);

      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        try {
          final data = json.decode(res.body);
          final msgData = data['data'] ?? data;
          if (msgData is Map) {
            final sent = Message.fromJson(Map<String, dynamic>.from(msgData));
            setState(() {
              _messages.add(sent);
              _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            });
          }
        } catch (_) {}
        _scrollToBottom();
      } else {
        AppSnackBar.showError(
          context,
          isFr ? 'Échec de l\'envoi du fichier' : 'Failed to send attachment',
        );
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showError(
        context,
        isFr ? 'Erreur lors de l\'envoi du fichier' : 'Error sending attachment',
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onTypingChanged(String text) {
    if (!_isConnected || socket == null) return;
    _otherTypingResetTimer?.cancel();
    if (!_isOtherTyping) {
      setState(() => _isOtherTyping = true);
      socket!.emit('typing_start', widget.chatId);
    }

    _otherTypingResetTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isOtherTyping = false);
      }
      socket!.emit('typing_stop', widget.chatId);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _typingResetTimer?.cancel();
    _otherTypingResetTimer?.cancel();

    if (socket != null) {
      try {
        socket!.emit('leave_chat', widget.chatId);
        socket!.emit('typing_stop', widget.chatId);
        socket!.disconnect();
        socket!.dispose();
      } catch (e) {
        debugPrint('Error disposing socket: $e');
      }
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary100,
                    AppColors.primary400,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.transparent,
                backgroundImage: _profile != null
                    ? NetworkImage(_profile!)
                    : null,
                child: Text(
                  _otherUserName.isNotEmpty
                      ? _otherUserName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _otherUserName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _isConnected ? AppColors.success : AppColors.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isTyping
                            ? (isFr ? 'en train d\'écrire...' : 'typing...')
                            : (_isConnected ? '' : (isFr ? 'Connexion...' : 'Connecting...')),
                        style: TextStyle(
                          fontSize: 11,
                          color: _isTyping
                              ? AppColors.primary
                              : (_isConnected ? AppColors.success : AppColors.warning),
                          fontStyle: _isTyping
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!_isConnected)
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.warning),
              onPressed: _reconnectSocket,
              tooltip: isFr ? 'Reconnecter' : 'Reconnect',
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              AppSnackBar.showSuccess(context, isFr ? 'Options de chat bientôt disponibles !' : 'Chat options coming soon!');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status banner
          if (!_isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: AppColors.warning100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.warning),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isFr ? 'Connexion au chat...' : 'Connecting to chat...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.warning800,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isFr ? 'Chargement des messages...' : 'Loading messages...',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: AppColors.primary200,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isFr ? 'Aucun message' : 'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isFr ? 'Démarrez la conversation !' : 'Start the conversation!',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Show typing indicator at the end
                      if (_isTyping && index == _messages.length) {
                        return _buildTypingIndicator();
                      }

                      final message = _messages[index];
                      final isMe = message.senderId == widget.userId;
                      final showDate =
                          index == 0 ||
                          !_isSameDay(
                            _messages[index - 1].timestamp,
                            message.timestamp,
                          );

                      return Column(
                        children: [
                          if (showDate) _buildDateDivider(message.timestamp),
                          _buildMessageBubble(message, isMe),
                        ],
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pendingFiles.isNotEmpty) ...[
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: _pendingFiles.length,
                        itemBuilder: (_, i) => Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withAlpha(60),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.attach_file,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _pendingFiles[i].name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => setState(
                                  () => _pendingFiles.removeAt(i),
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: AppColors.primary.withAlpha(180),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.attach_file,
                          color: _pendingFiles.isNotEmpty
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        onPressed:
                            _pendingFiles.length < 5 ? _pickAttachment : null,
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: isFr
                                  ? 'Écrivez un message...'
                                  : 'Type a message...',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: _onTypingChanged,
                            onSubmitted: (_) => _pendingFiles.isEmpty
                                ? _sendMessage()
                                : _sendMessageWithFiles(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary200,
                              AppColors.primary700,
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: _pendingFiles.isEmpty
                              ? _sendMessage
                              : _sendMessageWithFiles,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.borderLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 600 + (index * 200)),
              builder: (context, value, child) {
                return Container(
                  margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.textLight.withAlpha(
                      (100 + (value * 155)).toInt(),
                    ),
                    shape: BoxShape.circle,
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    final isPending = message.id.startsWith('temp-');

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        decoration: BoxDecoration(
          gradient: isMe
              ? LinearGradient(
                  colors: [
                    AppColors.primary200,
                    AppColors.primary400,
                  ],
                )
              : null,
          color: isMe ? null : AppColors.borderLight,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (message.content.isNotEmpty)
              Text(
                message.content,
                style: TextStyle(
                  color: isMe ? Colors.white : AppColors.textDark,
                  fontSize: 15,
                ),
              ),
            if (message.attachments.isNotEmpty)
              _buildAttachmentList(message, isMe),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(message.timestamp),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isPending ? Icons.access_time : Icons.done_all,
                    size: 14,
                    color: isPending ? Colors.white54 : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentList(Message message, bool isMe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: message.attachments.map((att) {
        if (att.isImage) {
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: AppNetworkImage(
                url: att.fullUrl,
                width: 200,
                fit: BoxFit.cover,
                errorWidget: _buildFileChip(att, isMe),
              ),
            ),
          );
        }
        return _buildFileChip(att, isMe);
      }).toList(),
    );
  }

  Widget _buildFileChip(MessageAttachment att, bool isMe) {
    final color = isMe ? Colors.white : AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withAlpha(40) : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_file, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              att.filename ?? 'Attachment',
              style: TextStyle(color: color, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Returns the correct MIME type for a file extension, or null so the
  /// default (application/octet-stream) is used.
  MediaType? _contentTypeForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'doc':
        return MediaType('application', 'msword');
      case 'docx':
        return MediaType(
          'application',
          'vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
      case 'xls':
        return MediaType('application', 'vnd.ms-excel');
      case 'xlsx':
        return MediaType(
          'application',
          'vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      case 'txt':
        return MediaType('text', 'plain');
      case 'zip':
        return MediaType('application', 'zip');
      case 'mp4':
        return MediaType('video', 'mp4');
      case 'mp3':
        return MediaType('audio', 'mpeg');
      default:
        return null;
    }
  }

  Widget _buildDateDivider(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.borderLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDate(date),
            style: TextStyle(fontSize: 12, color: AppColors.textDark),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return isFr ? 'Aujourd\'hui' : 'Today';
    } else if (messageDate == yesterday) {
      return isFr ? 'Hier' : 'Yesterday';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
