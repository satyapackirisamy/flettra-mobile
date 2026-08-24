import 'package:flutter/material.dart';
import '../theme/flettra_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import '../services/auth_service.dart';
import '../utils/user_display.dart';
import '../widgets/avatar.dart';
import '../widgets/moderation_sheet.dart';
import '../widgets/motion.dart';

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
  final ApiService           _apiService   = ApiService();
  final AuthService          _authService  = AuthService();
  final FlutterSecureStorage _storage      = const FlutterSecureStorage();
  final TextEditingController _msgCtrl     = TextEditingController();
  final ScrollController       _scrollCtrl = ScrollController();

  List<dynamic> _messages  = [];
  IO.Socket?    _socket;
  String?       _userId;
  bool          _isLoading  = true;
  bool          _isConnected = false;


  // ─── Lifecycle ────────────────────────────────────────────────────────────────

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

  // ─── Setup ────────────────────────────────────────────────────────────────────

  Future<void> _setupChat() async {
    final user = await _authService.getUser();
    _userId = user['id']?.toString();
    await _fetchHistory();
    await _connectSocket();
  }

  Future<void> _fetchHistory() async {
    try {
      final Response<dynamic> response;
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
          _messages  = (response.data is List) ? response.data : [];
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _connectSocket() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) return;

    _socket = IO.io(ApiService.baseUrl, <String, dynamic>{
      // Websocket first, but keep polling as a fallback. Websocket-only meant a
      // blocked or failed upgrade left the chat permanently silent, with no
      // indication of why.
      'transports': ['websocket', 'polling'],
      'autoConnect': false,
      'auth': {'token': token},
    });

    _socket!.onConnect((_) {
      if (mounted) setState(() => _isConnected = true);
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

    if (widget.rideId != null) {
      _socket!.on('rideMessage', _onMessage);
    } else if (widget.groupId != null) {
      _socket!.on('groupMessage', _onMessage);
    } else {
      _socket!.on('buddyMessage', _onMessage);
    }

    _socket!.onDisconnect((_) {
      if (mounted) setState(() => _isConnected = false);
    });

    // The gateway answers a rejected join or send with an error event. Nothing
    // listened for it, so "not buddies with this user" was indistinguishable
    // from a message that simply never arrived.
    _socket!.on('error', (data) {
      if (mounted) showError(context, data?.toString() ?? 'Chat error');
    });
    _socket!.onConnectError((_) {
      if (mounted) setState(() => _isConnected = false);
    });
    _socket!.connect();
  }

  void _onMessage(dynamic data) {
    if (!mounted || data is! Map) return;
    setState(() {
      final id = data['id']?.toString();

      // Replace the optimistic copy rather than showing the message twice. It
      // matches on content + sender because the pending copy has no server id.
      final pending = _messages.indexWhere((m) =>
          m is Map &&
          m['_pending'] == true &&
          m['content'] == data['content'] &&
          _senderIdOf(m) == _senderIdOf(data));
      if (pending != -1) {
        _messages[pending] = data;
        return;
      }

      // Guard a genuine duplicate (a reconnect can replay the room).
      if (id != null &&
          _messages.any((m) => m is Map && m['id']?.toString() == id)) {
        return;
      }
      _messages.add(data);
    });
    _scrollToBottom();
  }

  static String? _senderIdOf(dynamic m) {
    if (m is! Map) return null;
    final sender = m['sender'];
    if (sender is Map) return sender['id']?.toString();
    return m['senderId']?.toString();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients && _scrollCtrl.positions.length == 1) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    if (_socket == null || !_isConnected) {
      showError(context, 'Not connected — your message was not sent.');
      return;
    }

    // Show it straight away. The sender's own message previously appeared only
    // once the server echoed it back to the room, so if the room join had been
    // rejected or the echo was lost, the message was saved on the server and
    // invisible to the person who sent it. That is exactly what "sent but not
    // showing" looks like.
    setState(() {
      _messages.add(<String, dynamic>{
        '_pending': true,
        'content': text,
        'createdAt': DateTime.now().toIso8601String(),
        'sender': {'id': _userId},
        'senderId': _userId,
      });
    });
    _scrollToBottom();

    if (widget.rideId != null) {
      _socket!.emit('sendRideMessage', {'rideId': widget.rideId, 'userId': _userId, 'content': text});
    } else if (widget.groupId != null) {
      _socket!.emit('sendGroupMessage', {'groupId': widget.groupId, 'userId': _userId, 'content': text});
    } else {
      _socket!.emit('sendBuddyMessage', {'senderId': _userId, 'receiverId': widget.buddy['id']?.toString(), 'content': text});
    }
    _msgCtrl.clear();

    // Safety net: if the echo never lands, reconcile with the server so the
    // list ends up correct instead of stuck on a pending bubble.
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (_messages.any((m) => m is Map && m['_pending'] == true)) {
        _fetchHistory();
      }
    });
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String get _chatTitle {
    if (widget.rideId != null)  return widget.buddy['name'] ?? 'Ride Chat';
    if (widget.groupId != null) return widget.buddy['name'] ?? 'Group Chat';
    return _buddyName;
  }

  String get _buddyName => userName(widget.buddy, fallback: 'Chat');

  String get _chatSubtitle {
    if (widget.rideId != null)  return '${_messages.length} messages • Ride';
    if (widget.groupId != null) return '${_messages.length} messages • Group';
    return _isConnected ? 'Online now' : 'Offline';
  }

  bool _isDifferentDay(dynamic a, dynamic b) {
    try {
      final da = DateTime.parse(a.toString()).toLocal();
      final db = DateTime.parse(b.toString()).toLocal();
      return da.day != db.day || da.month != db.month || da.year != db.year;
    } catch (_) {
      return false;
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.c.surface,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────────

  /// The lime header.
  ///
  /// Every element on it was drawn in white: the back chevron, the overflow
  /// glyph, and `Colors.white70` for the subtitle. White on `#B9F227` is about
  /// 1.3:1 — which is why the name and "Online now" read as one smudged block.
  /// Everything now uses `onBrand` (the near-black the palette defines as the
  /// foreground for brand fills), so the header holds its contrast in both
  /// themes, and the two lines are separated by weight and opacity rather than
  /// by colour alone.
  Widget _buildHeader() {
    final c = context.c;
    final onBrand = c.onBrand;

    return Container(
      color: c.brand,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
          child: Row(
            children: [
              // Back
              Pressable(
                onTap: () => Navigator.pop(context),
                scale: 0.9,
                child: Container(
                  width: AppTouch.iosMin,
                  height: AppTouch.iosMin,
                  alignment: Alignment.center,
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      color: onBrand, size: 18),
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),

              // Avatar + presence dot
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: onBrand.withValues(alpha: 0.18), width: 2),
                    ),
                    child: Avatar(
                      size: 40,
                      imageUrl: userPicture(widget.buddy),
                      name: _buddyName,
                    ),
                  ),
                  if (_isConnected)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: c.ok,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.brand, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),

              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _chatTitle,
                      style: AppTypography.heading.copyWith(
                        color: onBrand,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _chatSubtitle,
                      style: AppTypography.caption.copyWith(
                        // 0.7 alpha over lime still clears 4.5:1, unlike white.
                        color: onBrand.withValues(alpha: 0.7),
                        letterSpacing: 0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Overflow
              Pressable(
                onTap: () => showModerationSheet(
                  context,
                  targetUserId: widget.buddy['id']?.toString() ?? '',
                  targetName: _buddyName,
                ),
                scale: 0.9,
                child: Container(
                  width: AppTouch.iosMin,
                  height: AppTouch.iosMin,
                  alignment: Alignment.center,
                  child: Icon(Icons.more_horiz_rounded, color: onBrand, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Message list ─────────────────────────────────────────────────────────────

  Widget _buildMessageList() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: context.c.brand));
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.c.brand.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chat_bubble_outline_rounded, size: 48, color: context.c.brand),
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: AppTypography.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: context.c.ink),
            ),
            const SizedBox(height: 6),
            Text(
              'Say hello to $_chatTitle!',
              style: AppTypography.dmSans(fontSize: 13, color: context.c.ink3),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      physics: const BouncingScrollPhysics(),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final msg          = _messages[i];
        final showDivider  = i == 0 ||
            _isDifferentDay(_messages[i - 1]['createdAt'], msg['createdAt']);
        return Column(
          children: [
            if (showDivider) _buildDateDivider(msg['createdAt']),
            _buildBubble(msg, i),
          ],
        );
      },
    );
  }

  Widget _buildDateDivider(dynamic raw) {
    String label = 'TODAY';
    try {
      final dt  = DateTime.parse(raw.toString()).toLocal();
      final now = DateTime.now();
      label = dt.day == now.day && dt.month == now.month && dt.year == now.year
          ? 'TODAY, ${DateFormat('h:mm a').format(dt).toUpperCase()}'
          : DateFormat('MMM d, h:mm a').format(dt).toUpperCase();
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: context.c.ink3,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: AppTypography.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: context.c.ink2),
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(dynamic msg, int index) {
    final sender     = msg['sender'];
    final senderId   = sender is Map
        ? sender['id']?.toString()
        : msg['senderId']?.toString();
    // userName() ignores a value that is still AES ciphertext, so a response
    // from an older server never puts a hex blob above the bubble.
    final displayName = userName(sender, fallback: _buddyName);

    final isMe       = senderId == _userId;
    final content    = msg['content']?.toString() ?? '';
    String timeStr   = '';
    try {
      timeStr = DateFormat('h:mm a').format(
        DateTime.parse(msg['createdAt'].toString()).toLocal(),
      );
    } catch (_) {}

    final prevSenderId = index > 0
        ? ((_messages[index - 1]['sender'] is Map
              ? _messages[index - 1]['sender']['id']
              : _messages[index - 1]['senderId'])
            ?.toString())
        : null;
    final isFirstFromSender = prevSenderId != senderId;

    return Padding(
      padding: EdgeInsets.only(
        top: isFirstFromSender ? AppSpacing.sm : 0,
        bottom: AppSpacing.xxs + 2,
      ),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Other user avatar
          if (!isMe) ...[
            isFirstFromSender
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Avatar(
                      size: 32,
                      imageUrl: userPicture(sender),
                      name: displayName,
                    ),
                  )
                : const SizedBox(width: 40),
          ],

          // Bubble
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Sender name (first message in group)
                if (!isMe && isFirstFromSender)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      displayName,
                      style: AppTypography.dmSans(
                        fontSize: 12, fontWeight: FontWeight.w500, color: context.c.ink3,
                      ),
                    ),
                  ),

                // Message bubble
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.c.surfaceRaised,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 5),
                      bottomRight: Radius.circular(isMe ? 5 : 16),
                    ),
                    border: Border.all(
                      color: isMe
                          ? context.c.brand.withValues(alpha: 0.55)
                          : context.c.rule,
                    ),
                  ),
                  child: Text(
                    content,
                    style: AppTypography.dmSans(
                      fontSize: 14,
                      color: context.c.ink,
                      height: 1.45,
                    ),
                  ),
                ),

                // Timestamp + read receipt
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: AppTypography.dmSans(
                          fontSize: 9, color: context.c.ink3, fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.done_all_rounded, size: 12, color: context.c.brand),
                      ],
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

  // ─── Input bar ────────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: context.c.surfaceRaised,
        border: Border(top: BorderSide(color: Colors.grey[100]!, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              // Attach
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  border: Border.all(color: context.c.ink3),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_rounded, color: context.c.ink2, size: 20),
              ),
              const SizedBox(width: 8),

              // Text field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: context.c.surfaceSunken,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _msgCtrl,
                    minLines: 1,
                    maxLines: 4,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.send,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppTypography.dmSans(fontSize: 14, color: context.c.ink),
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      hintStyle: AppTypography.dmSans(color: context.c.ink3, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Emoji
              Icon(Icons.sentiment_satisfied_alt_outlined, color: context.c.ink3, size: 22),
              const SizedBox(width: 8),

              // Send — orange circle with arrow
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: context.c.brand,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_forward_ios_rounded, color: context.c.onBrand, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
