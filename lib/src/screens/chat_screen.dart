import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> buddy;
  final String? rideId;
  final String? groupId;

  const ChatScreen({
    super.key,
    required this.buddy,
    this.rideId,
    this.groupId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _messages = [];
  IO.Socket? _socket;
  String? _userId;
  bool _isLoading = true;
  bool _isConnected = false;

  static const Color primaryOrange = Color(0xFFFF5500);

  @override
  void initState() {
    super.initState();
    _setupChat();
  }

  Future<void> _setupChat() async {
    final user = await _authService.getUser();
    _userId = user?['id']?.toString();

    // Fetch message history
    await _fetchHistory();

    // Connect socket
    await _connectSocket();
  }

  Future<void> _fetchHistory() async {
    try {
      final response;
      if (widget.rideId != null) {
        response = await _apiService.getRideMessages(widget.rideId!);
      } else if (widget.groupId != null) {
        response = await _apiService.getGroupMessages(widget.groupId!);
      } else {
        final buddyId = widget.buddy['id']?.toString() ?? '';
        response = await _apiService.getBuddyMessages(buddyId);
      }

      if (mounted) {
        setState(() {
          _messages = (response.data is List) ? response.data : [];
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error fetching chat history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _connectSocket() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      debugPrint('No JWT token found, cannot connect socket');
      return;
    }

    _socket = IO.io(ApiService.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {'token': token},
    });

    _socket!.onConnect((_) {
      debugPrint('Socket connected');
      if (mounted) setState(() => _isConnected = true);

      // Join the appropriate room
      if (widget.rideId != null) {
        _socket!.emit('joinRide', widget.rideId);
      } else if (widget.groupId != null) {
        _socket!.emit('joinGroup', widget.groupId);
      } else {
        _socket!.emit('joinBuddyChat', {
          'userId': _userId,
          'buddyId': widget.buddy['id']?.toString(),
        });
      }
    });

    // Listen for incoming messages
    if (widget.rideId != null) {
      _socket!.on('rideMessage', _onMessageReceived);
    } else if (widget.groupId != null) {
      _socket!.on('groupMessage', _onMessageReceived);
    } else {
      _socket!.on('buddyMessage', _onMessageReceived);
    }

    _socket!.onDisconnect((_) {
      debugPrint('Socket disconnected');
      if (mounted) setState(() => _isConnected = false);
    });

    _socket!.onConnectError((err) {
      debugPrint('Socket connection error: $err');
    });

    _socket!.connect();
  }

  void _onMessageReceived(dynamic data) {
    if (mounted) {
      setState(() => _messages.add(data));
      _scrollToBottom();
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

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _socket == null) return;

    if (widget.rideId != null) {
      _socket!.emit('sendRideMessage', {
        'rideId': widget.rideId,
        'userId': _userId,
        'content': text,
      });
    } else if (widget.groupId != null) {
      _socket!.emit('sendGroupMessage', {
        'groupId': widget.groupId,
        'userId': _userId,
        'content': text,
      });
    } else {
      _socket!.emit('sendBuddyMessage', {
        'senderId': _userId,
        'receiverId': widget.buddy['id']?.toString(),
        'content': text,
      });
    }

    _messageController.clear();
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buddyName = widget.buddy['name'] ?? 'Chat';

    return Scaffold(
      appBar: AppBar(
        title: Text(buddyName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryOrange))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 60, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'Start a conversation with $buddyName',
                              style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final sender = msg['sender'];
                          final senderId = sender is Map ? sender['id']?.toString() : msg['senderId']?.toString();
                          final senderName = sender is Map ? (sender['name'] ?? 'User') : 'User';
                          final isMe = senderId == _userId;
                          final createdAt = msg['createdAt'];
                          final time = createdAt != null ? DateTime.tryParse(createdAt.toString()) : null;

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8, top: 4),
                                    child: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: primaryOrange.withOpacity(0.1),
                                      child: Text(
                                        (senderName.isNotEmpty ? senderName[0] : '?').toUpperCase(),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryOrange),
                                      ),
                                    ),
                                  ),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      if (!isMe)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 4, bottom: 4),
                                          child: Text(
                                            senderName,
                                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey),
                                          ),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isMe ? primaryOrange : Colors.grey[100],
                                          borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(16),
                                            topRight: const Radius.circular(16),
                                            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                                            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              msg['content']?.toString() ?? '',
                                              style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14),
                                            ),
                                            if (time != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                DateFormat('HH:mm').format(time),
                                                style: TextStyle(fontSize: 9, color: isMe ? Colors.white70 : Colors.grey),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isMe) const SizedBox(width: 32),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey[400], fontSize: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: primaryOrange, shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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
}
