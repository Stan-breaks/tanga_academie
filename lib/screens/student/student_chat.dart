import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';

class StudentChatPage extends StatefulWidget {
  final String chatId;
  final String userId;

  const StudentChatPage({
    super.key,
    required this.chatId,
    required this.userId,
  });

  @override
  State<StudentChatPage> createState() => _StudentChatPageState();
}

class _StudentChatPageState extends State<StudentChatPage>
    with TickerProviderStateMixin {
  late Socket socket;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  bool _isLoading = true;
  bool _isConnected = false;
  String _otherUserName = 'Chat';
  bool _isTyping = false;
  String? _token;
  List<PlatformFile> _pendingFiles = [];
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadToken();
    _initSocket();
    _fetchChatMessages();
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
            .setExtraHeaders({'authorization': 'Bearer $_token'})
            .build(),
      );

      socket.onConnect((_) {
        debugPrint('Socket connected');
        if (mounted) {
          setState(() => _isConnected = true);
        }

        socket.emit('authenticate', {'userId': widget.userId, 'token': _token});
        socket.emit('join_chat', widget.chatId);
      });

      socket.onDisconnect((_) {
        debugPrint('Socket disconnected');
        if (mounted) {
          setState(() => _isConnected = false);
        }
      });

      socket.onConnectError((error) {
        debugPrint('Socket connection error: $error');
        if (mounted) {
          setState(() => _isConnected = false);
        }
      });

      // Listen for new messages on multiple events for compatibility
      socket.on('new_message', _handleNewMessage);
      socket.on('receive_message', _handleNewMessage);
      socket.on('message', _handleNewMessage);

      socket.on('user_typing', (data) {
        if (data['userId'] != widget.userId && mounted) {
          setState(() => _isTyping = true);
          // Auto-reset typing after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() => _isTyping = false);
            }
          });
        }
      });

      socket.on('user_stopped_typing', (data) {
        if (data['userId'] != widget.userId && mounted) {
          setState(() => _isTyping = false);
        }
      });

      socket.connect();
    } catch (e) {
      debugPrint('Socket initialization error: $e');
    }
  }

  void _handleNewMessage(dynamic data) {
    if (!mounted) return;

    debugPrint('Received new message: $data');

    final senderId =
        data['senderId'] ?? data['sender']?['_id'] ?? data['sender'];

    // Skip our own messages
    if (senderId == widget.userId) {
      return;
    }

    final newMessage = Message.fromJson(data);

    // Check for duplicates
    final exists = _messages.any(
      (msg) =>
          (msg.id == newMessage.id && msg.id.isNotEmpty) ||
          (msg.senderId == senderId &&
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
            }
          }

          _isLoading = false;
        });
        _fadeController.forward();
        _scrollToBottom();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _token == null) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

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

        final newMessage = Message(
          id:
              data['data']?['_id'] ??
              'temp-${DateTime.now().millisecondsSinceEpoch}',
          senderId: widget.userId,
          content: messageText,
          timestamp: DateTime.now(),
          readBy: [],
        );

        setState(() {
          _messages.add(newMessage);
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });

        if (_isConnected) {
          socket.emit('send_message', {
            'chatId': widget.chatId,
            'content': messageText,
            'senderId': widget.userId,
            'attachments': [],
          });
        }

        _scrollToBottom();

        Future.delayed(const Duration(milliseconds: 500), () {
          _fetchChatMessages();
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  isFr
                      ? 'Échec de l\'envoi du message'
                      : 'Failed to send message',
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text(
                isFr
                    ? 'Erreur lors de l\'envoi du message'
                    : 'Error sending message',
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result != null) {
      final newFiles = result.files.where((f) => f.path != null).toList();
      setState(() {
        _pendingFiles = [..._pendingFiles, ...newFiles].take(5).toList();
      });
    }
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
      if (messageText.isNotEmpty) request.fields['content'] = messageText;

      for (final file in filesToSend) {
        if (file.path != null) {
          final ext = file.extension ?? 'bin';
          request.files.add(
            await http.MultipartFile.fromPath(
              'attachments',
              file.path!,
              contentType: MediaType('application', ext),
            ),
          );
        }
      }

      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);

      if ((res.statusCode == 200 || res.statusCode == 201) && mounted) {
        Future.delayed(const Duration(milliseconds: 500), _fetchChatMessages);
        _scrollToBottom();
      }
    } catch (_) {}
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
    if (text.isNotEmpty && _isConnected) {
      socket.emit('typing_start', {
        'chatId': widget.chatId,
        'userId': widget.userId,
      });
    } else if (_isConnected) {
      socket.emit('typing_stop', {
        'chatId': widget.chatId,
        'userId': widget.userId,
      });
    }
  }

  @override
  void dispose() {
    if (_isConnected) {
      socket.emit('leave_chat', widget.chatId);
      socket.emit('typing_stop', {
        'chatId': widget.chatId,
        'userId': widget.userId,
      });
    }
    socket.disconnect();
    socket.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          color: Colors.blueAccent,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Loading messages...',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : _messages.isEmpty
                ? _buildEmptyChat()
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMe = message.senderId == widget.userId;
                        final showDate =
                            index == 0 ||
                            !_isSameDay(
                              _messages[index - 1].timestamp,
                              message.timestamp,
                            );
                        final showAvatar =
                            !isMe &&
                            (index == 0 ||
                                _messages[index - 1].senderId !=
                                    message.senderId);

                        return Column(
                          children: [
                            if (showDate) _buildDateDivider(message.timestamp),
                            _buildMessageBubble(message, isMe, showAvatar),
                          ],
                        );
                      },
                    ),
                  ),
          ),
          if (_isTyping) _buildTypingIndicator(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
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
            ),
            child: Center(
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
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isConnected
                            ? Colors.green.shade400
                            : Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isTyping
                          ? 'typing...'
                          : (_isConnected
                                ? (isFr ? 'En ligne' : 'Online')
                                : (isFr ? 'Hors ligne' : 'Offline')),
                      style: TextStyle(
                        fontSize: 12,
                        color: _isTyping
                            ? Colors.blueAccent
                            : (_isConnected
                                  ? Colors.green.shade600
                                  : Colors.grey.shade500),
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
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.blueAccent),
          onPressed: _fetchChatMessages,
          tooltip: 'Refresh',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.black54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$value coming soon!'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'Clear chat', child: Text('Clear chat')),
            const PopupMenuItem(value: 'Block', child: Text('Block user')),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.blueAccent.shade200,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isFr ? 'Aucun message' : 'No messages yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFr
                ? 'Envoyez un message pour commencer la conversation !'
                : 'Send a message to start the conversation!',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTypingDot(0),
            const SizedBox(width: 4),
            _buildTypingDot(1),
            const SizedBox(width: 4),
            _buildTypingDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.blueAccent.withAlpha((150 * value).toInt() + 50),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe, bool showAvatar) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 6,
        left: isMe ? 48 : 0,
        right: isMe ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blueAccent.shade100,
                    Colors.blueAccent.shade400,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _otherUserName.isNotEmpty
                      ? _otherUserName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else if (!isMe)
            const SizedBox(width: 40),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isMe
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blueAccent.shade400,
                          Colors.blueAccent.shade700,
                        ],
                      )
                    : null,
                color: isMe ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isMe
                        ? Colors.blueAccent.withAlpha(40)
                        : Colors.black.withAlpha(8),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(
                      color: isMe ? Colors.white60 : Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateDivider(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _formatDate(date),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300, height: 1)),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, -4),
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
                      color: Colors.blueAccent.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.blueAccent.withAlpha(60),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.attach_file,
                          size: 14,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _pendingFiles[i].name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blueAccent,
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
                            color: Colors.blueAccent.withAlpha(180),
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
                        ? Colors.blueAccent
                        : Colors.grey.shade600,
                  ),
                  onPressed: _pendingFiles.length < 5 ? _pickAttachment : null,
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: isFr
                            ? 'Tapez un message...'
                            : 'Type a message...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
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
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blueAccent.shade400,
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
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
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

class Message {
  final String id;
  final String senderId;
  final String content;
  final DateTime timestamp;
  final List<String> readBy;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
    required this.readBy,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    String senderId;
    if (json['sender'] is String) {
      senderId = json['sender'];
    } else if (json['sender'] is Map) {
      senderId = json['sender']['_id'] ?? '';
    } else if (json['senderId'] != null) {
      senderId = json['senderId'];
    } else {
      senderId = '';
    }

    return Message(
      id: json['_id'] ?? '',
      senderId: senderId,
      content: json['content'] ?? '',
      timestamp: DateTime.parse(
        json['timestamp'] ??
            json['createdAt'] ??
            DateTime.now().toIso8601String(),
      ),
      readBy:
          (json['readBy'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
