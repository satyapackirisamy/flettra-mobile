import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
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
  final ApiService           _apiService  = ApiService();
  final AuthService          _authService = AuthService();
  final TextEditingController _msgCtrl    = TextEditingController();
  final ScrollController      _scrollCtrl = ScrollController();

  List<dynamic> _messages = [];
  IO.Socket?    _socket;
  String?       _userId;

  static const Color _orange    = Color(0xFFFF6B2C);
  static const Color _orangeEnd = Color(0xFFFF8C5A);
  static const Color _dark      = Color(0xFF1A0A08);

  @override
  void initState() {
    super.initState();
    _setupChat();
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _setupChat() async {
    final user = await _authService.getUser();
    _userId = user['id']?.toString();

    // Fetch history
    try {
      final dynamic response;
      if (widget.rideId != null) {
        response = await _apiService.getRideMessages(widget.rideId!);
      } else if (widget.groupId != null) {
        response = await _apiService.getGroupMessages(widget.groupId!);
      } else {
        response = await _apiService.getBuddyMessages(widget.buddyId!);
      }
      if (mounted) {
        setState(() => _messages = (response.data is List) ? response.data : []);
        _scrollToBottom();
      }
    } catch (_) {}

    // Connect socket
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
        _socket!.on('rideMessage', _onMsg);
      } else if (widget.groupId != null) {
        _socket!.emit('joinGroup', widget.groupId);
        _socket!.on('groupMessage', _onMsg);
      } else if (widget.buddyId != null) {
        _socket!.emit('joinBuddyChat', {'userId': _userId, 'buddyId': widget.buddyId});
        _socket!.on('buddyMessage', _onMsg);
      }
    });
  }

  void _onMsg(dynamic data) {
    if (mounted) {
      setState(() => _messages.add(data));
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients && _scrollCtrl.positions.length == 1) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _socket == null) return;
    if (widget.rideId != null) {
      _socket!.emit('sendRideMessage', {'rideId': widget.rideId, 'userId': _userId, 'content': text});
    } else if (widget.groupId != null) {
      _socket!.emit('sendGroupMessage', {'groupId': widget.groupId, 'userId': _userId, 'content': text});
    } else if (widget.buddyId != null) {
      _socket!.emit('sendBuddyMessage', {'senderId': _userId, 'receiverId': widget.buddyId, 'content': text});
    }
    _msgCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildMessageList()),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: _orange.withOpacity(0.08), shape: BoxShape.circle),
              child: const Icon(Icons.chat_bubble_outline_rounded, size: 40, color: _orange),
            ),
            const SizedBox(height: 14),
            Text('No messages yet', style: AppTypography.dmSans(fontWeight: FontWeight.w700, color: Colors.grey[400])),
            const SizedBox(height: 4),
            Text('Be the first to say hello!', style: AppTypography.dmSans(fontSize: 12, color: Colors.grey[300])),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      physics: const BouncingScrollPhysics(),
      itemCount: _messages.length,
      itemBuilder: (context, i) => _buildBubble(_messages[i], i),
    );
  }

  Widget _buildBubble(dynamic msg, int index) {
    final sender     = msg['sender'];
    final senderId   = sender is Map ? sender['id']?.toString() : msg['senderId']?.toString();
    final senderName = sender is Map ? (sender['name'] ?? sender['firstName'] ?? 'User').toString() : 'User';
    final isMe       = senderId == _userId;
    final content    = msg['content']?.toString() ?? '';
    String timeStr   = '';
    try {
      timeStr = DateFormat('HH:mm').format(DateTime.parse(msg['createdAt'].toString()).toLocal());
    } catch (_) {}

    final prevSenderId = index > 0
        ? ((_messages[index - 1]['sender'] is Map
              ? _messages[index - 1]['sender']['id']
              : _messages[index - 1]['senderId'])?.toString())
        : null;
    final isFirstFromSender = prevSenderId != senderId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Other user avatar
          if (!isMe)
            isFirstFromSender
                ? Container(
                    width: 30, height: 30,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                        style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  )
                : const SizedBox(width: 38),

          // Bubble
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && isFirstFromSender)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(senderName,
                        style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: _orange)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? null
                        : null,
                    color: isMe ? null : const Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(18),
                      topRight:    const Radius.circular(18),
                      bottomLeft:  Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(content,
                          style: AppTypography.dmSans(
                            fontSize: 14,
                            color: isMe ? Colors.white : _dark,
                            height: 1.4,
                          )),
                      const SizedBox(height: 3),
                      Text(timeStr,
                          style: AppTypography.dmSans(
                            fontSize: 9,
                            color: isMe ? Colors.white60 : Colors.grey[400],
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[100]!)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(24)),
              child: TextField(
                controller: _msgCtrl,
                style: AppTypography.dmSans(fontSize: 14, color: _dark),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: AppTypography.dmSans(color: Colors.grey[400], fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
