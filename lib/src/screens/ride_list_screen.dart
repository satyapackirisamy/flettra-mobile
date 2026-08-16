import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/network_image_widget.dart';
import 'ride_details_screen.dart';
import 'notifications_screen.dart';
import 'all_rides_screen.dart';
import 'main_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pulse loader
// ─────────────────────────────────────────────────────────────────────────────

class _PulseLoader extends StatefulWidget {
  const _PulseLoader();

  @override
  State<_PulseLoader> createState() => _PulseLoaderState();
}

class _PulseLoaderState extends State<_PulseLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 340,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _anim,
              builder: (_, child) => Opacity(opacity: _anim.value, child: child),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B2C), Color(0xFFFF8C5A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: _anim,
              builder: (_, child) => Opacity(opacity: _anim.value, child: child),
              child: Text(
                'Finding rides...',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFFF6B2C),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Keep _SkeletonCard stub to avoid removal of the class reference
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pressable card wrapper — scales down on tap for haptic feel
// ─────────────────────────────────────────────────────────────────────────────

class _PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressableCard({required this.child, required this.onTap});

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_)   => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.965 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────

class RideListScreen extends StatefulWidget {
  const RideListScreen({super.key});

  @override
  State<RideListScreen> createState() => RideListScreenState();
}

class RideListScreenState extends State<RideListScreen> {
  void refresh() => _fetchRides();

  final ApiService _apiService = ApiService();

  List<dynamic> _rides        = [];
  List<dynamic> _destinations = [];
  String        _userName     = 'Explorer';
  String?       _userId;
  bool          _isLoading    = true;
  String        _filter       = 'All';
  int           _unreadCount  = 0;

