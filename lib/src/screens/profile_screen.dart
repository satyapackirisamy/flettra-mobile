import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../widgets/network_image_widget.dart';
import 'onboarding_screen.dart';
import 'analytics_screen.dart';
import 'all_rides_screen.dart';
import 'rider_profile_screen.dart';

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _StickyTabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) => false;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _stats;
  List<dynamic> _myPosts   = [];
  List<dynamic> _myRides   = [];
  List<dynamic> _myBuddies = [];
  bool _isLoading   = true;
  bool _isUploading = false;
  int  _avatarVersion = 0;
  late TabController _tabController;
  final ScrollController _timelineScrollCtrl = ScrollController();
  final ScrollController _buddiesScrollCtrl  = ScrollController();
  final ScrollController _journalScrollCtrl  = ScrollController();

  static const Color _orange = Color(0xFFFF6B2C);
  static const Color _bg     = Colors.white;
  static const Color _dark   = Color(0xFF1A0A08);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Nuke image cache every time the profile screen opens so the avatar always
    // fetches fresh from the server — never from a stale in-memory entry.
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _fetch();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timelineScrollCtrl.dispose();
    _buddiesScrollCtrl.dispose();
    _journalScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    final u = await _authService.getUser();
    if (mounted) setState(() { _user = u; _isLoading = false; });

    // Load stats, posts, and rides in parallel
    await Future.wait([
      _apiService.getMyAnalytics().then((res) {
        if (mounted) setState(() => _stats = res.data is Map ? res.data : null);
      }).catchError((_) {}),

      _apiService.getGlobalTimeline().then((res) {
        if (mounted) {
          final data = res.data;
          final allPosts = (data is Map ? data['posts'] : data) as List? ?? [];
          setState(() => _myPosts = allPosts.take(6).toList());
        }
      }).catchError((_) {}),

      _apiService.getMyRides().then((res) {
        if (mounted) {
          setState(() => _myRides = _parseList(res.data));
        }
      }).catchError((_) {}),

      _apiService.getBuddies().then((res) {
        if (mounted) {
          setState(() => _myBuddies = _parseList(res.data));
        }
      }).catchError((_) {}),
    ]);
  }

  List<dynamic> _parseList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map) {
      for (final key in ['data', 'buddies', 'users', 'items', 'results', 'rides']) {
        if (raw[key] is List) return raw[key] as List<dynamic>;
      }
    }
    return [];
  }

  // ─── Avatar upload ────────────────────────────────────────────────────────────

  Future<void> _pickAndUploadAvatar() async {
    setState(() => _isUploading = true);
    try {
      // Upload to Cloudinary so the URL is publicly accessible on any device
      final cloudUrl = await CloudinaryService.pickAndUpload(context, imageQuality: 85, maxWidth: 400);
      if (cloudUrl == null) { setState(() => _isUploading = false); return; }

      await _apiService.client.patch('/users/profile', data: {'profilePicture': cloudUrl});

      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      final updatedUser = await _authService.getUser();

      if (mounted) {
        setState(() {
          _user = updatedUser;
          _avatarVersion++;
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Profile picture updated!', style: AppTypography.dmSans(fontWeight: FontWeight.w600)),
          backgroundColor: _orange, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e', style: AppTypography.dmSans(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B2C)));

    // Safely extract name fields — the server may return empty strings instead of null
    final rawFirst  = (_user?['firstName'] ?? '').toString().trim();
    final rawLast   = (_user?['lastName']  ?? '').toString().trim();
    final firstName = rawFirst.isNotEmpty ? rawFirst : '';    // keep truly empty for avatar logic
    final fullName  = (rawFirst.isNotEmpty || rawLast.isNotEmpty)
        ? '$rawFirst $rawLast'.trim()
        : 'Flettra Traveler';
    final handle    = (rawFirst.isNotEmpty || rawLast.isNotEmpty)
        ? '@${rawFirst.toLowerCase()}${rawLast.toLowerCase()}'
        : '';
    final bio        = (_user?['bio'] ?? '').toString().trim().isNotEmpty
        ? _user!['bio'].toString().trim()
        : 'Nomad by choice, traveler by heart. Exploring the world one ride at a time.';
    final totalRides = _stats?['totalRides'] ?? 0;
    final distanceKm = _stats?['totalDistanceKm'] ?? 0;
    final compass    = _stats?['compassPoints'] ?? 0;
    final plan       = (_user?['subscriptionPlan'] ?? 'free').toString().toLowerCase();
    // Try multiple field names in case the backend serialises differently
    final picField   = _user?['profilePicture'] ?? _user?['profile_picture'] ?? _user?['avatar'];
    // Build avatar URL — only add cache bust to external URLs
    final picPath    = picField?.toString().trim() ?? '';
    final cacheBust  = '${_avatarVersion}_${DateTime.now().millisecondsSinceEpoch ~/ 60000}';
    // If there's an actual uploaded pic, build the full URL; else fall back to ''
    // so _buildAvatarImage immediately renders the initials fallback (avoids localhost calls)
    String avatarUrl = '';
    if (picPath.isNotEmpty) {
      final raw = ApiService.getAvatarUrl(picPath, name: rawFirst.isNotEmpty ? rawFirst : 'U');
      avatarUrl = raw.contains('?') ? '$raw&v=$cacheBust' : '$raw?v=$cacheBust';
    }

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          Expanded(
            child: NestedScrollView(
            physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // ── Cover + AppBar ───────────────────────────────────────
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Cover illustration
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0E7090), Color(0xFF1DA1C2), Color(0xFF48C9B0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Geometric shapes for visual interest
                          Positioned(top: 20, right: 40, child: _geoShape(80, const Color(0xFF0A5F75), 20)),
                          Positioned(top: 60, right: 80, child: _geoShape(50, const Color(0xFF156A82), 14)),
                          Positioned(top: 10, right: 20, child: _geoShape(30, const Color(0xFF0C6B87).withOpacity(0.6), 8)),
                          // Settings icon top-left
                          SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _showSettings(context, plan),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
                                      child: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () => _showSettings(context, plan),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
                                      child: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Avatar overlapping cover
                    Positioned(
                      bottom: -40,
                      left: 20,
                      child: GestureDetector(
                        onTap: _pickAndUploadAvatar,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 4))],
                          ),
                          padding: const EdgeInsets.all(3),
                          child: _isUploading
                              ? const SizedBox(width: 84, height: 84, child: Center(child: CircularProgressIndicator(color: _orange)))
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(17),
                                  child: _buildAvatarImage(avatarUrl, firstName, 84),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 52), // space for overlapping avatar

                // ── Name + handle + actions ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(fullName, style: AppTypography.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: _dark, letterSpacing: -0.3)),
                                Text(handle, style: AppTypography.dmSans(fontSize: 13, color: _orange, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Action buttons
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _showEditProfile,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                              decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(24)),
                              child: Text('Edit Profile', style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey[200]!)),
                            child: const Icon(Icons.share_outlined, size: 18, color: _dark),
                          ),
                        ],
                      ),
                      // Bio
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(bio, style: AppTypography.dmSans(fontSize: 13, color: Colors.grey[600], height: 1.55, fontStyle: FontStyle.italic)),
                      ],
                      const SizedBox(height: 20),

                      // ── Stats row ────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            _statCol('$totalRides', 'RIDES'),
                            _statDivider(),
                            _statCol('${distanceKm}km', 'KILOMETERS'),
                            _statDivider(),
                            _statCol('$compass', 'SAGE POINTS'),
                          ],
                        ),
                      ),
                                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // ── Member level ─────────────────────────────────────────
                _buildMemberCard(plan, context),
                const SizedBox(height: 8),

              ],
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              TabBar(
                controller: _tabController,
                labelStyle: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.8),
                unselectedLabelStyle: AppTypography.dmSans(fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.8),
                labelColor: _orange,
                unselectedLabelColor: Colors.grey[400],
                indicatorColor: _orange,
                indicatorWeight: 3,
                dividerColor: Colors.grey[100],
                tabs: const [Tab(text: 'TIMELINE'), Tab(text: 'BUDDIES'), Tab(text: 'JOURNAL')],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTimelineTab(),
            _buildBuddiesTab(),
            _buildJournalTab(),
          ],
        ),
          )),
        ],
      ),
    );
  }

  // ─── Timeline Tab ─────────────────────────────────────────────────────────────

  Widget _buildTimelineTab() {
    if (_myPosts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_library_outlined, size: 52, color: Colors.grey[300]),
              const SizedBox(height: 14),
              Text('No posts yet', style: AppTypography.dmSans(fontWeight: FontWeight.w700, color: Colors.grey[400])),
              const SizedBox(height: 6),
              Text('Share your travel moments', style: AppTypography.dmSans(fontSize: 12, color: Colors.grey[400])),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      key: const PageStorageKey('timeline'),
      controller: _timelineScrollCtrl,
      primary: false,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      physics: const ClampingScrollPhysics(),
      itemCount: _myPosts.length,
      itemBuilder: (context, i) => _buildTimelinePost(_myPosts[i]),
    );
  }

  Widget _buildTimelinePost(dynamic post) {
    final firstName = (_user?['firstName'] ?? '').toString().trim();
    final picPath   = (_user?['profilePicture'] ?? '').toString().trim();
    final avatarUrl = picPath.isNotEmpty ? ApiService.getAvatarUrl(picPath, name: firstName) : '';
    final content   = (post['content'] ?? '').toString();
    final imageUrl  = post['imageUrl'] != null ? ApiService.getFullImageUrl(post['imageUrl']) : null;
    final likes     = (post['likes'] as List?)?.length ?? 0;
    final comments  = post['commentsCount'] ?? 0;
    final location  = post['location'] ?? 'Somewhere beautiful';
    String timeAgo  = '';
    try {
      final dt   = DateTime.parse((post['createdAt'] ?? '').toString());
      final diff = DateTime.now().difference(dt);
      timeAgo    = diff.inHours < 24 ? '${diff.inHours}h ago' : '${diff.inDays}d ago';
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFD4A76B), width: 2),
                  ),
                  child: _buildAvatarImage(avatarUrl, firstName, 36),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(firstName, style: AppTypography.dmSans(fontSize: 14, fontWeight: FontWeight.w800, color: _dark)),
                      Row(
                        children: [
                          Text(timeAgo, style: AppTypography.dmSans(fontSize: 10, color: Colors.grey[400])),
                          if (location.isNotEmpty) ...[
                            Text(' • ', style: AppTypography.dmSans(fontSize: 10, color: Colors.grey[400])),
                            const Icon(Icons.location_on_rounded, size: 10, color: _orange),
                            Flexible(child: Text(location, style: AppTypography.dmSans(fontSize: 10, color: Colors.grey[400]), overflow: TextOverflow.ellipsis)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Text(content, style: AppTypography.dmSans(fontSize: 13, color: Colors.grey[700], height: 1.55), maxLines: 4, overflow: TextOverflow.ellipsis),
          ),
          // Image
          if (imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: SafeNetworkImage(url: imageUrl, height: 200, width: double.infinity, fit: BoxFit.cover),
            ),
          // Engagement
          if (imageUrl == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.favorite_border_rounded, size: 18, color: Color(0xFFE53935)),
                  const SizedBox(width: 4),
                  Text('$likes', style: AppTypography.dmSans(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('$comments', style: AppTypography.dmSans(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w700)),
                  const Spacer(),
                  const Icon(Icons.ios_share_rounded, size: 16, color: Colors.grey),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBuddiesTab() {
    if (_myBuddies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _orange.withOpacity(0.10), shape: BoxShape.circle), child: const Icon(Icons.people_outline_rounded, size: 48, color: _orange)),
              const SizedBox(height: 16),
              Text('Your Travel Circle', style: AppTypography.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: _dark)),
              const SizedBox(height: 8),
              Text('Connect with fellow adventurers to build your circle', style: AppTypography.dmSans(fontSize: 13, color: Colors.grey[400]), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      key: const PageStorageKey('buddies'),
      controller: _buddiesScrollCtrl,
      primary: false,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      physics: const ClampingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.78,
      ),
      itemCount: _myBuddies.length,
      itemBuilder: (context, i) => _buildBuddyCard(_myBuddies[i]),
    );
  }

  Widget _buildBuddyCard(dynamic buddy) {
    final first  = (buddy['firstName'] ?? '').toString().trim();
    final last   = (buddy['lastName']  ?? '').toString().trim();
    final name   = '$first $last'.trim().isNotEmpty ? '$first $last'.trim() : (buddy['name'] ?? 'Buddy').toString().trim();
    final location = (buddy['location'] ?? '').toString().trim();
    final picField = buddy['profilePicture'] ?? buddy['profile_picture'] ?? buddy['avatar'];
    final avatarUrl = ApiService.getAvatarUrl(picField?.toString(), name: name);
    final userId = (buddy['id'] ?? buddy['_id'] ?? '').toString();

    final rawInterests = buddy['interests'];
    final interests = rawInterests is List
        ? rawInterests.map((e) => e.toString().toUpperCase()).toList()
        : <String>[];

    return GestureDetector(
      onTap: userId.isNotEmpty
          ? () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => RiderProfileScreen(userId: userId, knownName: name)))
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF5E6DC),
                    boxShadow: [BoxShadow(color: _orange.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  padding: const EdgeInsets.all(4),
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: _orange,
                    backgroundImage: avatarUrl.startsWith('http') ? NetworkImage(avatarUrl) : null,
                    child: !avatarUrl.startsWith('http')
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: AppTypography.dmSans(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white))
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 2, right: 2,
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(color: _orange, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(name, style: AppTypography.dmSans(fontSize: 14, fontWeight: FontWeight.w800, color: _dark), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (location.isNotEmpty)
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
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => RiderProfileScreen(userId: userId, knownName: name))),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(30)),
                child: Center(child: Text('View Profile', style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white))),
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildJournalTab() {
    if (_myRides.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _orange.withOpacity(0.10), shape: BoxShape.circle), child: const Icon(Icons.luggage_rounded, size: 48, color: _orange)),
              const SizedBox(height: 16),
              Text('No trips yet', style: AppTypography.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: _dark)),
              const SizedBox(height: 8),
              Text('Your travel history will appear here', style: AppTypography.dmSans(fontSize: 13, color: Colors.grey[400]), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      key: const PageStorageKey('journal'),
      controller: _journalScrollCtrl,
      primary: false,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      physics: const ClampingScrollPhysics(),
      itemCount: _myRides.length,
      itemBuilder: (context, i) => _buildJournalRideCard(_myRides[i]),
    );
  }

  Widget _buildJournalRideCard(dynamic ride) {
    final isRejected = (ride['adminStatus']?.toString() ?? 'active') == 'rejected';
    final rejectionReason = ride['adminRejectionReason']?.toString() ?? '';
    final name   = ride['name'] ?? ride['title'] ?? 'Trip';
    final origin = ride['origin'] ?? '';
    final dest   = ride['destination'] ?? '';
    final status = isRejected ? 'rejected' : (ride['status'] ?? 'pending').toString().toLowerCase();
    final date   = ride['departureDate'] ?? ride['createdAt'] ?? '';
    String dateStr = '';
    try {
      final dt = DateTime.parse(date.toString()).toLocal();
      const m  = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      dateStr  = '${dt.day} ${m[dt.month - 1]}, ${dt.year}';
    } catch (_) {}

    final coverImage = ApiService.getFullImageUrl(ride['coverImage'] ?? ride['imageUrl'] ?? '');

    Color statusColor;
    switch (status) {
      case 'completed': statusColor = const Color(0xFF10B981); break;
      case 'ongoing':
      case 'in_progress': statusColor = _orange; break;
      case 'rejected': statusColor = const Color(0xFFE53935); break;
      default: statusColor = Colors.grey;
    }

    return Opacity(
      opacity: isRejected ? 0.6 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRejected)
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFFEDED),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(children: [
                const Icon(Icons.block_rounded, size: 12, color: Color(0xFFE53935)),
                const SizedBox(width: 6),
                const Text('Removed by admin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFE53935))),
                if (rejectionReason.isNotEmpty) ...[
                  const Text('  ·  ', style: TextStyle(color: Color(0xFFE57373))),
                  Expanded(child: Text(rejectionReason, style: const TextStyle(fontSize: 11, color: Color(0xFFE57373)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ]),
            ),
      Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isRejected ? const Color(0xFFF9F9F9) : Colors.white,
        borderRadius: isRejected
            ? const BorderRadius.vertical(bottom: Radius.circular(20))
            : BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
            child: SafeNetworkImage(url: coverImage, width: 90, height: 90, fit: BoxFit.cover),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(name, style: AppTypography.dmSans(fontSize: 14, fontWeight: FontWeight.w800, color: _dark), overflow: TextOverflow.ellipsis)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text(status.toUpperCase(), style: AppTypography.dmSans(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (origin.isNotEmpty)
                    Text('$origin → $dest', style: AppTypography.dmSans(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 10, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(dateStr, style: AppTypography.dmSans(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    ),
        ],
      ),
    );
  }

  // ─── Avatar with initials fallback ───────────────────────────────────────────

  /// Tries to load [url] as a network image. On any error, renders an orange
  /// gradient initials tile (or a person icon if no name) — never the blue generic icon.
  Widget _buildAvatarImage(String url, String nameOrInitial, double size) {
    final letter   = nameOrInitial.trim();
    final initial  = letter.isNotEmpty ? letter[0].toUpperCase() : '';
    final fontSize = size * 0.38;
    final radius   = BorderRadius.circular(size * 0.2);

    Widget fallback = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
      ),
      child: Center(
        child: initial.isNotEmpty
            ? Text(
                initial,
                style: AppTypography.dmSans(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              )
            : Icon(Icons.person_rounded, size: size * 0.55, color: Colors.white),
      ),
    );

    // Only skip localhost/127 relative paths — full https URLs (e.g. Cloudinary) load fine.
    final isLocalhost = !url.startsWith('https://') &&
        (url.contains('localhost') || url.contains('127.0.0.1'));
    if (url.isEmpty || isLocalhost) {
      return ClipRRect(borderRadius: radius, child: fallback);
    }

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  // ─── Member Level Card ────────────────────────────────────────────────────────

  Widget _buildMemberCard(String plan, BuildContext ctx) {
    final levelInfo = _getMemberLevel(plan);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF2A1A14), levelInfo['color'] as Color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('MEMBER LEVEL', style: AppTypography.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: _orange, letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text(levelInfo['name'] as String, style: AppTypography.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white, fontStyle: FontStyle.italic)),
                Text(levelInfo['desc'] as String, style: AppTypography.dmSans(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // Star badge
          Stack(
            alignment: Alignment.center,
            children: [
              Container(width: 52, height: 52, decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle)),
              const Icon(Icons.star_rounded, color: Colors.white, size: 28),
            ],
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Text('VIP', style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getMemberLevel(String plan) {
    switch (plan) {
      case 'premium':   return {'name': 'Sage Elite',       'desc': 'Unlock exclusive routes & priority access.', 'color': const Color(0xFF8B1A1A)};
      case 'basic':     return {'name': 'Road Ranger',      'desc': 'Exploring more, discovering more.',           'color': const Color(0xFF1A4A8B)};
      case 'enterprise':return {'name': 'Legend Status',    'desc': 'The pinnacle of Flettra travel.',             'color': const Color(0xFF5A1A8B)};
      default:          return {'name': 'Flettra Explorer', 'desc': 'Enjoy all features for your first year!',     'color': const Color(0xFF1A5A2A)};
    }
  }

  // ─── Settings Sheet ───────────────────────────────────────────────────────────

  void _showSettings(BuildContext context, String plan) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.settings_rounded, color: _orange, size: 20)),
                    const SizedBox(width: 12),
                    Text('Settings', style: AppTypography.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: _dark)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              _settingsTile(Icons.analytics_rounded, 'My Analytics', 'Stats, insights & progress', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
              }),
              _settingsTile(Icons.emoji_events_rounded, 'Leaderboard', 'See how you rank globally', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
              }),
              _settingsTile(Icons.loyalty_rounded, 'Rewards', 'Check your Compass Points', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
              }),
              _settingsTile(Icons.history_rounded, 'Trip History', 'View all your past trips', () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AllRidesScreen()));
              }),
              _settingsTile(Icons.settings_suggest_rounded, 'Preferences', 'Customize your experience', () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Coming soon!', style: AppTypography.dmSans(fontWeight: FontWeight.w600)), backgroundColor: _orange, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
              }),
              _settingsTile(Icons.help_outline_rounded, 'Support', 'Get help & contact us', () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email: help@flettra.com', style: AppTypography.dmSans(fontWeight: FontWeight.w600)), backgroundColor: _orange, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
              }),
              const Divider(height: 1),
              // Delete Account
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withOpacity(0.06), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 20)),
                title: Text('Delete Account', style: AppTypography.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.red)),
                subtitle: Text('Permanently remove your account & data', style: AppTypography.dmSans(fontSize: 11, color: Colors.red.withOpacity(0.6))),
                onTap: () {
                  Navigator.pop(context); // close settings sheet
                  _confirmDeleteAccount(context);
                },
              ),
              // Logout
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20)),
                title: Text('Sign Out', style: AppTypography.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  await _authService.logout();
                  if (mounted) {
                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Delete Account Confirmation ──────────────────────────────────────────────

  void _confirmDeleteAccount(BuildContext context) {
    final confirmController = TextEditingController();
    bool deleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_rounded, color: Colors.red, size: 22),
              const SizedBox(width: 8),
              Text('Delete Account', style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 17, color: Colors.red)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This action cannot be undone. Your account, rides, posts, and all personal data will be permanently deleted after 60 days.',
                style: AppTypography.dmSans(fontSize: 13, color: const Color(0xFF6B7280), height: 1.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Type DELETE to confirm:',
                style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                onChanged: (_) => setDialogState(() {}),
                style: AppTypography.dmSans(fontWeight: FontWeight.w700, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'DELETE',
                  hintStyle: AppTypography.dmSans(color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F7),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: deleting ? null : () => Navigator.pop(ctx),
              child: Text('Cancel', style: AppTypography.dmSans(color: const Color(0xFF6B7280))),
            ),
            ElevatedButton(
              onPressed: (confirmController.text.trim() == 'DELETE' && !deleting)
                  ? () async {
                      setDialogState(() => deleting = true);
                      try {
                        await _apiService.client.delete('/users/me');
                        await _authService.logout();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                            (route) => false,
                          );
                        }
                      } catch (e) {
                        setDialogState(() => deleting = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Failed to delete account. Please try again.', style: AppTypography.dmSans()),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: deleting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Delete My Account', style: AppTypography.dmSans(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsTile(IconData icon, String title, String sub, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: _orange, size: 20)),
      title: Text(title, style: AppTypography.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: _dark)),
      subtitle: Text(sub, style: AppTypography.dmSans(fontSize: 11, color: Colors.grey[400])),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.grey[300]),
      onTap: onTap,
    );
  }

  // ─── Edit profile sheet ───────────────────────────────────────────────────────

  void _showEditProfile() {
    final firstCtrl = TextEditingController(text: _user?['firstName'] ?? '');
    final lastCtrl  = TextEditingController(text: _user?['lastName'] ?? '');
    final bioCtrl   = TextEditingController(text: _user?['bio'] ?? '');
    final locCtrl   = TextEditingController(text: _user?['location'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, _) => Container(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.edit_rounded, color: _orange, size: 20)),
                  const SizedBox(width: 14),
                  Text('Edit Profile', style: AppTypography.dmSans(fontSize: 20, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _field(firstCtrl, 'First name', Icons.person_outline_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(lastCtrl, 'Last name', Icons.person_outline_rounded)),
                ],
              ),
              const SizedBox(height: 12),
              _field(bioCtrl, 'Bio', Icons.info_outline_rounded, maxLines: 3),
              const SizedBox(height: 12),
              _field(locCtrl, 'Location', Icons.location_on_outlined),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await _apiService.client.patch('/users/profile', data: {
                        'firstName': firstCtrl.text.trim(),
                        'lastName': lastCtrl.text.trim(),
                        'bio': bioCtrl.text.trim(),
                        'location': locCtrl.text.trim(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _fetch();
                    } catch (_) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Save failed. Try again.', style: AppTypography.dmSans(fontWeight: FontWeight.w600)), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                  child: Text('Save Changes', style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: AppTypography.dmSans(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.dmSans(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: Colors.grey[400], size: 18),
        filled: true, fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // ─── Widget helpers ───────────────────────────────────────────────────────────

  Widget _statCol(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTypography.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 0.8)),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(height: 32, width: 1, color: Colors.grey[200]);

  Widget _geoShape(double size, Color color, double radius) {
    return Container(width: size, height: size, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)));
  }
}
