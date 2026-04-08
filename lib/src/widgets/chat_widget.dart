import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';

class ChatWidget extends StatefulWidget {
  final String? rideId;
  final String? buddyId;
  final String? groupId;
  final String title;

  const ChatWidget({super.key, this.rideId, this.buddyId, this.groupId, required this.title});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _messages = [];
  IO.Socket? _socket;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _setupChat();
  }

  Future<void> _setupChat() async {
    final user = await _authService.getUser();
    _userId = user['id']?.toString();
    
    // Fetch History
    try {
      Response response;
      if (widget.rideId != null) {
        response = await _apiService.getRideMessages(widget.rideId!);
      } else if (widget.groupId != null) {
        response = await _apiService.getGroupMessages(widget.groupId!);
      } else {
        response = await _apiService.getBuddyMessages(widget.buddyId!);
      }
      
      setState(() {
        _messages = response.data;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error fetching history: $e');
    }

    // Connect Socket with auth token
    final token = await const FlutterSecureStorage().read(key: 'jwt_token');
    _socket = IO.io(ApiService.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {'token': token},
    });
    _socket!.connect();

    _socket!.onConnect((_) {
      if (widget.rideId != null) {
        _socket!.emit('joinRide', widget.rideId);
        _socket!.on('rideMessage', (data) {
          if (mounted) {
            setState(() => _messages.add(data));
            _scrollToBottom();
          }
        });
      } else if (widget.groupId != null) {
        _socket!.emit('joinGroup', widget.groupId);
        _socket!.on('groupMessage', (data) {
          if (mounted) {
            setState(() => _messages.add(data));
            _scrollToBottom();
          }
        });
      } else if (widget.buddyId != null) {
        _socket!.emit('joinBuddyChat', {'userId': _userId, 'buddyId': widget.buddyId});
        _socket!.on('buddyMessage', (data) {
          if (mounted) {
            setState(() => _messages.add(data));
            _scrollToBottom();
          }
        });
      }
    });
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

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (widget.rideId != null) {
      _socket!.emit('sendRideMessage', {
        'rideId': widget.rideId,
        'userId': _userId,
        'content': text
      });
    } else if (widget.groupId != null) {
      _socket!.emit('sendGroupMessage', {
        'groupId': widget.groupId,
        'userId': _userId,
        'content': text
      });
    } else if (widget.buddyId != null) {
      _socket!.emit('sendBuddyMessage', {
        'senderId': _userId,
        'receiverId': widget.buddyId,
        'content': text
      });
    }
    _messageController.clear();
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final sender = msg['sender'];
              final senderId = sender is Map ? sender['id']?.toString() : msg['senderId']?.toString();
              final senderName = sender is Map ? (sender['name'] ?? 'User') : 'User';
              final isMe = senderId == _userId;
              final time = DateTime.tryParse(msg['createdAt']?.toString() ?? '') ?? DateTime.now();

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, top: 4),
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                          child: Text((senderName.isNotEmpty ? senderName[0] : '?').toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
                        ),
                      ),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 4),
                              child: Text(senderName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey)),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe ? Theme.of(context).colorScheme.primary : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                                bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                              ),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(msg['content'], 
                                  style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(DateFormat('HH:mm').format(time), 
                                  style: TextStyle(fontSize: 8, color: isMe ? Colors.white70 : Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isMe) const SizedBox(width: 32), // Padding for own messages to not hit the left edge
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
