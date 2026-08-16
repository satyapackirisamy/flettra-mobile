import 'package:flutter/foundation.dart';
import '../theme/app_typography.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';
import 'edit_post_screen.dart';
import '../widgets/network_image_widget.dart';
import '../widgets/moderation_sheet.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => TimelineScreenState();
}

// Public alias so GlobalKey<TimelineScreenState> works from main_screen
typedef TimelineScreenState = _TimelineScreenState;

class _TimelineScreenState extends State<TimelineScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  List<dynamic> _posts = [];
  bool _isLoading = true;
  String _selectedScope = 'Friends';

  static const Color _orange = Color(0xFFFF6B2C);
  static const Color _bg = Colors.white;
  static const Color _dark = Color(0xFF1A0A08);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Called externally (e.g. from MainScreen after a new post is created).
  void refresh() => _loadData();

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _fetchPosts();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchPosts() async {
    try {
      final res = _selectedScope == 'Friends'
          ? await _apiService.getFriendsTimeline()
          : await _apiService.getGlobalTimeline();
      if (mounted) {
        final data = res.data;
        setState(() => _posts = (data is Map ? data['posts'] : data) as List? ?? []);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: _orange,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: _orange))
                    : _posts.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 120),
                            itemCount: _posts.length,
                            itemBuilder: (context, i) => _buildCard(_posts[i], i),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          Text(
            'Feed',
            style: AppTypography.dmSans(fontSize: 24, fontWeight: FontWeight.w800, color: _dark, letterSpacing: -0.5),
          ),
          const Spacer(),
          // Scope toggle
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: ['Friends', 'Discover'].map((s) {
                final active = _selectedScope == s;
                return GestureDetector(
                  onTap: () { setState(() => _selectedScope = s); _loadData(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: active ? _orange : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(s, style: AppTypography.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: active ? Colors.white : Colors.grey[400])),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Card Router ─────────────────────────────────────────────────────────────

  Widget _buildCard(dynamic post, int index) {
    final hasImage = (post['imageUrl'] != null) || ((post['imageUrls'] as List?)?.isNotEmpty == true);
    final content = (post['content'] ?? '').toString();

    // First post with image → featured style
    if (index == 0 && hasImage) return _buildFeaturedCard(post);
    // Every 3rd post with no image & long text → quote card
    if (index % 3 == 2 && !hasImage && content.length > 60) return _buildQuoteCard(post);
    // Short text-only → private journal style
    if (!hasImage && content.length < 120) return _buildJournalCard(post);
    // Default: regular image post
    return _buildRegularCard(post);
  }

  // ─── Featured card ────────────────────────────────────────────────────────────

  Widget _buildFeaturedCard(dynamic post) {
    final imageUrl = _getImageUrl(post);
    final name = _authorName(post);
    final content = (post['content'] ?? '').toString();
    final avatarUrl = ApiService.getAvatarUrl(post['author']?['profilePicture'], name: name);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero image with overlay
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: imageUrl != null
                    ? SafeNetworkImage(url: imageUrl, height: 260, width: double.infinity, fit: BoxFit.cover)
                    : Container(height: 260, color: Colors.grey[200]),
              ),
              // Dark gradient
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.75), Colors.transparent],
                    ),
                  ),
                ),
              ),
              // Featured tag + title
              Positioned(
                bottom: 20, left: 20, right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(6)),
                      child: Text('FEATURED JOURNEY', style: AppTypography.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1.2)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _postTitle(post),
                      style: AppTypography.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5, height: 1.15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Quote + author
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"$content"',
                  style: AppTypography.dmSans(fontSize: 13, color: Colors.grey[600], height: 1.6, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    WebCircleAvatar(url: avatarUrl, radius: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 13, color: _dark)),
                          Text(_timeAgo(post['createdAt']), style: AppTypography.dmSans(fontSize: 10, color: Colors.grey[400])),
                        ],
                      ),
                    ),
                    _moreBtn(post),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Regular image card ───────────────────────────────────────────────────────

  Widget _buildRegularCard(dynamic post) {
    final imageUrl = _getImageUrl(post);
    final name = _authorName(post);
    final content = (post['content'] ?? '').toString();
    final avatarUrl = ApiService.getAvatarUrl(post['author']?['profilePicture'], name: name);
    final likes = (post['likes'] as List?)?.length ?? 0;
    final comments = (post['commentsCount'] ?? 0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              children: [
                WebCircleAvatar(url: avatarUrl, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 14, color: _dark)),
                      Text(_timeAgo(post['createdAt']), style: AppTypography.dmSans(fontSize: 10, color: Colors.grey[400])),
                    ],
                  ),
                ),
                _moreBtn(post),
              ],
            ),
          ),
          // Image
          if (imageUrl != null) ...[
            Stack(
              children: [
                ClipRRect(
                  child: SafeNetworkImage(url: imageUrl, height: 220, width: double.infinity, fit: BoxFit.cover),
                ),
                // Category tag
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
                    child: Text(_categoryTag(post), style: AppTypography.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: _dark, letterSpacing: 0.8)),
                  ),
                ),
              ],
            ),
          ],
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              content,
              style: AppTypography.dmSans(fontSize: 13, color: Colors.grey[700], height: 1.55),
            ),
          ),
          // Engagement
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.favorite_border_rounded, size: 20),
                  color: const Color(0xFFE53935),
                  onPressed: () async { await ApiService().likePost(post['id']); _loadData(); },
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
                Text('$likes', style: AppTypography.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[500])),
                const SizedBox(width: 12),
                const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Colors.grey),
                const SizedBox(width: 4),
                Text('$comments', style: AppTypography.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[500])),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.near_me_outlined, size: 20, color: _orange),
                  onPressed: () {},
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Quote card ───────────────────────────────────────────────────────────────

  Widget _buildQuoteCard(dynamic post) {
    final name = _authorName(post);
    final content = (post['content'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('"', style: AppTypography.dmSans(fontSize: 72, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.4), height: 0.6)),
          const SizedBox(height: 8),
          Text(
            content,
            style: AppTypography.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1.35, letterSpacing: -0.3),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: Center(child: Text(name[0], style: AppTypography.dmSans(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('THOUGHT LEADER', style: AppTypography.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 1.0)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.ios_share_rounded, size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Journal / text-only card ─────────────────────────────────────────────────

  Widget _buildJournalCard(dynamic post) {
    final name = _authorName(post);
    final content = (post['content'] ?? '').toString();
    final avatarUrl = ApiService.getAvatarUrl(post['author']?['profilePicture'], name: name);
    final likes = (post['likes'] as List?)?.length ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WebCircleAvatar(url: avatarUrl, radius: 16),
              const SizedBox(width: 8),
              Text(name, style: AppTypography.dmSans(fontWeight: FontWeight.w700, fontSize: 13, color: _dark)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _orange.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
                child: Text('PRIVATE JOURNAL', style: AppTypography.dmSans(fontSize: 8, fontWeight: FontWeight.w700, color: _orange, letterSpacing: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _postTitle(post),
            style: AppTypography.dmSans(fontSize: 17, fontWeight: FontWeight.w700, color: _dark, height: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: AppTypography.dmSans(fontSize: 13, color: Colors.grey[600], height: 1.6),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              GestureDetector(
                onTap: () async { await ApiService().likePost(post['id']); _loadData(); },
                child: Text('READ FULL STORY →', style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: _orange, letterSpacing: 0.3)),
              ),
              const Spacer(),
              const Icon(Icons.favorite_border_rounded, size: 16, color: Color(0xFFE53935)),
              const SizedBox(width: 4),
              Text('$likes', style: AppTypography.dmSans(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              const Icon(Icons.ios_share_rounded, size: 16, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  Widget _moreBtn(dynamic post) {
    return GestureDetector(
      onTap: () => _showPostOptions(post),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.grey[50], shape: BoxShape.circle),
        child: Icon(Icons.more_horiz_rounded, color: Colors.grey[400], size: 18),
      ),
    );
  }

  String? _getImageUrl(dynamic post) {
    final single = post['imageUrl'];
    if (single != null && single.toString().isNotEmpty) return ApiService.getFullImageUrl(single.toString());
    final urls = post['imageUrls'] as List?;
    if (urls != null && urls.isNotEmpty) return ApiService.getFullImageUrl(urls[0].toString());
    return null;
  }

  String _authorName(dynamic post) {
    final a = post['author'];
    if (a == null) return 'Unknown';
    if (a['name'] != null && (a['name'] as String).isNotEmpty) return a['name'];
    final first = a['firstName'] ?? '';
    final last = a['lastName'] ?? '';
    return '$first $last'.trim().isNotEmpty ? '$first $last'.trim() : 'User';
  }

  String _postTitle(dynamic post) {
    final content = (post['content'] ?? '').toString();
    // Use first line (or first sentence) as title
    final firstLine = content.split('\n').first;
    return firstLine;
  }

  String _categoryTag(dynamic post) {
    final content = (post['content'] ?? '').toString().toLowerCase();
    if (content.contains('mountain') || content.contains('alpine') || content.contains('peak')) return 'ALPINE';
    if (content.contains('beach') || content.contains('ocean') || content.contains('sea')) return 'COASTAL';
    if (content.contains('city') || content.contains('urban')) return 'URBAN';
    if (content.contains('forest') || content.contains('jungle')) return 'FOREST';
    return 'JOURNEY';
  }

  String _timeAgo(dynamic raw) {
    if (raw == null) return '';
    try {
      var dt = DateTime.parse(raw.toString());
      // Server sends UTC timestamps; if no 'Z' suffix Dart treats as local — force UTC
      if (!raw.toString().endsWith('Z') && !raw.toString().contains('+')) {
        dt = DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, dt.millisecond);
      }
      final diff = DateTime.now().difference(dt.toLocal());
      if (diff.isNegative) return 'just now';
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM d').format(dt.toLocal());
    } catch (_) { return ''; }
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: _orange.withOpacity(0.10), shape: BoxShape.circle),
              child: const Icon(Icons.photo_library_outlined, size: 48, color: _orange),
            ),
            const SizedBox(height: 20),
            Text('Your feed is empty', style: AppTypography.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: _dark)),
            const SizedBox(height: 8),
            Text('Share your traveler moments to inspire others', style: AppTypography.dmSans(fontSize: 13, color: Colors.grey[400]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Future<void> _showPostOptions(dynamic post) async {
    final myId = await _authService.getCurrentUserId();
    final authorId = post['author']?['id'] ?? post['authorId'];
    final isMyPost = myId != null && myId == authorId;

    if (!mounted) return;

    if (isMyPost) {
      // Own post: edit / delete
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.edit_rounded, size: 20)),
                  title: Text('Edit Post', style: AppTypography.dmSans(fontWeight: FontWeight.w700)),
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditPostScreen(post: post)));
                    if (result == true) _loadData();
                  },
                ),
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20)),
                  title: Text('Delete Post', style: AppTypography.dmSans(fontWeight: FontWeight.w700, color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(context);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: Text('Delete Post?', style: AppTypography.dmSans(fontWeight: FontWeight.w800)),
                        content: Text('This action cannot be undone.', style: AppTypography.dmSans()),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: AppTypography.dmSans(fontWeight: FontWeight.w700))),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: AppTypography.dmSans(color: Colors.red, fontWeight: FontWeight.w800))),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      try { await ApiService().deletePost(post['id']); _loadData(); } catch (_) {}
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    } else {
      // Someone else's post: report / mute / block
      final authorName = _authorName(post);
      if (!mounted) return;
      await showModerationSheet(
        context,
        targetUserId: authorId ?? '',
        postId: post['id'],
        targetName: authorName,
        onActionDone: _loadData,
      );
    }
  }
}
