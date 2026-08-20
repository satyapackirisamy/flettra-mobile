import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../theme/app_spacing.dart';
import '../theme/grouped.dart';
import '../theme/app_typography.dart';
import '../theme/flettra_colors.dart';
import '../services/notification_service.dart';
import '../widgets/network_image_widget.dart';
import 'ride_details_screen.dart';
import 'notifications_screen.dart';
import 'all_rides_screen.dart';

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
                  gradient: LinearGradient(
                    colors: [context.c.brand, context.c.brand],
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
                style: AppTypography.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.c.brand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  // Canvas comes from the theme now (surfaceSunken), not a white literal.

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
      color: context.c.surfaceSunken,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchRides,
                color: context.c.brand,
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

  /// A large title, the way both platforms head a root screen — rather than a
  /// centred wordmark. The wordmark belongs on the launch screen; repeating it
  /// above every scroll costs a row of height and tells the person nothing they
  /// did not already know.
  Widget _buildTopBar() {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.xs, AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text('Rides',
                style: AppTypography.display.copyWith(color: c.ink)),
          ),
          _iconBtn(Icons.menu_rounded, _showQuickMenu, tooltip: 'Menu'),
          Stack(
            alignment: Alignment.topRight,
            children: [
              _iconBtn(
                Icons.notifications_none_rounded,
                () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen()));
                  _fetchUnreadCount();
                },
                tooltip: 'Notifications',
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
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
        ],
      ),
    );
  }

  /// 44 pt of hit area. The previous version was 9 pt of padding around a 20 pt
  /// icon — a 38 pt target, under both platform minimums, which is why some of
  /// these read as "the button doesn't work".
  Widget _iconBtn(IconData icon, VoidCallback onTap, {String? tooltip}) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      iconSize: 22,
      color: context.c.ink,
      constraints: const BoxConstraints(
        minWidth: AppTouch.iosMin,
        minHeight: AppTouch.iosMin,
      ),
      icon: Icon(icon),
    );
  }

  // ─── Search bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
      child: GestureDetector(
        onTap: () => showSearch(
            context: context, delegate: RideSearchDelegate(_rides)),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: c.surfaceSunken,
            borderRadius: AppRadius.chipR,
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: c.ink3, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text('Where are you headed?',
                  style: AppTypography.body.copyWith(color: c.ink3)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Filter chips ────────────────────────────────────────────────────────────

  /// Replaces the filter icon that shipped wired to nothing — its source
  /// carried the comment "Filter sheet — coming soon". Chips show the active
  /// state and the result count inline, so you can see what a filter did
  /// without opening anything.
  Widget _buildFilterPills() {
    final c = context.c;
    final counts = <String, int>{
      'All': _rides.length,
      'My Rides': _countFor('My Rides'),
      'Ongoing': _countFor('Ongoing'),
    };

    return SizedBox(
      height: 30 + AppSpacing.sm + AppSpacing.xxs,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxs),
        physics: const BouncingScrollPhysics(),
        children: [
          for (final entry in counts.entries) ...[
            _filterChip(entry.key, entry.value, c),
            const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }

  int _countFor(String filter) {
    final previous = _filter;
    _filter = filter;
    final n = _filteredRides.length;
    _filter = previous;
    return n;
  }

  Widget _filterChip(String label, int count, FlettraColors c) {
    final selected = _filter == label;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _filter = label);
      },
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? c.brand : c.surface,
          borderRadius: AppRadius.pillR,
          border: Border.all(color: selected ? c.brand : c.rule),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppTypography.callout.copyWith(
                  color: selected ? c.onBrand : c.ink2,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                )),
            if (count > 0) ...[
              const SizedBox(width: AppSpacing.xxs + 1),
              Text('$count',
                  style: AppTypography.callout.copyWith(
                    color: (selected ? c.onBrand : c.ink3)
                        .withValues(alpha: selected ? 0.7 : 1),
                  )),
            ],
          ],
        ),
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
            decoration: BoxDecoration(color: context.c.brand.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(Icons.directions_car_rounded, color: context.c.brand, size: 32),
          ),
          const SizedBox(height: 14),
          Text('No rides found', style: AppTypography.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: context.c.ink)),
          const SizedBox(height: 5),
          Text('Try a different filter or check back later',
            style: AppTypography.dmSans(fontSize: 12, color: context.c.ink3)),
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
    final driver     = _extractDriver(r);
    final driverName = _driverFirstName(driver);

    final c = context.c;

    return Opacity(
      opacity: isRejected ? 0.55 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRejected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs,
                  AppSpacing.md, AppSpacing.xxs),
              color: c.badWash,
              child: Row(children: [
                Icon(Icons.block_rounded, size: 13, color: c.bad),
                const SizedBox(width: AppSpacing.xxs + 2),
                Text('Removed by admin',
                    style: AppTypography.caption.copyWith(color: c.bad)),
                if (rejectionReason.isNotEmpty) ...[
                  Text('  ·  ', style: TextStyle(color: c.bad)),
                  Expanded(
                    child: Text(rejectionReason,
                        style: AppTypography.caption
                            .copyWith(color: c.bad, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ]),
            ),

          // A list row, not a floating card. 110 pt of height with a 110 pt
          // image and a 20 pt margin fit two and a half rides on a phone, while
          // the text inside ran at 9-12 pt. This is ~76 pt, and the type inside
          // it went up rather than down.
          _PressableCard(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        RideDetailsScreen(rideId: r['id'].toString()))),
            child: Container(
              color: isRejected ? c.surfaceSunken : c.surfaceRaised,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.cardR,
                    child: Stack(
                      children: [
                        SafeNetworkImage(
                            url: cover, width: 52, height: 52, fit: BoxFit.cover),
                        if (catLabel.isNotEmpty)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              color: c.brand,
                              padding: const EdgeInsets.symmetric(vertical: 1),
                              child: Text(
                                catLabel,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: AppTypography.caption.copyWith(
                                    color: c.onBrand, fontSize: 8, height: 1.3),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm - 1),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(name,
                            style: AppTypography.bodyStrong.copyWith(color: c.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 1),
                        Text(
                          origin.isNotEmpty && dest.isNotEmpty
                              ? '$origin → $dest'
                              : origin.isNotEmpty
                                  ? origin
                                  : dest,
                          style: AppTypography.callout.copyWith(color: c.ink2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (dateStr.isNotEmpty)
                              Text(dateStr,
                                  style: AppTypography.footnote
                                      .copyWith(color: c.ink3)),
                            if (dateStr.isNotEmpty && driverName.isNotEmpty)
                              Text('  ·  ',
                                  style: AppTypography.footnote
                                      .copyWith(color: c.ink3)),
                            if (driverName.isNotEmpty)
                              Flexible(
                                child: Text(driverName,
                                    style: AppTypography.footnote
                                        .copyWith(color: c.ink3),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        price != null && price != 0
                            ? '₹${_money(price)}'
                            : 'TBD',
                        style: AppTypography.bodyStrong.copyWith(
                            color: price != null && price != 0
                                ? c.ink
                                : c.ink3),
                      ),
                      Text('per seat',
                          style:
                              AppTypography.footnote.copyWith(color: c.ink3)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Trims the trailing ".00" the API sends on whole-rupee amounts, and groups
  /// thousands. "~₹30000.00" is four characters of noise on a 52 pt row.
  static String _money(dynamic raw) {
    final value = double.tryParse(raw.toString()) ?? 0;
    final whole = value.truncate();
    final digits = whole.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
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
              ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllRidesScreen()))
              : null,
        ),
        if (_isLoading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: _PulseLoader())
        else if (rides.isEmpty)
          _buildEmpty()
        else ...[
          GroupedCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1,
                        thickness: 1,
                        color: context.c.ruleSoft,
                        indent: AppSpacing.md + 52 + AppSpacing.sm),
                  _buildRideCard(shown[i]),
                ],
              ],
            ),
          ),
          if (rides.length > maxShown)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllRidesScreen())),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: context.c.brand.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.c.brand.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Show all ${rides.length} rides',
                          style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: context.c.brand)),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: context.c.brand),
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
          color: context.c.surfaceRaised,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.c.ruleSoft),
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
                        Text('$seats', style: AppTypography.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
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
                    style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: context.c.ink, height: 1.2),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  if (origin.isNotEmpty && dest.isNotEmpty)
                    Text('$origin → $dest',
                      style: AppTypography.dmSans(fontSize: 10, color: context.c.ink2, fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (dateStr.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(dateStr, style: AppTypography.dmSans(fontSize: 9, color: context.c.ink3, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 6),
                  Text(price != null && price != 0 ? '~₹$price' : 'Budget TBD', style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: price != null && price != 0 ? context.c.brand : context.c.ink3)),
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
                    style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.location_on_rounded, size: 9, color: Colors.white70),
                    const SizedBox(width: 2),
                    Expanded(child: Text(place['tag']!,
                      style: AppTypography.dmSans(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.w500),
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
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.xxs, AppSpacing.xs - 1),
      child: Row(
        children: [
          Text(title, style: AppTypography.title.copyWith(color: c.ink)),
          if (count != null) ...[
            const SizedBox(width: AppSpacing.xs - 2),
            Text('$count', style: AppTypography.title.copyWith(color: c.ink3)),
          ],
          const Spacer(),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: c.brand,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                textStyle: AppTypography.callout,
              ),
              child: const Text('See all'),
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
        decoration: BoxDecoration(color: context.c.surfaceRaised, borderRadius: BorderRadius.circular(28)),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 38, height: 4, decoration: BoxDecoration(color: context.c.ink3, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: context.c.brand,
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'T',
                      style: AppTypography.dmSans(color: context.c.onBrand, fontWeight: FontWeight.w700, fontSize: 18),
                    )),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_userName, style: AppTypography.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: context.c.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('Flettra Explorer', style: AppTypography.dmSans(fontSize: 12, color: context.c.ink3)),
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
        decoration: BoxDecoration(color: context.c.brand.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: context.c.brand, size: 18),
      ),
      title: Text(label, style: AppTypography.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: context.c.ink)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: context.c.ink3),
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
                      color: context.c.brand,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          compact ? 'Join →' : 'Request to Join',
          style: AppTypography.dmSans(
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w800,
            color: context.c.surfaceRaised,
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
    appBarTheme: AppBarTheme(backgroundColor: context.c.surface, elevation: 0, iconTheme: IconThemeData(color: Colors.black87)),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: AppTypography.dmSans(color: context.c.ink3, fontSize: 15),
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
      Icon(Icons.search_rounded, size: 48, color: context.c.ink3),
      const SizedBox(height: 12),
      Text('Search rides', style: AppTypography.dmSans(color: context.c.ink3, fontWeight: FontWeight.w600)),
    ]));
    if (results.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.search_off_rounded, size: 48, color: context.c.ink3),
      const SizedBox(height: 12),
      Text('No rides for "$query"', style: AppTypography.dmSans(color: context.c.ink3, fontWeight: FontWeight.w600)),
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
            decoration: BoxDecoration(color: context.c.surfaceSunken, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: context.c.brandWash, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.directions_car_rounded, color: context.c.brand, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r['origin']} → ${r['destination']}',
                  style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 3),
                Text('${r['departureDate'] ?? ''} • ${r['seatsAvailable'] ?? 0} seats',
                  style: AppTypography.dmSans(color: context.c.ink2, fontSize: 12, fontWeight: FontWeight.w600)),
              ])),
              Text('₹${r['pricePerSeat'] ?? '0'}',
                style: AppTypography.dmSans(fontWeight: FontWeight.w800, color: context.c.brand, fontSize: 15)),
            ]),
          ),
        );
      },
    );
  }
}
