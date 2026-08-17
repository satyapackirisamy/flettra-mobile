import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../theme/app_spacing.dart';
import '../theme/flettra_colors.dart';
import '../services/auth_service.dart';
import '../widgets/network_image_widget.dart';
import 'chat_screen.dart';
import 'rider_profile_screen.dart';

class BuddiesScreen extends StatefulWidget {
  const BuddiesScreen({super.key});

  @override
  State<BuddiesScreen> createState() => _BuddiesScreenState();
}

class _BuddiesScreenState extends State<BuddiesScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _buddies       = [];
  List<dynamic> _requests      = [];
  List<dynamic> _searchResults = [];
  List<dynamic> _suggested     = []; // non-buddy users

  bool _isLoading   = true;
  bool _isSearching = false;
  String? _userId;

  static const Color _orange = Color(0xFFFF6B2C);
  static const Color _dark = Color(0xFF1A0A08);
  static const Color _bg = Color(0xFFEEF6FA); // light blue-grey like reference

  @override
  void initState() {
    super.initState();
    _loadData();
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    final user = await _authService.getUser();
    if (mounted) setState(() => _userId = user?['id']);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getBuddies(),
        _apiService.getBuddyRequests(),
        _apiService.searchUsers('').catchError((_) =>
            Response(requestOptions: RequestOptions(path: ''), data: [])),
      ]);
      if (mounted) {
        final buddiesRaw  = results[0].data;
        final requestsRaw = results[1].data;
        final allUsersRaw = results[2].data;

        // Defensive parsing: backend may return a List directly, or wrap in a Map
        List<dynamic> parsedBuddies  = _parseList(buddiesRaw);
        List<dynamic> parsedRequests = _parseList(requestsRaw);
        List<dynamic> parsedAll      = _parseList(allUsersRaw);

        // Suggested = all users excluding existing buddies and self
        final buddyIdSet = parsedBuddies.map((b) => b['id']?.toString() ?? '').toSet();
        final suggested  = parsedAll
            .where((u) => u['id']?.toString() != _userId && !buddyIdSet.contains(u['id']?.toString()))
            .toList();

        setState(() {
          _buddies   = parsedBuddies;
          _requests  = parsedRequests;
          _suggested = suggested;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Safely extract a List from whatever the backend returns.
  List<dynamic> _parseList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map) {
      // Try common wrapper keys
      for (final key in ['data', 'buddies', 'users', 'requests', 'items', 'results']) {
        if (raw[key] is List) return raw[key] as List<dynamic>;
      }
    }
    return [];
  }

  Future<void> _handleSearch(String query) async {
    if (query.isEmpty) {
      setState(() { _isSearching = false; _searchResults = []; });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final res = await _apiService.searchUsers(query);
      if (mounted) setState(() => _searchResults = (res.data is List) ? res.data : []);
    } catch (_) {}
  }

  Future<void> _sendRequest(String id) async {
    try {
      await _apiService.sendBuddyRequest(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Request sent!', style: AppTypography.dmSans(fontWeight: FontWeight.w700)),
          backgroundColor: _orange, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        _handleSearch(_searchController.text);
      }
    } catch (_) {}
  }

  Future<void> _respondToRequest(String requestId, bool accept) async {
    try {
      if (accept) await _apiService.acceptBuddyRequest(requestId);
      else        await _apiService.rejectBuddyRequest(requestId);
      _loadData();
    } catch (_) {}
  }

  Future<void> _removeBuddy(String buddyId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Remove Buddy?', style: AppTypography.dmSans(fontWeight: FontWeight.w800)),
        content: Text('Remove $name from your circle?', style: AppTypography.dmSans()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('CANCEL', style: AppTypography.dmSans(fontWeight: FontWeight.bold, color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('REMOVE', style: AppTypography.dmSans(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _apiService.client.delete('/users/buddies/$buddyId');
        _loadData();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _dark, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Buddy Network', style: AppTypography.dmSans(color: _dark, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.tune_rounded, color: _dark, size: 20),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: context.c.surfaceRaised,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _handleSearch,
                style: AppTypography.dmSans(fontWeight: FontWeight.w600, color: _dark),
                decoration: InputDecoration(
                  hintText: 'Search travel buddies...',
                  hintStyle: AppTypography.dmSans(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 22),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _orange))
                : _isSearching
                    ? _buildSearchResults()
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_requests.isNotEmpty) _buildRequestsSection(),
                            if (_buddies.isNotEmpty)  _buildMyBuddiesSection(),
                            _buildSuggestedSection(),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ─── Pending Requests Section ─────────────────────────────────────────────────

  Widget _buildRequestsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RECENT REQUESTS', style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 1.2)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(20)),
                child: Text('${_requests.length} PENDING', style: AppTypography.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))]),
            child: Column(
              children: _requests.asMap().entries.map((entry) {
                final i = entry.key;
                final req = entry.value;
                final sender = req['sender'] ?? {};
                final name = _getName(sender);
                return Column(
                  children: [
                    if (i > 0) const Divider(height: 1, indent: 72),
                    _buildRequestRow(req, sender, name),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestRow(dynamic req, dynamic sender, String name) {
    final avatarUrl = ApiService.getAvatarUrl(sender['profilePicture'], name: name);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Avatar — rounded-square with orange border (matching reference)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _orange, width: 2.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 48, height: 48,
                child: Image(
                  image: ApiService.networkImageProvider(avatarUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: _orange.withOpacity(0.12),
                    child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: AppTypography.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: _orange))),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: _dark)),
                Text('Wants to connect with you', style: AppTypography.dmSans(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Accept button — dark pill
          GestureDetector(
            onTap: () => _respondToRequest(req['id'], true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(color: _dark, borderRadius: BorderRadius.circular(24)),
              child: Text('Accept', style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          // Reject — grey circle X
          GestureDetector(
            onTap: () => _respondToRequest(req['id'], false),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Your Buddies (existing connections) ─────────────────────────────────────

  Widget _buildMyBuddiesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your buddies', style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 1.2)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _dark, borderRadius: BorderRadius.circular(20)),
                child: Text('${_buddies.length} CONNECTED', style: AppTypography.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimationLimiter(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _buddies.length,
              itemBuilder: (context, i) => AnimationConfiguration.staggeredList(
                position: i, duration: const Duration(milliseconds: 400),
                child: FadeInAnimation(child: _buildBuddyCard(_buddies[i], isConnected: true)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Suggested Buddies Grid ───────────────────────────────────────────────────

  Widget _buildSuggestedSection() {
    final list = _suggested.isEmpty && _buddies.isEmpty ? <dynamic>[] : _suggested;

    if (list.isEmpty && _buddies.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text('No users found', style: AppTypography.dmSans(fontWeight: FontWeight.w700, color: Colors.grey[400], fontSize: 16)),
              const SizedBox(height: 8),
              Text('Search for travel companions above', style: AppTypography.dmSans(fontSize: 13, color: Colors.grey[400])),
            ],
          ),
        ),
      );
    }

    if (list.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Suggested', style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 1.2)),
          const SizedBox(height: 12),
          AnimationLimiter(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              itemBuilder: (context, i) => AnimationConfiguration.staggeredList(
                position: i, duration: const Duration(milliseconds: 400),
                child: FadeInAnimation(child: _buildBuddyCard(list[i])),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A list row, not a grid tile.
  ///
  /// This screen backs the Chats tab, and messaging is a list everywhere on
  /// both platforms — two-up tiles with a 68 pt avatar and a full-width filled
  /// button fit four people on a phone and gave every one of them the same
  /// visual weight as a primary action.
  Widget _buildBuddyCard(dynamic buddy, {bool isConnected = false}) {
    final c         = context.c;
    final name      = _getName(buddy);
    final location  = (buddy['location'] ?? 'Explorer').toString();
    final avatarUrl = ApiService.getAvatarUrl(buddy['profilePicture'], name: name);
    final userId    = buddy['id']?.toString() ?? '';

    return InkWell(
      onTap: userId.isNotEmpty
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      RiderProfileScreen(userId: userId, knownName: name)))
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.ruleSoft)),
        ),
        child: Row(
          children: [
            WebCircleAvatar(url: avatarUrl, radius: 21),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong.copyWith(color: c.ink)),
                  Text(location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.footnote.copyWith(color: c.ink3)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            if (isConnected)
              IconButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ChatScreen(buddy: buddy))),
                tooltip: 'Message $name',
                iconSize: 20,
                color: c.brand,
                constraints: const BoxConstraints(
                    minWidth: AppTouch.iosMin, minHeight: AppTouch.iosMin),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
              )
            else
              TextButton(
                onPressed: () => _sendRequest(userId),
                style: TextButton.styleFrom(
                  foregroundColor: c.brand,
                  textStyle: AppTypography.bodyStrong,
                  minimumSize: const Size(0, AppTouch.iosMin),
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                ),
                child: const Text('Connect'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 52, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('No users found', style: AppTypography.dmSans(fontWeight: FontWeight.w700, color: Colors.grey[400])),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, i) {
        final user = _searchResults[i];
        final name = _getName(user);
        final isBuddy = _buddies.any((b) => b['id'] == user['id']);
        final isSelf  = user['id'] == _userId;
        final avatarUrl = ApiService.getAvatarUrl(user['profilePicture'], name: name);
        final location = user['location'] ?? 'Explorer';
        final interests = _getInterests(user);

        return Container(
          decoration: BoxDecoration(
            color: context.c.surfaceRaised,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              WebCircleAvatar(url: avatarUrl, radius: 34),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(name, style: AppTypography.dmSans(fontSize: 14, fontWeight: FontWeight.w800, color: _dark), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on_rounded, size: 11, color: Colors.grey[400]),
                  const SizedBox(width: 2),
                  Flexible(child: Text(location, style: AppTypography.dmSans(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                ],
              ),
              const SizedBox(height: 8),
              if (interests.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Wrap(
                    spacing: 4, runSpacing: 4, alignment: WrapAlignment.center,
                    children: interests.take(2).map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                      child: Text(tag, style: AppTypography.dmSans(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey[600], letterSpacing: 0.5)),
                    )).toList(),
                  ),
                ),
              const SizedBox(height: 12),
              if (!isSelf)
                GestureDetector(
                  onTap: isBuddy ? null : () => _sendRequest(user['id']),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: isBuddy ? const Color(0xFF10B981) : _orange, borderRadius: BorderRadius.circular(30)),
                    child: Center(
                      child: Text(isBuddy ? 'Connected ✓' : 'Connect', style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
            ],
          ),
        );
      },
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _getName(dynamic user) {
    if (user == null) return 'Unknown';
    String? name = user['name'];
    if (name != null && name.isNotEmpty) return name;
    String first = user['firstName'] ?? '';
    String last  = user['lastName'] ?? '';
    String full  = '$first $last'.trim();
    return full.isNotEmpty ? full : 'User';
  }

  List<String> _getInterests(dynamic user) {
    // Derive from role or subscription plan or location
    final role = (user['role'] ?? '').toString().toLowerCase();
    final plan = (user['subscriptionPlan'] ?? '').toString().toLowerCase();
    if (role == 'driver') return ['ROAD TRIP', 'DRIVING'];
    if (plan == 'premium') return ['ADVENTURE', 'TRAVEL'];
    return ['TRAVEL', 'EXPLORE'];
  }
}
