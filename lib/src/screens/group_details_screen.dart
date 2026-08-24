import 'package:flutter/material.dart';
import '../theme/flettra_colors.dart';
import '../theme/app_typography.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/chat_widget.dart';
import '../widgets/network_image_widget.dart';
import 'create_ride_screen.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailsScreen({super.key, required this.groupId});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();

  Map<String, dynamic>? _group;
  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;
  bool _joinRequestSent = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _currentUser = await _auth.getUser();
    await _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getGroupDetails(widget.groupId);
      setState(() => _group = res.data);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinGroup() async {
    try {
      await _api.joinGroup(widget.groupId);
      setState(() => _joinRequestSent = true);
      _fetchDetails();
      if (mounted) {
        showSuccess(context, 'Join request sent!');
      }
    } catch (e) {
      if (mounted) {
        showError(context, 'Failed to join');
      }
    }
  }

  Future<void> _respondToRequest(String requestId, String status) async {
    try {
      await _api.respondToGroupRequest(widget.groupId, requestId, status);
      _fetchDetails();
    } catch (_) {}
  }

  String _displayName(dynamic user) {
    if (user == null) return 'User';
    final name = user['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name;
    final first = user['firstName'] as String? ?? '';
    final last = user['lastName'] as String? ?? '';
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    return user['email']?.toString().split('@')[0] ?? 'User';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(backgroundColor: context.c.surface, body: Center(child: CircularProgressIndicator(color: context.c.brand)));
    if (_group == null) return Scaffold(backgroundColor: context.c.surface, body: Center(child: Text('Group not found')));

    final members = (_group!['members'] as List?) ?? [];
    final admin = _group!['admin'];
    final isMember = members.any((m) => m['id'] == _currentUser?['id']);
    final isAdmin = admin?['id'] == _currentUser?['id'];
    final pendingRequests = (_group!['pendingRequests'] as List?) ?? [];

    return Scaffold(
      backgroundColor: context.c.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: context.c.surface,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.9),
                child: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.black87), onPressed: () => Navigator.pop(context)),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  SafeNetworkImage(url: 'https://images.unsplash.com/photo-1506012787146-f92b2d7d6d96?q=80&w=800', fit: BoxFit.cover),
                  Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.7)]))),
                  Positioned(
                    bottom: 20, left: 24, right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_group!['isPrivate'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(color: context.c.surfaceRaised.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                            child: Text('PRIVATE', style: AppTypography.dmSans(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                          ),
                        Text(_group!['name'] ?? 'Group', style: AppTypography.dmSans(fontSize: 26, fontWeight: FontWeight.w800, color: context.c.onBrand)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.people_rounded, size: 14, color: Colors.white70),
                            const SizedBox(width: 6),
                            Text('${members.length} members', style: AppTypography.dmSans(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  if (_group!['description'] != null && _group!['description'].toString().isNotEmpty) ...[
                    Text(_group!['description'], style: AppTypography.dmSans(color: context.c.ink2, fontSize: 14, height: 1.5)),
                    const SizedBox(height: 24),
                  ],

                  // Join button for non-members
                  if (!isMember) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _joinRequestSent ? null : _joinGroup,
                        icon: Icon(_joinRequestSent ? Icons.check_rounded : Icons.group_add_rounded, size: 20),
                        label: Text(_joinRequestSent ? 'Request Sent' : 'Request to Join', style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.c.brand,
                          disabledBackgroundColor: context.c.ink3,
                          foregroundColor: context.c.onBrand,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Admin info
                  if (admin != null) ...[
                    Text('Admin', style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: context.c.ink2)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: context.c.surfaceSunken, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: context.c.brandWash,
                            child: Text(_displayName(admin)[0].toUpperCase(), style: AppTypography.dmSans(fontWeight: FontWeight.w800, color: context.c.brand)),
                          ),
                          const SizedBox(width: 12),
                          Text(_displayName(admin), style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 15)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: context.c.warnWash, borderRadius: BorderRadius.circular(8)),
                            child: Text('Admin', style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: context.c.brand)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Members
                  Text('Members (${members.length})', style: AppTypography.dmSans(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  ...members.map((m) {
                    final isGroupAdmin = m['id'] == admin?['id'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: isGroupAdmin ? context.c.brandWash : context.c.surfaceSunken,
                            child: Text(_displayName(m)[0].toUpperCase(), style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 13, color: isGroupAdmin ? context.c.brand : context.c.ink2)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_displayName(m), style: AppTypography.dmSans(fontWeight: FontWeight.w700, fontSize: 14))),
                          if (isGroupAdmin)
                            Text('Admin', style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: context.c.brand)),
                        ],
                      ),
                    );
                  }),

                  // Pending requests (admin only)
                  if (isAdmin && pendingRequests.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Pending Requests', style: AppTypography.dmSans(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    ...pendingRequests.map((req) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: context.c.brandWash, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Expanded(child: Text(_displayName(req['user']), style: AppTypography.dmSans(fontWeight: FontWeight.w700))),
                          IconButton(icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28), onPressed: () => _respondToRequest(req['id'], 'accepted')),
                          IconButton(icon: const Icon(Icons.cancel_rounded, color: Colors.red, size: 28), onPressed: () => _respondToRequest(req['id'], 'rejected')),
                        ],
                      ),
                    )),
                  ],

                  // Quick action cards
                  const SizedBox(height: 24),
                  if (isMember) ...[
                    _actionCard(Icons.chat_bubble_outline_rounded, 'Group Chat', 'Message everyone', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                        backgroundColor: context.c.surface,
                        appBar: AppBar(title: Text('Group Chat', style: AppTypography.dmSans(fontWeight: FontWeight.w800)), backgroundColor: context.c.surface, elevation: 0),
                        body: ChatWidget(groupId: widget.groupId, title: 'Chat'),
                      )));
                    }),
                    const SizedBox(height: 8),
                    _actionCard(Icons.directions_car_rounded, 'Plan a Ride', 'Create a ride with this group', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRideScreen()));
                    }),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.c.surfaceSunken, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: context.c.warnWash, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: context.c.brand),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(subtitle, style: AppTypography.dmSans(fontSize: 12, color: context.c.ink2, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.c.ink3),
          ],
        ),
      ),
    );
  }
}