  static const Color _orange   = Color(0xFFFF6B2C);
  static const Color _textDark = Color(0xFF1F2937);
  static const Color _bg       = Colors.white;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchRides();
  }

  // ─── Data ───────────────────────────────────────────────────────────────────

  /// Loads the home screen.
  ///
  /// Previously this awaited a single `Future.wait` over four things — rides,
  /// destinations, the profile, *and* a GPS fix followed by a call to a
  /// third-party reverse-geocode API. Nothing painted until the slowest of
  /// those finished, and on a cold start with location enabled that is seconds.
  /// It is the single biggest contributor to "the app is not responsive".
  ///
  /// Now the rides request alone gates the first paint. Everything else lands
  /// when it lands, and location — by far the slowest — never blocks anything.
  Future<void> _fetchRides() async {
    setState(() => _isLoading = true);

    // Kick all of these off together; await them separately.
    final ridesFuture = _apiService.client.get('/rides').catchError(
        (_) => Response(requestOptions: RequestOptions(path: ''), data: []));
    final destinationsFuture = _apiService.getDestinations().catchError(
        (_) => Response(requestOptions: RequestOptions(path: ''), data: []));
    final profileFuture = _apiService.getProfile().catchError(
        (_) => Response(requestOptions: RequestOptions(path: ''), data: {}));

    // ── First paint: rides only ──────────────────────────────────────────
    try {
      final ridesRes = await ridesFuture;
      if (!mounted) return;
      setState(() {
        _rides = _parseList(ridesRes.data);
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }

    // ── Everything below refines a screen that is already on-screen ──────
    unawaited(destinationsFuture.then((res) {
      if (mounted) setState(() => _destinations = _parseList(res.data));
    }).catchError((_) {}));

    unawaited(profileFuture.then((res) {
      if (!mounted) return;
      final profile = res.data is Map ? res.data as Map : <String, dynamic>{};
      setState(() {
        _userName = _getName(profile).split(' ').first;
        _userId = profile['id']?.toString();
      });
    }).catchError((_) {}));

    unawaited(_applyNearbySort());
    unawaited(_fetchUnreadCount());
  }

  /// Resolves the current city and re-orders rides to put local ones first.
  ///
  /// Deliberately fire-and-forget: it costs a GPS fix plus a network round trip
  /// to bigdatacloud.net, and a list that reorders a moment after it appears is
  /// far better than a blank screen while we wait for a location the person may
  /// never have granted.
  Future<void> _applyNearbySort() async {
    final city = await _getUserCity();
    if (!mounted || city == null || city.isEmpty || _rides.isEmpty) return;

    final needle = city.toLowerCase();
    bool isLocal(dynamic r) =>
        r['origin']?.toString().toLowerCase().contains(needle) ?? false;

    final sorted = List<dynamic>.from(_rides)
      ..sort((a, b) => (isLocal(a) ? 0 : 1).compareTo(isLocal(b) ? 0 : 1));

    setState(() => _rides = sorted);

    NotificationService().startNearbyRideCheck(city);

    final nearby = sorted.where(isLocal).length;
    if (nearby > 0 && mounted) {
      NotificationService.showInAppNotification(
        context,
        'Rides near you!',
        '$nearby ride${nearby > 1 ? 's' : ''} available from $city',
      );
    }
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final res    = await _apiService.client.get('/notifications');
      final notifs = (res.data is List) ? res.data as List : <dynamic>[];
      final unread = notifs.where((n) => n['isRead'] != true).length;
      if (mounted) setState(() => _unreadCount = unread);
    } catch (_) {}
  }

  Future<String?> _getUserCity() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) return null;
      final pos    = await Geolocator.getCurrentPosition();
      final webRes = await Dio().get(
          'https://api.bigdatacloud.net/data/reverse-geocode-client'
          '?latitude=${pos.latitude}&longitude=${pos.longitude}&localityLanguage=en');
      return webRes.data['city'] ?? webRes.data['locality'];
    } catch (_) { return null; }
  }

  List<dynamic> _parseList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map) {
      for (final k in ['data', 'rides', 'items', 'results']) {
        if (raw[k] is List) return raw[k] as List;
      }
    }
    return [];
  }

  String _getName(dynamic u) {
    if (u == null) return 'Traveler';
    final n = '${u['name'] ?? u['fullName'] ?? ''}'.trim();
    if (n.isNotEmpty && n != 'null') return n;
    final first = u['firstName']?.toString() ?? '';
    final last  = u['lastName']?.toString()  ?? '';
    if (first.isNotEmpty) return '$first $last'.trim();
    return u['email']?.toString().split('@').first ?? 'Traveler';
  }

  List<dynamic> get _filteredRides {
    switch (_filter) {
      case 'My Rides':
        return _rides.where((r) =>
          r['driverId']?.toString() == _userId ||
          (r['driver'] is Map && r['driver']['id']?.toString() == _userId)).toList();
      case 'Ongoing':
        return _rides.where((r) {
          final s = (r['status'] ?? '').toString().toLowerCase();
          return s == 'ongoing' || s == 'in_progress' || s == 'started';
        }).toList();
      default: return _rides;
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchRides,
                color: _orange,
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 120),
                  children: [
                    _buildSearchBar(),
                    _buildFilterPills(),
                    _buildNearbyRidesSection(),
                    _buildTrendingSection(),
                    _buildFeaturedPlacesSection(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          _iconBtn(Icons.menu_rounded, _showQuickMenu),
          const Spacer(),
          RichText(
            text: TextSpan(children: [
              TextSpan(text: 'Fle', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: _textDark)),
              TextSpan(text: 'ttra', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: _orange)),
            ]),
          ),
          const Spacer(),
          Stack(
            children: [
              _iconBtn(Icons.notifications_none_rounded, () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                _fetchUnreadCount();
              }, color: Colors.grey[600]),
              if (_unreadCount > 0)
                Positioned(
                  right: 0, top: 0,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
        ),
        child: Icon(icon, color: color ?? _textDark, size: 20),
      ),
    );
  }

  // ─── Hero text ──────────────────────────────────────────────────────────────

  Widget _buildHeroText() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w700, color: _textDark, height: 1.2),
          children: const [
            TextSpan(text: 'Your next '),
            TextSpan(text: 'journey', style: TextStyle(color: _orange, fontStyle: FontStyle.italic)),
            TextSpan(text: ' starts here.'),
          ],
        ),
      ),
    );
  }

  // ─── Search bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => showSearch(context: context, delegate: RideSearchDelegate(_rides)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: Colors.grey[500], size: 19),
                    const SizedBox(width: 10),
                    Text('Where are we heading?',
                        style: GoogleFonts.dmSans(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              // Filter sheet — coming soon
            },
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.tune_rounded, color: Colors.grey[600], size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Filter pills (removed — replaced by filter icon in search bar) ──────────

  Widget _buildFilterPills() => const SizedBox.shrink();

  // ─── Section label ───────────────────────────────────────────────────────────

  Widget _buildSectionLabel() {
    final count = _filteredRides.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Row(
        children: [
          Text(
            _filter == 'All' ? 'Rides for you' : _filter,
            style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark, letterSpacing: -0.2),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: Colors.black.withOpacity(0.05))),
          const SizedBox(width: 8),
          if (!_isLoading)
            Text('$count rides',
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.grey[400])),
        ],
      ),
    );
  }

  // ─── Empty state ─────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: _orange.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.directions_car_rounded, color: _orange, size: 32),
          ),
          const SizedBox(height: 14),
          Text('No rides found', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: _textDark)),
          const SizedBox(height: 5),
          Text('Try a different filter or check back later',
            style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey[400])),
        ],
      ),
    );
  }

  // ─── Ride card ──────────────────────────────────────────────────────────────

  Widget _buildRideCard(dynamic r) {
    final isRejected = (r['adminStatus']?.toString() ?? 'active') == 'rejected';
    final rejectionReason = r['adminRejectionReason']?.toString() ?? '';

    final name       = r['name']?.toString() ?? r['title']?.toString() ?? 'Ride';
    final origin     = r['origin']?.toString() ?? '';
    final dest       = r['destination']?.toString() ?? '';
    final price      = r['pricePerSeat'] ?? 0;
    final cover      = ApiService.getFullImageUrl(r['coverImage'] ?? r['imageUrl'] ?? '');
    final mode       = (r['transportMode'] ?? 'car').toString().toLowerCase();
    final catLabel   = _categoryLabel(mode, name);
    final dateStr    = _shortDate(r['departureDate']);
    final rating     = (r['rating'] ?? 4.8).toStringAsFixed(1);
    final driver     = _extractDriver(r);
    final driverName = _driverFirstName(driver);

    return Opacity(
      opacity: isRejected ? 0.55 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRejected)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDED),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Row(children: [
                const Icon(Icons.block_rounded, size: 13, color: Color(0xFFE53935)),
                const SizedBox(width: 6),
                const Text('Removed by admin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFE53935))),
                if (rejectionReason.isNotEmpty) ...[
                  const Text('  ·  ', style: TextStyle(color: Color(0xFFE57373))),
                  Expanded(child: Text(rejectionReason, style: const TextStyle(fontSize: 11, color: Color(0xFFE57373)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ]),
            ),
          _PressableCard(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => RideDetailsScreen(rideId: r['id'].toString()))),
      child: Container(
        margin: EdgeInsets.fromLTRB(20, isRejected ? 0 : 10, 20, 0),
        height: 110,
        decoration: BoxDecoration(
          color: isRejected ? const Color(0xFFF9F9F9) : Colors.white,
          borderRadius: isRejected
              ? const BorderRadius.vertical(bottom: Radius.circular(20))
              : BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            // Left: square image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
              child: Stack(
                children: [
                  SafeNetworkImage(url: cover, width: 110, height: 110, fit: BoxFit.cover),
                  // Category pill overlay
                  Positioned(
                    bottom: 8, left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(10)),
                      child: Text(catLabel, style: GoogleFonts.dmSans(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.1)),
                    ),
                  ),
                ],
              ),
            ),
            // Right: text content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(name,
                      style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: _textDark, height: 1.1),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    // Route
                    Text(
                      origin.isNotEmpty && dest.isNotEmpty ? '$origin → $dest' : origin.isNotEmpty ? origin : dest,
                      style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w400),
                      overflow: TextOverflow.ellipsis),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(dateStr, style: GoogleFonts.dmSans(fontSize: 9, color: Colors.grey[400], fontWeight: FontWeight.w600)),
                    ],
                    const Spacer(),
                    // Budget + driver + chevron
                    Row(
                      children: [
                        Text(price != null && price != 0 ? '~₹$price' : 'Budget TBD', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: price != null && price != 0 ? _orange : Colors.grey)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            driverName.isNotEmpty ? '· $driverName' : '',
                            style: GoogleFonts.dmSans(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFFCCCCCC)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
          ),
        ],
      ),
    );
  }

  // ─── Featured destination card ────────────────────────────────────────────────

  Widget _buildFeaturedCard() {
    final dest  = _destinations.first;
    final name  = dest['name']?.toString() ?? 'Featured Journey';
    final desc  = dest['description']?.toString() ?? 'Premium travel experience for the modern explorer.';
    final image = ApiService.getFullImageUrl(dest['imageUrl'] ?? dest['coverImage'] ?? '');

    return _PressableCard(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Featured', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _orange, letterSpacing: 0.0)),
                  const SizedBox(height: 4),
                  Text(name, style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: _textDark, letterSpacing: -0.3, height: 1.15)),
                  const SizedBox(height: 6),
                  Text(desc, style: GoogleFonts.dmSans(fontSize: 11, color: Colors.grey[500], height: 1.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Row(children: [
                    Text('Explore now', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: _textDark)),
                    const SizedBox(width: 5),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: _orange),
                  ]),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
              child: SafeNetworkImage(url: image, height: 130, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Nearby Rides section ────────────────────────────────────────────────────

  Widget _buildNearbyRidesSection() {
    const maxShown = 3;
    final rides = _filteredRides;
    final shown = rides.take(maxShown).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Nearby Rides',
          count: rides.length,
          onSeeAll: rides.isNotEmpty
              ? () => context.switchToTab(2)
              : null,
        ),
        if (_isLoading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: _PulseLoader())
        else if (rides.isEmpty)
          _buildEmpty()
        else ...[
          ...shown.map((r) => _buildRideCard(r)),
          if (rides.length > maxShown)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: GestureDetector(
                onTap: () => context.switchToTab(2),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: _orange.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _orange.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Show all ${rides.length} rides',
                          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: _orange)),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 14, color: _orange),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  // ─── Trending section ─────────────────────────────────────────────────────────

  Widget _buildTrendingSection() {
    if (_isLoading || _rides.isEmpty) return const SizedBox.shrink();
    // "Trending" = rides with soonest departure or most passengers
    final trending = List<dynamic>.from(_rides)
      ..sort((a, b) {
        final aP = (a['passengers'] as List?)?.length ?? 0;
        final bP = (b['passengers'] as List?)?.length ?? 0;
        return bP.compareTo(aP);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Trending Rides'),
        SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(left: 20, right: 8),
            itemCount: trending.length,
            itemBuilder: (context, i) => _buildTrendingCard(trending[i]),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildTrendingCard(dynamic r) {
    final screenW   = MediaQuery.of(context).size.width;
    final cardW     = (screenW - 20) / 2.4;
    final name      = r['name']?.toString() ?? r['destination']?.toString() ?? 'Ride';
    final dest      = r['destination']?.toString() ?? '';
    final origin    = r['origin']?.toString() ?? '';
    final price     = r['pricePerSeat'] ?? 0;
    final cover     = ApiService.getFullImageUrl(r['coverImage'] ?? r['imageUrl'] ?? '');
    final seats     = r['seatsAvailable'] ?? 0;
    final dateStr   = _shortDate(r['departureDate']);

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => RideDetailsScreen(rideId: r['id'].toString()))),
      child: Container(
        width: cardW,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Stack(
                children: [
                  SafeNetworkImage(url: cover, height: 110, width: double.infinity, fit: BoxFit.cover),
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.event_seat_rounded, size: 10, color: Colors.white),
                        const SizedBox(width: 3),
                        Text('$seats', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                      ]),
                    ),
                  ),
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.45), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: _textDark, height: 1.2),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  if (origin.isNotEmpty && dest.isNotEmpty)
                    Text('$origin → $dest',
                      style: GoogleFonts.dmSans(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (dateStr.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(dateStr, style: GoogleFonts.dmSans(fontSize: 9, color: Colors.grey[400], fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 6),
                  Text(price != null && price != 0 ? '~₹$price' : 'Budget TBD', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: price != null && price != 0 ? _orange : Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Featured Places section ──────────────────────────────────────────────────

  static const List<Map<String, String>> _featuredPlaces = [
    {'name': 'Spiti Valley',   'tag': 'Himachal Pradesh', 'image': 'https://images.unsplash.com/photo-1581793745862-99fde7fa73d2?q=80&w=800&auto=format&fit=crop'},
    {'name': 'Ladakh',         'tag': 'Jammu & Kashmir',  'image': 'https://images.unsplash.com/photo-1583141138031-6ec630489cf2?q=80&w=800&auto=format&fit=crop'},
    {'name': 'Goa',            'tag': 'Coastal Paradise', 'image': 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?q=80&w=800&auto=format&fit=crop'},
    {'name': 'Kerala',         'tag': 'God\'s Own Country','image': 'https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?q=80&w=800&auto=format&fit=crop'},
    {'name': 'Rajasthan',      'tag': 'Land of Kings',    'image': 'https://images.unsplash.com/photo-1590050752117-238cb0fb12b1?q=80&w=800&auto=format&fit=crop'},
    {'name': 'Manali',         'tag': 'Himachal Pradesh', 'image': 'https://images.unsplash.com/photo-1626621341517-bbf3d9990a23?q=80&w=800&auto=format&fit=crop'},
    {'name': 'Coorg',          'tag': 'Karnataka',        'image': 'https://images.unsplash.com/photo-1596178060810-72f53ce9a65c?q=80&w=800&auto=format&fit=crop'},
  ];

  Widget _buildFeaturedPlacesSection() {
    // Merge API destinations with hardcoded fallback
    final apiPlaces = _destinations.map((d) => {
      'name':  d['name']?.toString() ?? '',
      'tag':   d['region']?.toString() ?? d['country']?.toString() ?? 'India',
      'image': ApiService.getFullImageUrl(d['imageUrl'] ?? d['coverImage'] ?? ''),
    }).where((p) => p['name']!.isNotEmpty).toList();

    final places = apiPlaces.isNotEmpty ? apiPlaces : _featuredPlaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Featured Places'),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(left: 20, right: 8),
            itemCount: places.length,
            itemBuilder: (context, i) => _buildPlaceCard(places[i]),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPlaceCard(Map<String, String> place) {
    final screenW = MediaQuery.of(context).size.width;
    final cardW   = (screenW - 20) / 2.5;

    return Container(
      width: cardW,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SafeNetworkImage(url: place['image']!, fit: BoxFit.cover),
            // Gradient overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
            // Text
            Positioned(
              left: 10, right: 10, bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(place['name']!,
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.location_on_rounded, size: 9, color: Colors.white70),
                    const SizedBox(width: 2),
                    Expanded(child: Text(place['tag']!,
                      style: GoogleFonts.dmSans(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Section header helper ────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, {int? count, VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Text(title,
            style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: _textDark, letterSpacing: -0.3)),
          if (count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: _orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('$count', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: _orange)),
            ),
          ],
          const Spacer(),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Row(children: [
                Text('See all', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _orange)),
                const SizedBox(width: 3),
                const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: _orange),
              ]),
            ),
        ],
      ),
    );
  }

  // ─── Quick menu ──────────────────────────────────────────────────────────────

  void _showQuickMenu() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFFE8551A), Color(0xFFFF8C5A)]),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'T',
                      style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                    )),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_userName, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('Flettra Explorer', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey[400])),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              ...[
                _menuItem(Icons.home_rounded,           'Home',          () => Navigator.pop(context)),
                _menuItem(Icons.directions_car_rounded, 'My Rides',      () => Navigator.pop(context)),
                _menuItem(Icons.groups_rounded,         'Groups',        () => Navigator.pop(context)),
                _menuItem(Icons.notifications_rounded,  'Notifications', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                }),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: _orange.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: _orange, size: 18),
      ),
      title: Text(label, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: _textDark)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey[300]),
      onTap: onTap,
    );
  }

  Widget _joinBtn(String rideId, {bool compact = false}) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => RideDetailsScreen(rideId: rideId))),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 6 : 9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFE8551A), Color(0xFFFF8C5A)]),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          compact ? 'Join →' : 'Request to Join',
          style: GoogleFonts.dmSans(
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  dynamic _extractDriver(dynamic r) {
    return (r['driver'] is Map ? r['driver'] : null)
        ?? (r['creator'] is Map ? r['creator'] : null)
        ?? (r['user'] is Map ? r['user'] : null)
        ?? (r['organizer'] is Map ? r['organizer'] : null);
  }

  String _categoryLabel(String mode, String name) {
    if (mode == 'bike') return 'BIKE TRIP';
    if (mode == 'bus') return 'GROUP BUS';
    if (name.toLowerCase().contains('beach')) return 'BEACH';
    if (name.toLowerCase().contains('mountain') || name.toLowerCase().contains('alpine')) return 'NATURE';
    if (name.toLowerCase().contains('city') || name.toLowerCase().contains('urban')) return 'CITY';
    return 'ADVENTURE';
  }

  String _shortDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt     = DateTime.parse(raw.toString()).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return ''; }
  }

  String _driverFirstName(dynamic driver) {
    if (driver == null) return '';
    final first = driver['firstName']?.toString().trim() ?? '';
    if (first.isNotEmpty) return first;
    final full = (driver['name'] ?? driver['fullName'])?.toString().trim() ?? '';
    if (full.isNotEmpty) return full.split(' ').first;
    final email = driver['email']?.toString().trim() ?? '';
    if (email.contains('@')) return email.split('@').first;
    return '';
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// Search delegate
// ─────────────────────────────────────────────────────────────────────────────

class RideSearchDelegate extends SearchDelegate {
  final List<dynamic> rides;
  RideSearchDelegate(this.rides);

  @override String get searchFieldLabel => 'Search by origin, destination...';

  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context).copyWith(
    appBarTheme: const AppBarTheme(backgroundColor: Colors.white, elevation: 0, iconTheme: IconThemeData(color: Colors.black87)),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: GoogleFonts.dmSans(color: Colors.grey[400], fontSize: 15),
      border: InputBorder.none,
    ),
  );

  @override List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () { query = ''; showSuggestions(context); }),
  ];

  @override Widget? buildLeading(BuildContext context) =>
    IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => close(context, null));

  @override Widget buildResults(BuildContext context) => _buildList(context);
  @override Widget buildSuggestions(BuildContext context) => _buildList(context);

  List<dynamic> _filtered() {
    if (query.isEmpty) return rides;
    final q = query.toLowerCase();
    return rides.where((r) =>
      (r['origin'] ?? '').toString().toLowerCase().contains(q) ||
      (r['destination'] ?? '').toString().toLowerCase().contains(q) ||
      (r['name'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  Widget _buildList(BuildContext context) {
    final results = _filtered();
    if (query.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.search_rounded, size: 48, color: Colors.grey[300]),
      const SizedBox(height: 12),
      Text('Search rides', style: GoogleFonts.dmSans(color: Colors.grey[400], fontWeight: FontWeight.w600)),
    ]));
    if (results.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
      const SizedBox(height: 12),
      Text('No rides for "$query"', style: GoogleFonts.dmSans(color: Colors.grey[400], fontWeight: FontWeight.w600)),
    ]));
    return ListView.builder(
      itemCount: results.length,
      padding: const EdgeInsets.all(20),
      itemBuilder: (context, i) {
        final r = results[i];
        return GestureDetector(
          onTap: () { close(context, null); Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailsScreen(rideId: r['id']))); },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFF3EE), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.directions_car_rounded, color: Color(0xFFFF6B2C), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r['origin']} → ${r['destination']}',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 3),
                Text('${r['departureDate'] ?? ''} • ${r['seatsAvailable'] ?? 0} seats',
                  style: GoogleFonts.dmSans(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
              ])),
              Text('₹${r['pricePerSeat'] ?? '0'}',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: const Color(0xFFFF6B2C), fontSize: 15)),
            ]),
          ),
        );
      },
    );
  }
}
