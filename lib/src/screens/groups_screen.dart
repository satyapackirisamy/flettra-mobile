import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import '../services/api_service.dart';
import '../theme/app_spacing.dart';
import '../theme/flettra_colors.dart';
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
          decoration: BoxDecoration(
            color: context.c.surfaceRaised,
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
                  Text('New Group', style: AppTypography.dmSans(fontSize: 20, fontWeight: FontWeight.w800)),
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
                    Expanded(child: Text('Private Group', style: AppTypography.dmSans(fontWeight: FontWeight.w700))),
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
                  child: Text('Create Group', style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 15)),
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
                      _sectionLabel('Your circles', '${_filteredMyGroups.length}'),
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

  /// One word for one thing. This screen previously called the same object a
  /// "Club" in the title and button, a "Group" in the section header, and the
  /// tab bar said "Circles" — three names for one concept on one screen.
  /// The product calls them Circles, so they are Circles everywhere.
  Widget _buildHeader() {
    final c = context.c;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.xs, AppSpacing.xs, 0),
        child: Row(
          children: [
            Expanded(
              child: Text('Circles',
                  style: AppTypography.display.copyWith(color: c.ink)),
            ),
            IconButton(
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                _fetchUnreadCount();
              },
              tooltip: 'Notifications',
              iconSize: 22,
              color: c.ink,
              constraints: const BoxConstraints(
                  minWidth: AppTouch.iosMin, minHeight: AppTouch.iosMin),
              icon: Stack(
                alignment: Alignment.topRight,
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none_rounded),
                  if (_unreadNotifications > 0)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: c.brand,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.surface, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndCreate() {
    final c = context.c;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
        child: TextField(
          onChanged: (v) => setState(() => _search = v),
          style: AppTypography.body.copyWith(color: c.ink),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search circles',
            hintStyle: AppTypography.body.copyWith(color: c.ink3),
            prefixIcon: Icon(Icons.search_rounded, color: c.ink3, size: 18),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 38, minHeight: 38),
            filled: true,
            fillColor: c.surfaceSunken,
            border: OutlineInputBorder(
                borderRadius: AppRadius.chipR, borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.chipR, borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
          ),
        ),
      ),
    );
  }

  /// The "Start a New Club" bar is gone. Creating a circle is the same kind of
  /// action as creating a ride or a post, and the FAB already offers all three
  /// — a full-width gradient button competing with it was the loudest thing on
  /// a screen whose job is to list what you are already in.
  Widget _sectionLabel(String title, String count) {
    final c = context.c;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs - 1),
        child: Row(
          children: [
            Text(title, style: AppTypography.title.copyWith(color: c.ink)),
            if (count.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.xs - 2),
              Text(count, style: AppTypography.title.copyWith(color: c.ink3)),
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
                                    Text('PRIVATE', style: AppTypography.dmSans(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        Text(g['name'] ?? 'Group', style: AppTypography.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                                  Text('${_memberCount(g)} members', style: AppTypography.dmSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                              child: Text('Open', style: AppTypography.dmSans(color: _primary, fontWeight: FontWeight.w800, fontSize: 12)),
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
          final c = context.c;
          final g = _filteredMyGroups[i + 1];
          final memberCount = _memberCount(g);
          final description = (g['description'] ?? '').toString();
          final isPrivate = g['isPrivate'] == true;

          // A separated list row rather than a floating card. Six of these fit
          // where three did, and the row still carries more information.
          return InkWell(
            onTap: () => _openGroup(g),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.ruleSoft)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: c.brandWash,
                      borderRadius: AppRadius.cardR,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      (g['name'] as String? ?? 'C')
                          .characters
                          .first
                          .toUpperCase(),
                      style: AppTypography.heading.copyWith(color: c.brand),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(g['name'] ?? 'Circle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                AppTypography.bodyStrong.copyWith(color: c.ink)),
                        if (description.isNotEmpty)
                          Text(description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.callout
                                  .copyWith(color: c.ink2)),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Text(
                              '$memberCount ${memberCount == 1 ? "member" : "members"}',
                              style: AppTypography.footnote
                                  .copyWith(color: c.ink3),
                            ),
                            if (isPrivate) ...[
                              Text('  ·  ',
                                  style: AppTypography.footnote
                                      .copyWith(color: c.ink3)),
                              Icon(Icons.lock_outline_rounded,
                                  size: 11, color: c.ink3),
                              const SizedBox(width: 2),
                              Text('Private',
                                  style: AppTypography.footnote
                                      .copyWith(color: c.ink3)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.ink3, size: 20),
                ],
              ),
            ),
          );
        },
        childCount: _filteredMyGroups.length - 1,
      ),
    );
  }

  Widget _buildEmptyMyGroups() {
    final c = context.c;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.xxl, horizontal: AppSpacing.md),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: c.brandWash, borderRadius: AppRadius.cardR),
              child: Icon(Icons.groups_rounded, size: 26, color: c.brand),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text("You're not in a circle yet",
                style: AppTypography.heading.copyWith(color: c.ink)),
            const SizedBox(height: AppSpacing.xxs),
            Text('Join one below, or start your own from the + button.',
                textAlign: TextAlign.center,
                style: AppTypography.callout.copyWith(color: c.ink2)),
          ],
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
                  color: context.c.surfaceRaised,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF0E8E6)),
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
                          style: AppTypography.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(g['name'] ?? 'Group', style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF1A1A1A)), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(g['description'] ?? '', style: AppTypography.dmSans(color: Colors.grey[500], fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.people_outline_rounded, size: 12, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text('$members', style: AppTypography.dmSans(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: _bgSoft, borderRadius: BorderRadius.circular(8)),
                          child: Text('Join', style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 11, color: _primary)),
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
