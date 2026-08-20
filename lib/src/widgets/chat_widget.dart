import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/flettra_colors.dart';
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
              decoration: BoxDecoration(color: context.c.brand.withOpacity(0.08), shape: BoxShape.circle),
              child: Icon(Icons.chat_bubble_outline_rounded, size: 40, color: context.c.brand),
            ),
            const SizedBox(height: 14),
            Text('No messages yet', style: AppTypography.dmSans(fontWeight: FontWeight.w700, color: context.c.ink3)),
            const SizedBox(height: 4),
            Text('Be the first to say hello!', style: AppTypography.dmSans(fontSize: 12, color: context.c.ink3)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs),
      physics: const BouncingScrollPhysics(),
      itemCount: _messages.length,
      itemBuilder: (context, i) => _buildBubble(_messages[i], i),
    );
  }

  /// True when this message starts a new calendar day relative to the previous.
  bool _startsNewDay(int index) {
    DateTime? at(int i) {
      if (i < 0 || i >= _messages.length) return null;
      try {
        return DateTime.parse(_messages[i]['createdAt'].toString()).toLocal();
      } catch (_) {
        return null;
      }
    }

    final current = at(index);
    if (current == null) return false;
    if (index == 0) return true;
    final previous = at(index - 1);
    if (previous == null) return true;
    return current.year != previous.year ||
        current.month != previous.month ||
        current.day != previous.day;
  }

  /// A dated pill between days, so a long thread stays readable without every
  /// bubble carrying a full date.
  Widget _buildDaySeparator(DateTime day) {
    final c = context.c;
    final now = DateTime.now();
    final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = day.year == yesterday.year &&
        day.month == yesterday.month &&
        day.day == yesterday.day;
    final label = isToday
        ? 'Today'
        : isYesterday
            ? 'Yesterday'
            : DateFormat('d MMM yyyy').format(day);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xxs + 1),
          decoration: BoxDecoration(
            color: c.brandWash,
            borderRadius: AppRadius.pillR,
            border: Border.all(color: c.brand.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_rounded, size: 11, color: c.brand),
              const SizedBox(width: AppSpacing.xxs + 2),
              Text(label,
                  style: AppTypography.caption.copyWith(color: c.brand)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(dynamic msg, int index) {
    final c          = context.c;
    final sender     = msg['sender'];
    final senderId   = sender is Map ? sender['id']?.toString() : msg['senderId']?.toString();
    final senderName = sender is Map
        ? (sender['name'] ?? sender['firstName'] ?? 'User').toString()
        : 'User';
    final isMe       = senderId == _userId;
    final content    = msg['content']?.toString() ?? '';
    final pending    = msg['_pending'] == true;

    String timeStr = '';
    DateTime? sentAt;
    try {
      sentAt = DateTime.parse(msg['createdAt'].toString()).toLocal();
      timeStr = DateFormat('HH:mm').format(sentAt);
    } catch (_) {}

    final prevSenderId = index > 0
        ? ((_messages[index - 1]['sender'] is Map
                ? _messages[index - 1]['sender']['id']
                : _messages[index - 1]['senderId'])
            ?.toString())
        : null;
    final newDay = _startsNewDay(index);
    // A run of messages from one person shows their name and avatar once.
    final isFirstFromSender = prevSenderId != senderId || newDay;

    // Own messages are outlined rather than filled. A solid lime bubble on every
    // line is the accent shouting; an outline still reads as "mine" and lets the
    // message text stay ink, which is easier to read at length.
    final bubble = Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm + 1, AppSpacing.xs + 1, AppSpacing.sm + 1, AppSpacing.xs),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 5),
          bottomRight: Radius.circular(isMe ? 5 : 16),
        ),
        border: Border.all(
          color: isMe ? c.brand.withValues(alpha: 0.55) : c.rule,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(content,
              style: AppTypography.body.copyWith(color: c.ink, height: 1.35)),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pending ? 'Sending…' : timeStr,
                style: AppTypography.caption.copyWith(
                  color: pending ? c.ink3 : (isMe ? c.brand : c.ink3),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isMe && !pending) ...[
                const SizedBox(width: AppSpacing.xxs),
                Icon(Icons.done_all_rounded, size: 12, color: c.brand),
              ],
            ],
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (newDay && sentAt != null) _buildDaySeparator(sentAt),
        Padding(
          padding: EdgeInsets.only(bottom: isFirstFromSender ? 2 : 3, top: isFirstFromSender ? 6 : 0),
          child: Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe)
                isFirstFromSender
                    ? Container(
                        width: 30,
                        height: 30,
                        margin: const EdgeInsets.only(right: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: c.brandWash,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.brand.withValues(alpha: 0.4)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          senderName.isNotEmpty
                              ? senderName.characters.first.toUpperCase()
                              : 'U',
                          style: AppTypography.caption.copyWith(color: c.brand),
                        ),
                      )
                    : const SizedBox(width: 38),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMe && isFirstFromSender)
                      Padding(
                        padding: const EdgeInsets.only(
                            left: AppSpacing.xxs, bottom: 3),
                        child: Text(senderName,
                            style:
                                AppTypography.footnote.copyWith(color: c.ink3)),
                      ),
                    Opacity(opacity: pending ? 0.6 : 1, child: bubble),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        border: Border(top: BorderSide(color: c.rule, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.surfaceSunken,
                shape: BoxShape.circle,
                border: Border.all(color: c.rule),
              ),
              child: IconButton(
                onPressed: _showAttachSheet,
                tooltip: 'Attach',
                iconSize: 18,
                color: c.ink2,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.attach_file_rounded),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: c.surfaceSunken,
                  borderRadius: AppRadius.pillR,
                  border: Border.all(color: c.rule),
                ),
                child: TextField(
                  controller: _msgCtrl,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTypography.body.copyWith(color: c.ink),
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    hintStyle: AppTypography.body.copyWith(color: c.ink3),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(Icons.arrow_forward_rounded,
                    color: c.onBrand, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Attachment options. The paperclip previously did nothing.
  void _showAttachSheet() {
    final c = context.c;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_outlined, color: c.brand),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.location_on_outlined, color: c.route),
              title: const Text('Share live location'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
