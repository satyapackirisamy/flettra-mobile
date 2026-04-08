import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'ride_details_screen.dart';
import 'create_post_screen.dart';
import 'edit_post_screen.dart';
import 'create_ride_screen.dart';
import '../widgets/common_fab.dart';
import '../widgets/network_image_widget.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  List<dynamic> _posts = [];
  List<dynamic> _nearbyRides = [];
  bool _isLoading = true;
  String _selectedScope = 'Friends'; // 'Friends' or 'Discover'

  static const Color primaryOrange = Color(0xFFFF5500);
  static const Color textDark = Color(0xFF111827);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchPosts(), _fetchNearbyRides()]);
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

  Future<void> _fetchNearbyRides() async {
    try {
      final res = await _apiService.getMyRides();
      if (mounted) setState(() => _nearbyRides = (res.data as List?) ?? []);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: primaryOrange,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _posts.isEmpty ? _buildEmptyPost() : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _posts.length,
                        itemBuilder: (context, i) => _buildPostItem(_posts[i]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Social Feed', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1)),
          _buildScopeToggle(),
        ],
      ),
    );
  }

  Widget _buildScopeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(30)),
      child: Row(children: ['Friends', 'Discover'].map((s) => _buildToggleBtn(s)).toList()),
    );
  }

  Widget _buildToggleBtn(String s) {
    final active = _selectedScope == s;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedScope = s);
        _loadData();
      },
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: active ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(20), boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : []), child: Text(s, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: active ? primaryOrange : Colors.grey))),
    );
  }

  Widget _buildPostItem(dynamic post) {
    final avatarUrl = ApiService.getAvatarUrl(
      post['author']?['profilePicture'],
      name: post['author']?['name'] ?? 'U',
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              CircleAvatar(backgroundImage: networkImageProvider(avatarUrl), radius: 18),
              const SizedBox(width: 10),
              Text(post['author']?['name'] ?? 'Unknown', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              GestureDetector(
                onTap: () => _showPostOptions(post),
                child: const Icon(Icons.more_horiz_rounded, color: Colors.grey),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          if (post['imageUrl'] != null) Container(height: 300, width: double.infinity, decoration: BoxDecoration(image: DecorationImage(image: networkImageProvider(ApiService.getFullImageUrl(post['imageUrl'])), fit: BoxFit.cover))),
          if (post['imageUrls'] != null && (post['imageUrls'] as List).isNotEmpty)
            SizedBox(
              height: 300,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: (post['imageUrls'] as List).length,
                itemBuilder: (context, idx) => Container(
                  width: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(
                    image: DecorationImage(image: networkImageProvider(ApiService.getFullImageUrl(post['imageUrls'][idx])), fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(post['content'] ?? '', style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.5)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.favorite_border_rounded, color: Colors.grey[400], size: 22),
                  onPressed: () async {
                    await ApiService().likePost(post['id']);
                    _loadData();
                  },
                ),
                Text('${(post['likes'] as List?)?.length ?? 0}', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
        ],
      ),
    );
  }

  void _showPostOptions(dynamic post) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: Text('Edit Post', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EditPostScreen(post: post)),
                );
                if (result == true) _loadData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: Text('Delete Post', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Post'),
                    content: const Text('Are you sure you want to delete this post?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirmed == true) {
                  try {
                    await ApiService().deletePost(post['id']);
                    _loadData();
                  } catch (_) {}
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPost() {
    return Center(child: Padding(padding: const EdgeInsets.all(40), child: Text('Share your traveler moments.', style: GoogleFonts.plusJakartaSans(color: Colors.grey))));
  }
}
