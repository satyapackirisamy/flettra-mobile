import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/network_image_widget.dart';
import 'group_details_screen.dart';
import 'notifications_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _myGroups = [];
  List<dynamic> _allGroups = [];
  bool _isLoading = true;
  String _search = '';
  int _unreadNotifications = 0;

  static const Color _primary = Color(0xFFFF6B2C);
  static const Color _accent = Color(0xFFFF7851);
  static const Color _bgSoft = Color(0xFFFFF0EB);

  static const List<String> _heroImages = [
    'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?q=80&w=800',
    'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?q=80&w=800',
    'https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?q=80&w=800',
    'https://images.unsplash.com/photo-1530789253388-582c481c54b0?q=80&w=800',
  ];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([_api.getMyGroups(), _api.getGroups()]);
      if (mounted) {
        setState(() {
          _myGroups = (results[0].data as List?) ?? [];
          final all = (results[1].data as List?) ?? [];
          final myIds = _myGroups.map((g) => g['id']).toSet();
          _allGroups = all.where((g) => !myIds.contains(g['id'])).toList();
          _isLoading = false;
        });
        _fetchUnreadCount();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final res = await _api.client.get('/notifications');
      final notifs = (res.data as List?) ?? [];
      if (mounted) setState(() => _unreadNotifications = notifs.where((n) => n['isRead'] != true).length);
    } catch (_) {}
  }

  List<dynamic> get _filteredMyGroups => _search.isEmpty
      ? _myGroups
      : _myGroups.where((g) => (g['name'] ?? '').toString().toLowerCase().contains(_search.toLowerCase())).toList();

  List<dynamic> get _filteredSuggested => _search.isEmpty
      ? _allGroups
      : _allGroups.where((g) => (g['name'] ?? '').toString().toLowerCase().contains(_search.toLowerCase())).toList();

  String _groupImage(int index) => _heroImages[index % _heroImages.length];

  int _memberCount(dynamic g) => (g['members'] as List?)?.length ?? 0;

  void _openGroup(dynamic g) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailsScreen(groupId: g['id'].toString())))
        .then((_) => _loadGroups());
  }

  void _createGroup() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isPrivate = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.group_add_rounded, color: _primary, size: 22)),
                  const SizedBox(width: 14),
                  Text('New Group', style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 20),
              _formField(nameCtrl, 'Group name', Icons.groups_rounded),
              const SizedBox(height: 12),
              _formField(descCtrl, 'Description (optional)', Icons.description_rounded, maxLines: 3),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Private Group', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700))),
                    Switch(value: isPrivate, onChanged: (v) => setSheetState(() => isPrivate = v), activeColor: _primary),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    try {
                      await _api.createGroup({'name': nameCtrl.text.trim(), 'description': descCtrl.text.trim(), 'isPrivate': isPrivate});
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) showSuccess(context, 'Group created!');
                      _loadGroups();
                    } catch (_) {
                      if (ctx.mounted) showError(ctx, 'Failed to create group');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text('Create Group', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formField(TextEditingController ctrl, String hint, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: GoogleFonts.dmSans(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: Colors.grey[400], size: 18),
        filled: true, fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : RefreshIndicator(
                onRefresh: _loadGroups,
                color: _primary,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildHeader(),
                    _buildSearchAndCreate(),
                    if (_filteredMyGroups.isNotEmpty) ...[
                      _sectionLabel('My Groups', '${_filteredMyGroups.length}'),
                      _buildFeaturedGroup(),
                      if (_filteredMyGroups.length > 1) _buildMyGroupsList(),
                    ] else if (_search.isEmpty)
                      _buildEmptyMyGroups(),
                    if (_filteredSuggested.isNotEmpty) ...[
                      _sectionLabel('Suggested for You', ''),
                      _buildSuggestedGrid(),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Clubs', style: GoogleFonts.dmSans(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -1, color: const Color(0xFF1A1A1A))),
                  Text('Find your riding tribe', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                _fetchUnreadCount();
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(14)),
                child: Stack(
                  children: [
                    const Icon(Icons.notifications_none_rounded, size: 22, color: Color(0xFF1A1A1A)),
                    if (_unreadNotifications > 0)
                      Positioned(
                        right: 0, top: 0,
                        child: Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndCreate() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Column(
          children: [
            TextField(
              onChanged: (v) => setState(() => _search = v),
              style: GoogleFonts.dmSans(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search clubs...',
                hintStyle: GoogleFonts.dmSans(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                filled: true, fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _createGroup,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_primary, _accent]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text('Start a New Club', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String title, String count) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
        child: Row(
          children: [
            Text(title, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A))),
            if (count.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(8)),
                child: Text(count, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: _primary)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedGroup() {
    final g = _filteredMyGroups[0];
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: GestureDetector(
          onTap: () => _openGroup(g),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 220,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SafeNetworkImage(url: _groupImage(0), fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20, right: 20, bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (g['isPrivate'] == true)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.lock_rounded, size: 10, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text('PRIVATE', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        Text(g['name'] ?? 'Group', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.people_rounded, size: 14, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text('${_memberCount(g)} members', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                              child: Text('Open', style: GoogleFonts.dmSans(color: _primary, fontWeight: FontWeight.w800, fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyGroupsList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final g = _filteredMyGroups[i + 1];
          final memberCount = _memberCount(g);
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: GestureDetector(
              onTap: () => _openGroup(g),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF0E8E6)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    // Group color avatar
                    Container(
                      width: 54, height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primary.withOpacity(0.8), _accent.withOpacity(0.6)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          (g['name'] as String? ?? 'G').substring(0, 1).toUpperCase(),
                          style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g['name'] ?? 'Group', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A))),
                          if ((g['description'] ?? '').toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(g['description'], maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(color: Colors.grey[500], fontSize: 12)),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.people_outline_rounded, size: 13, color: Color(0xFFFF6B2C)),
                              const SizedBox(width: 4),
                              Text('$memberCount members', style: GoogleFonts.dmSans(color: const Color(0xFFFF6B2C), fontSize: 11, fontWeight: FontWeight.w700)),
                              if (g['isPrivate'] == true) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.lock_outline_rounded, size: 11, color: Colors.grey),
                                const SizedBox(width: 2),
                                Text('Private', style: GoogleFonts.dmSans(color: Colors.grey, fontSize: 11)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                  ],
                ),
              ),
            ),
          );
        },
        childCount: _filteredMyGroups.length - 1,
      ),
    );
  }

  Widget _buildEmptyMyGroups() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(24)),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.groups_rounded, size: 40, color: _primary),
              ),
              const SizedBox(height: 16),
              Text('No clubs yet', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF1A1A1A))),
              const SizedBox(height: 6),
              Text('Create one or join a suggested club below', style: GoogleFonts.dmSans(color: Colors.grey[500], fontSize: 13), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestedGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final g = _filteredSuggested[i];
            final members = _memberCount(g);
            final colors = [
              [const Color(0xFFFF6B2C), const Color(0xFFFF7851)],
              [const Color(0xFF1A5276), const Color(0xFF2E86C1)],
              [const Color(0xFF145A32), const Color(0xFF27AE60)],
              [const Color(0xFF4A235A), const Color(0xFF8E44AD)],
            ];
            final c = colors[i % colors.length];
            return GestureDetector(
              onTap: () => _openGroup(g),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF0E8E6)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: c, begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          (g['name'] as String? ?? 'G').substring(0, 1).toUpperCase(),
                          style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(g['name'] ?? 'Group', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF1A1A1A)), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(g['description'] ?? '', style: GoogleFonts.dmSans(color: Colors.grey[500], fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.people_outline_rounded, size: 12, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text('$members', style: GoogleFonts.dmSans(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(8)),
                          child: Text('Join', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 11, color: _primary)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: _filteredSuggested.length,
        ),
      ),
    );
  }
}
