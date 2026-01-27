import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/storage_service.dart';

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
  bool _isTyping = false;
  String? _token;
  Timer? _reconnectTimer;
  Timer? _typingResetTimer;
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
            .setExtraHeaders({'authorization': 'Bearer $_token'})
            .build(),
      );

      socket!.onConnect((_) {
        debugPrint('Socket connected');
        if (mounted) {
          setState(() => _isConnected = true);
        }

        // Authenticate and join chat
        socket!.emit('authenticate', {'userId': widget.userId, 'token': _token});
        socket!.emit('join_chat', widget.chatId);
        
        // Cancel any pending reconnect timers
        _reconnectTimer?.cancel();
      });

      socket!.onDisconnect((_) {
        debugPrint('Socket disconnected');
        if (mounted) {
          setState(() => _isConnected = false);
        }
        
        // Schedule reconnection attempt
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
      socket!.on('receive_message', _handleNewMessage);
      socket!.on('message', _handleNewMessage);

      // Listen for typing events
      socket!.on('user_typing', (data) {
        if (data['userId'] != widget.userId && mounted) {
          setState(() => _isTyping = true);
          
          // Auto-reset typing indicator after 3 seconds
          _typingResetTimer?.cancel();
          _typingResetTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() => _isTyping = false);
            }
          });
        }
      });

      socket!.on('user_stopped_typing', (data) {
        if (data['userId'] != widget.userId && mounted) {
          setState(() => _isTyping = false);
          _typingResetTimer?.cancel();
        }
      });

      // Connect the socket
      socket!.connect();
      
    } catch (e) {
      debugPrint('Socket initialization error: $e');
    }
  }

  void _handleNewMessage(dynamic data) {
    if (!mounted) return;
    
    debugPrint('Received new message: $data');
    
    final senderId = data['senderId'] ?? data['sender']?['_id'] ?? data['sender'];

    // Skip our own messages (we add them locally when sending)
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
           msg.timestamp.difference(newMessage.timestamp).inSeconds.abs() < 5),
    );

    if (!exists) {
      setState(() {
        _messages.add(newMessage);
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        _isTyping = false; // Stop typing indicator when message received
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

    // Optimistically add the message to the UI immediately
    final tempMessage = Message(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      senderId: widget.userId,
      content: messageText,
      timestamp: DateTime.now(),
      readBy: [],
    );

    setState(() {
      _messages.add(tempMessage);
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
    _scrollToBottom();

    // Stop typing indicator
    if (_isConnected && socket != null) {
      socket!.emit('typing_stop', {
        'chatId': widget.chatId,
        'userId': widget.userId,
      });
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

        // Update temp message with real ID
        if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == tempMessage.id);
            if (index != -1 && data['data']?['_id'] != null) {
              _messages[index] = Message(
                id: data['data']['_id'],
                senderId: widget.userId,
                content: messageText,
                timestamp: tempMessage.timestamp,
                readBy: [],
              );
            }
          });
        }

        // Emit socket event for real-time delivery to other user
        if (_isConnected && socket != null) {
          socket!.emit('send_message', {
            'chatId': widget.chatId,
            'content': messageText,
            'senderId': widget.userId,
            'attachments': [],
          });
        }
      } else {
        // Remove failed message
        if (mounted) {
          setState(() {
            _messages.removeWhere((m) => m.id == tempMessage.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send message')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      // Remove failed message
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == tempMessage.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error sending message')),
        );
      }
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

  Timer? _typingDebounceTimer;

  void _onTypingChanged(String text) {
    if (!_isConnected || socket == null) return;
    
    _typingDebounceTimer?.cancel();
    
    if (text.isNotEmpty) {
      socket!.emit('typing_start', {
        'chatId': widget.chatId,
        'userId': widget.userId,
      });
      
      // Stop typing after 2 seconds of no input
      _typingDebounceTimer = Timer(const Duration(seconds: 2), () {
        if (_isConnected && socket != null) {
          socket!.emit('typing_stop', {
            'chatId': widget.chatId,
            'userId': widget.userId,
          });
        }
      });
    } else {
      socket!.emit('typing_stop', {
        'chatId': widget.chatId,
        'userId': widget.userId,
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _typingResetTimer?.cancel();
    _typingDebounceTimer?.cancel();
    
    if (socket != null) {
      try {
        socket!.emit('leave_chat', widget.chatId);
        socket!.emit('typing_stop', {
          'chatId': widget.chatId,
          'userId': widget.userId,
        });
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
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blueAccent.shade100,
                    Colors.blueAccent.shade400,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.transparent,
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
                          color: _isConnected ? Colors.green : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isTyping
                            ? 'typing...'
                            : (_isConnected ? 'Online' : 'Connecting...'),
                        style: TextStyle(
                          fontSize: 11,
                          color: _isTyping 
                              ? Colors.blueAccent 
                              : (_isConnected ? Colors.green : Colors.orange),
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
              icon: const Icon(Icons.refresh, color: Colors.orange),
              onPressed: _reconnectSocket,
              tooltip: 'Reconnect',
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat options coming soon!')),
              );
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
              color: Colors.orange.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.orange),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Connecting to chat...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
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
                        const CircularProgressIndicator(color: Colors.blueAccent),
                        const SizedBox(height: 16),
                        Text(
                          'Loading messages...',
                          style: TextStyle(color: Colors.grey.shade600),
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
                            color: Colors.blueAccent.withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: Colors.blueAccent.shade200,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
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
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.attach_file, color: Colors.grey.shade600),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Attachments coming soon!'),
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: _onTypingChanged,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blueAccent.shade200,
                          Colors.blueAccent.shade700,
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
                      onPressed: _sendMessage,
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

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
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
                    color: Colors.grey.shade500.withAlpha((100 + (value * 155)).toInt()),
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
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          gradient: isMe
              ? LinearGradient(
                  colors: [
                    Colors.blueAccent.shade200,
                    Colors.blueAccent.shade400,
                  ],
                )
              : null,
          color: isMe ? null : Colors.grey.shade200,
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
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(message.timestamp),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.black54,
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

  Widget _buildDateDivider(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDate(date),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
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
      id: json['_id'] ?? json['id'] ?? '',
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
