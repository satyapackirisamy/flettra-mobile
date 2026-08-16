import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/moderation_sheet.dart';
import '../theme/app_spacing.dart';
import '../theme/flettra_colors.dart';
import 'chat_screen.dart';

class RiderProfileScreen extends StatefulWidget {
  final String userId;
  final String? knownName;

  const RiderProfileScreen({super.key, required this.userId, this.knownName});

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  final ApiService _api = ApiService();

  Map<String, dynamic>? _user;
  List<dynamic> _rides = [];
  bool _isLoading = true;
  bool _buddyRequestSent = false;
  bool _isAlreadyBuddy = false;
  String? _currentUserId;

  /// True when this profile belongs to the signed-in user.
  bool get _isSelf =>
      _currentUserId != null && _currentUserId == widget.userId;

  static const Color _orange = Color(0xFFFF6B2C);
  static const Color _dark   = Color(0xFF1A0A08);
  static const Color _bg     = Colors.white;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Opens the conversation with this rider. ChatScreen takes the buddy map, so
  /// pass what we loaded and fall back to the id/name we were given.
  void _openChat() {
    // Guard against opening a conversation with yourself. The test data has
    // rows where sender_id == receiver_id, which is how that gets created.
    if (_isSelf) {
      showError(context, "That's your own profile.");
      return;
    }
    final buddy = _user ??
        <String, dynamic>{'id': widget.userId, 'name': widget.knownName ?? ''};
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(buddy: buddy)),
    );
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getUserById(widget.userId),
        _api.client.get('/rides', queryParameters: {'driverId': widget.userId}).catchError(
          (_) => Response(requestOptions: RequestOptions(path: ''), data: []),
        ),
        _api.getBuddies().catchError(
          (_) => Response(requestOptions: RequestOptions(path: ''), data: []),
        ),
        _api.getProfile().catchError(
          (_) => Response(requestOptions: RequestOptions(path: ''), data: {}),
        ),
      ]);
      if (mounted) {
        final userData  = results[0].data;
        final ridesData = results[1].data;
        final buddyData = results[2].data;
        final buddyList = buddyData is List ? buddyData : [];
        final alreadyBuddy = buddyList.any((b) =>
            (b['id'] ?? b['_id'])?.toString() == widget.userId);
        final me = results[3].data;
        setState(() {
          _user            = userData is Map<String, dynamic> ? userData : null;
          _rides           = ridesData is List ? ridesData : [];
          _isAlreadyBuddy  = alreadyBuddy;
          _currentUserId   = me is Map ? me['id']?.toString() : null;
          _isLoading       = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendBuddyRequest() async {
    try {
      await _api.sendBuddyRequest(widget.userId);
      setState(() => _buddyRequestSent = true);
      if (mounted) showSuccess(context, 'Buddy request sent!');
    } catch (_) {
      if (mounted) showError(context, 'Could not send buddy request');
    }
  }

  String _displayName() {
    if (_user == null) return widget.knownName ?? 'Rider';
    final first = (_user!['firstName'] ?? '').toString().trim();
    final last  = (_user!['lastName']  ?? '').toString().trim();
    final full  = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    final name = (_user!['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    return widget.knownName ?? 'Rider';
  }

  String _handle() {
    final first = (_user?['firstName'] ?? '').toString().trim().toLowerCase();
    final last  = (_user?['lastName']  ?? '').toString().trim().toLowerCase();
    if (first.isNotEmpty) return '@$first$last';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverHeader(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStats(),
                        const SizedBox(height: 20),
                        _buildBio(),
                        if (_rides.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildRidesSection(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _isLoading ? null : _buildBottomBar(),
    );
  }

  Widget _buildSliverHeader() {
    final name    = _displayName();
    final handle  = _handle();
    final picPath = _user?['profilePicture']?.toString().trim() ?? '';
    final isLocalhost = picPath.contains('localhost') || picPath.contains('127.0.0.1');
    final avatarUrl = (!isLocalhost && picPath.isNotEmpty)
        ? ApiService.getAvatarUrl(picPath, name: name)
        : '';

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cover + back button + avatar overlap ──────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Cover
              Container(
                height: 180,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF6B2C), Color(0xFFFF8C5A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(top: 20, right: 40,
                        child: _geoCircle(80, Colors.white.withOpacity(0.08))),
                    Positioned(top: 60, right: 90,
                        child: _geoCircle(50, Colors.white.withOpacity(0.06))),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Back button
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                            // Three-dot options (only for other users)
                            GestureDetector(
                              onTap: () => showModerationSheet(
                                context,
                                targetUserId: widget.userId,
                                targetName: _displayName(),
                                onActionDone: () {
                                  Navigator.pop(context);
                                },
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.more_vert_rounded,
                                    color: Colors.white, size: 18),
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
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.12),
                          blurRadius: 16, offset: const Offset(0, 4))
                    ],
                  ),
                  padding: const EdgeInsets.all(3),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: _buildAvatar(avatarUrl, name, 84),
                  ),
                ),
              ),
            ],
          ),
          // ── Space for overlapping avatar ──────────────────────────────
          const SizedBox(height: 52),
          // ── Name + handle ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTypography.dmSans(
                        fontSize: 22, fontWeight: FontWeight.w700,
                        color: _dark, letterSpacing: -0.3)),
                if (handle.isNotEmpty)
                  Text(handle,
                      style: AppTypography.dmSans(
                          fontSize: 13, color: _orange,
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAvatar(String url, String name, double size) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final radius  = BorderRadius.circular(size * 0.2);

    Widget fallback = Container(
      width: size, height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFFF6B2C), Color(0xFFFF8C5A)]),
      ),
      child: Center(
        child: Text(initial,
            style: AppTypography.dmSans(
                fontSize: size * 0.38, fontWeight: FontWeight.w700,
                color: Colors.white)),
      ),
    );

    if (url.isEmpty) return ClipRRect(borderRadius: radius, child: fallback);

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        url, width: size, height: size, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  Widget _geoCircle(double size, Color color) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildStats() {
    final totalRides = (_rides.length).toString();
    final plan = (_user?['subscriptionPlan'] ?? 'free').toString().toLowerCase();
    final isPro = plan == 'pro' || plan == 'premium';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 12, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          _statItem(totalRides, 'Rides'),
          _divider(),
          _statItem('4.8', 'Rating'),
          _divider(),
          _statItem(isPro ? 'Pro' : 'Free', 'Plan',
              valueColor: isPro ? _orange : Colors.grey[500]),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, {Color? valueColor}) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppTypography.dmSans(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: valueColor ?? _dark)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTypography.dmSans(
                  fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 36, color: Colors.grey[100]);

  Widget _buildBio() {
    final bio = (_user?['bio'] ?? '').toString().trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ABOUT',
            style: AppTypography.dmSans(
                fontSize: 11, fontWeight: FontWeight.w800,
                color: Colors.grey[400], letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03),
                  blurRadius: 8, offset: const Offset(0, 2))
            ],
          ),
          child: Text(
            bio.isNotEmpty
                ? bio
                : 'Adventure seeker & travel enthusiast. Always ready for the next ride.',
            style: AppTypography.dmSans(
                fontSize: 14, color: Colors.grey[600], height: 1.6,
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildRidesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('RIDES',
                style: AppTypography.dmSans(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: Colors.grey[400], letterSpacing: 1.2)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: _orange, borderRadius: BorderRadius.circular(10)),
              child: Text('${_rides.length}',
                  style: AppTypography.dmSans(
                      fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._rides.take(5).map((r) {
          final origin  = r['origin']?.toString()      ?? '';
          final dest    = r['destination']?.toString() ?? '';
          final date    = _fmtDate(r['departureDate']?.toString());
          final price   = r['pricePerSeat'] ?? 0;
          final status  = (r['status'] ?? 'scheduled').toString();
          final statusColor = status == 'ongoing'
              ? const Color(0xFF10B981)
              : status == 'completed'
                  ? const Color(0xFF6366F1)
                  : _orange;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03),
                    blurRadius: 8, offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: _orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.directions_car_rounded,
                      color: _orange, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        origin.isNotEmpty && dest.isNotEmpty
                            ? '$origin → $dest'
                            : dest.isNotEmpty ? dest : origin,
                        style: AppTypography.dmSans(
                            fontWeight: FontWeight.w800, fontSize: 13,
                            color: _dark),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (date.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(date,
                            style: AppTypography.dmSans(
                                fontSize: 11, color: Colors.grey[400],
                                fontWeight: FontWeight.w500)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(price != null && price != 0 ? '~₹$price' : 'Free',
                        style: AppTypography.dmSans(
                            fontWeight: FontWeight.w800, fontSize: 13,
                            color: _orange)),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status[0].toUpperCase() + status.substring(1),
                        style: AppTypography.dmSans(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: statusColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBottomBar() {
    final c = context.c;
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md,
          MediaQuery.of(context).padding.bottom + AppSpacing.xs),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.rule, width: 0.5)),
      ),
      // Being buddies is a state, not an action. The bar previously spent the
      // one primary slot on a disabled button restating what the screen already
      // shows — so the whole point of opening someone's profile, messaging
      // them, had nowhere to go. Now the state is a quiet line and the action
      // is the button.
      child: _isSelf
          ? Text('This is your profile',
              textAlign: TextAlign.center,
              style: AppTypography.footnote.copyWith(color: c.ink3))
          : _isAlreadyBuddy
          ? Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 16, color: c.ok),
                const SizedBox(width: AppSpacing.xxs + 2),
                Expanded(
                  child: Text('Buddies',
                      style: AppTypography.footnote.copyWith(color: c.ok)),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilledButton.icon(
                  onPressed: _openChat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                  label: const Text('Message'),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.brand,
                    foregroundColor: c.onBrand,
                    minimumSize: const Size(0, AppTouch.min),
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.cardR),
                    textStyle: AppTypography.bodyStrong,
                  ),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _buddyRequestSent ? null : _sendBuddyRequest,
                icon: Icon(
                    _buddyRequestSent ? Icons.check_circle_rounded : Icons.person_add_rounded,
                    size: 18),
                label: Text(
                    _buddyRequestSent ? 'Request Sent' : 'Add as Buddy',
                    style: AppTypography.dmSans(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _buddyRequestSent ? Colors.grey[300] : _orange,
                  disabledBackgroundColor: Colors.grey[300],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
    );
  }

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return ''; }
  }
}
