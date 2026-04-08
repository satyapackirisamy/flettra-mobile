import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
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

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getMyGroups(),
        _api.getGroups(),
      ]);
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
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final res = await _api.client.get('/notifications');
      final notifs = (res.data as List?) ?? [];
      final unread = notifs.where((n) => n['isRead'] != true).length;
      if (mounted) setState(() => _unreadNotifications = unread);
    } catch (_) {}
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
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Create New Group', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'Group name',
                  filled: true, fillColor: const Color(0xFFF8F9FA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Description (optional)',
                  filled: true, fillColor: const Color(0xFFF8F9FA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Private Group', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                  Switch(
                    value: isPrivate,
                    onChanged: (v) => setSheetState(() => isPrivate = v),
                    activeColor: const Color(0xFFFF5500),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    try {
                      await _api.createGroup({
                        'name': nameCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'isPrivate': isPrivate,
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) showSuccess(context, 'Group created!');
                      _loadGroups();
                    } catch (e) {
                      if (ctx.mounted) showError(ctx, 'Failed to create group');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5500),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text('Create Group', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<dynamic> get _filteredMyGroups => _search.isEmpty
      ? _myGroups
      : _myGroups.where((g) => (g['name'] ?? '').toString().toLowerCase().contains(_search.toLowerCase())).toList();

  List<dynamic> get _filteredSuggested => _search.isEmpty
      ? _allGroups
      : _allGroups.where((g) => (g['name'] ?? '').toString().toLowerCase().contains(_search.toLowerCase())).toList();

  String _groupImage(int index) {
    const images = [
      'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?q=80&w=800',
      'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?q=80&w=800',
      'https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?q=80&w=800',
      'https://images.unsplash.com/photo-1530789253388-582c481c54b0?q=80&w=800',
    ];
    return images[index % images.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5500)))
            : RefreshIndicator(
                onRefresh: _loadGroups,
                color: const Color(0xFFFF5500),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(child: Text('My Groups', style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800))),
                        GestureDetector(
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                            _fetchUnreadCount();
                          },
                          child: Stack(
                            children: [
                              const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.notifications_none_rounded, size: 24)),
                              if (_unreadNotifications > 0)
                                Positioned(
                                  right: 2, top: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                    decoration: const BoxDecoration(color: Color(0xFFFF5500), shape: BoxShape.circle),
                                    child: Center(child: Text('${_unreadNotifications > 9 ? '9+' : _unreadNotifications}', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Search
                    TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Search groups...',
                        hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
                        filled: true, fillColor: const Color(0xFFF8F9FA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Create button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _createGroup,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: Text('Create New Group', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5500),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Featured group (first one)
                    if (_filteredMyGroups.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () => _openGroup(_filteredMyGroups[0]),
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            image: DecorationImage(image: NetworkImage(_groupImage(0)), fit: BoxFit.cover),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                              ),
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_filteredMyGroups[0]['name'] ?? 'Group', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.people_rounded, size: 16, color: Colors.white70),
                                    const SizedBox(width: 6),
                                    Text('${(_filteredMyGroups[0]['members'] as List?)?.length ?? 0} members', style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
                                    const Spacer(),
                                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Other my groups
                    ..._filteredMyGroups.skip(1).toList().asMap().entries.map((entry) {
                      final g = entry.value;
                      final members = (g['members'] as List?) ?? [];
                      return GestureDetector(
                        onTap: () => _openGroup(g),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(20)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g['name'] ?? 'Group', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800)),
                              if (g['description'] != null && g['description'].toString().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(g['description'], maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.plusJakartaSans(color: Colors.grey[600], fontSize: 13, height: 1.4)),
                              ],
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
                                child: Text('${members.length} MEMBERS', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFFF5500))),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    // Empty state
                    if (_filteredMyGroups.isEmpty && _search.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.groups_rounded, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('No groups yet', style: GoogleFonts.plusJakartaSans(color: Colors.grey[400], fontWeight: FontWeight.w700)),
                            Text('Create one or join a suggested group below', style: GoogleFonts.plusJakartaSans(color: Colors.grey[400], fontSize: 12)),
                          ],
                        ),
                      ),
                    // Suggested groups
                    if (_filteredSuggested.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Suggested for You', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800)),
                          Text('VIEW ALL', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFFFF5500))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _filteredSuggested.length,
                          itemBuilder: (context, i) {
                            final g = _filteredSuggested[i];
                            return GestureDetector(
                              onTap: () => _openGroup(g),
                              child: Container(
                                width: 160,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(20)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.explore_rounded, color: Color(0xFFFF5500), size: 20),
                                    ),
                                    const Spacer(),
                                    Text(g['name'] ?? 'Group', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(g['description'] ?? '', style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                                      child: Center(child: Text('Join', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13))),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  void _openGroup(dynamic g) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailsScreen(groupId: g['id'].toString())))
      .then((_) => _loadGroups());
  }
}
