import 'package:flutter/material.dart';
import '../theme/flettra_colors.dart';
import '../theme/app_typography.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/network_image_widget.dart';
import 'ride_details_screen.dart';

class AllRidesScreen extends StatefulWidget {
  const AllRidesScreen({super.key});

  @override
  State<AllRidesScreen> createState() => _AllRidesScreenState();
}

class _AllRidesScreenState extends State<AllRidesScreen> {
  final ApiService  _apiService  = ApiService();
  final AuthService _authService = AuthService();

  List<dynamic> _allRides = [];
  List<dynamic> _myRides  = [];
  bool   _isLoading      = true;
  String _selectedFilter = 'ALL';
  String _searchQuery    = '';
  String? _myUserId;

  final TextEditingController _searchController = TextEditingController();

  static const Color _orange    = Color(0xFFFF6B2C);
  static const Color _orangeEnd = Color(0xFFFF8C5A);
  static const Color _dark      = Color(0xFF1A0A08);
  static const Color _bg        = Colors.white;

  static const List<String> _filters = ['ALL', 'MY RIDES', 'ONGOING', 'HISTORY'];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);

    // Fetch each source independently so a failure in one (e.g. /rides/my-rides)
    // doesn't wipe out the others — previously a single throw left every list empty.
    final results = await Future.wait([
      _authService.getUser().then<dynamic>((u) => u).catchError((_) => null),
      _apiService.client.get('/rides').then<dynamic>((r) => r.data).catchError((_) => null),
      _apiService.getMyRides().then<dynamic>((r) => r.data).catchError((_) => null),
    ]);

    if (!mounted) return;
    final user = results[0];
    setState(() {
      if (user is Map) _myUserId = user['id']?.toString();
      if (results[1] != null) _allRides = _parseList(results[1]);
      if (results[2] != null) _myRides  = _parseList(results[2]);
      _isLoading = false;
    });
  }

  List<dynamic> _parseList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map) {
      for (final key in ['data', 'rides', 'items', 'results']) {
        if (raw[key] is List) return raw[key] as List<dynamic>;
      }
    }
    return [];
  }

  List<dynamic> get _filteredRides {
    List<dynamic> base;
    switch (_selectedFilter) {
      case 'MY RIDES':
        base = _myRides;
        break;
      case 'ONGOING':
        base = _myRides.where((r) {
          final dep = DateTime.tryParse(r['departureDate'] ?? '');
          if (dep == null) return false;
          return dep.isAfter(DateTime.now().subtract(const Duration(hours: 12)));
        }).toList();
        break;
      case 'HISTORY':
        base = _myRides.where((r) {
          final dep = DateTime.tryParse(r['departureDate'] ?? '');
          if (dep == null) return false;
          return dep.isBefore(DateTime.now());
        }).toList();
        break;
      default:
        base = _allRides;
    }

    if (_searchQuery.isEmpty) return base;
    final q = _searchQuery.toLowerCase();
    return base.where((r) =>
      (r['name'] ?? '').toString().toLowerCase().contains(q) ||
      (r['origin'] ?? '').toString().toLowerCase().contains(q) ||
      (r['destination'] ?? '').toString().toLowerCase().contains(q),
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildFilterPills(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: context.c.surfaceRaised,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rides',
            style: AppTypography.dmSans(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: _dark,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Discover and join adventures',
            style: AppTypography.dmSans(fontSize: 13, color: Colors.grey[400], fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─── Search ───────────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      color: context.c.surfaceRaised,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: AppTypography.dmSans(fontSize: 14, color: _dark),
          decoration: InputDecoration(
            hintText: 'Search by name, origin or destination...',
            hintStyle: AppTypography.dmSans(color: Colors.grey[400], fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                    child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  // ─── Filter pills ──────────────────────────────────────────────────────────────

  Widget _buildFilterPills() {
    return Container(
      color: context.c.surfaceRaised,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((filter) {
            final isActive = _selectedFilter == filter;
            return GestureDetector(
              onTap: () => setState(() => _selectedFilter = filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? null
                      : null,
                  color: isActive ? null : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  filter,
                  style: AppTypography.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isActive ? Colors.white : Colors.grey[500],
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── List ─────────────────────────────────────────────────────────────────────

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _orange));
    }

    final rides = _filteredRides;

    if (rides.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _orange.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_bike_rounded, size: 40, color: _orange),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 'ALL' ? 'No rides available' : 'No rides here',
              style: AppTypography.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: _dark),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedFilter == 'ALL' ? 'Check back soon for new adventures' : 'Try a different filter',
              style: AppTypography.dmSans(fontSize: 13, color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      color: _orange,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        physics: const BouncingScrollPhysics(),
        itemCount: rides.length,
        itemBuilder: (context, i) => _buildCard(rides[i]),
      ),
    );
  }

  // ─── Ride card ────────────────────────────────────────────────────────────────

  Widget _buildCard(dynamic r) {
    final name   = r['name'] ?? '${r['origin'] ?? ''} → ${r['destination'] ?? ''}';
    final origin = r['origin'] ?? '';
    final dest   = r['destination'] ?? '';
    final price  = r['pricePerSeat'];
    final seats  = r['seatsAvailable'] ?? 0;
    final cover  = ApiService.getFullImageUrl(r['coverImage'] ?? '');
    final driver = r['creator'] ?? r['driver'] ?? {};
    final driverName = driver is Map
        ? '${driver['firstName'] ?? ''} ${driver['lastName'] ?? ''}'.trim()
        : 'Driver';

    String dateStr = '';
    try {
      final dt = DateTime.parse((r['departureDate'] ?? '').toString()).toLocal();
      dateStr = DateFormat('d MMM, HH:mm').format(dt);
    } catch (_) {}

    final status  = (r['status'] ?? '').toString().toLowerCase();
    final isOwner = r['creatorId']?.toString() == _myUserId;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailsScreen(rideId: r['id']))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: context.c.surfaceRaised,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero image ────────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: SafeNetworkImage(
                    url: cover,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A0A08), Color(0xFF3D1A0E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: const Center(child: Icon(Icons.directions_bike_rounded, size: 48, color: Colors.white24)),
                    ),
                  ),
                ),
                // Gradient overlay
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black54],
                        ),
                      ),
                    ),
                  ),
                ),
                // Status / owner badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Row(
                    children: [
                      if (isOwner)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('MY RIDE', style: AppTypography.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.8)),
                        ),
                      if (status == 'ongoing' || status == 'in_progress') ...[
                        if (isOwner) const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              Text('LIVE', style: AppTypography.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Price badge
                if (price != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '~₹$price',
                        style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                // Route name on image
                Positioned(
                  bottom: 12,
                  left: 14,
                  right: 14,
                  child: Text(
                    name,
                    style: AppTypography.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, shadows: [const Shadow(color: Colors.black45, blurRadius: 8)]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // ── Info row ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Origin → Destination
                  if (origin.isNotEmpty)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(color: _orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.near_me_rounded, size: 13, color: _orange),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$origin → $dest',
                            style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: _dark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  // Bottom row: date + seats + driver
                  Row(
                    children: [
                      // Date
                      Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 5),
                      Text(dateStr, style: AppTypography.dmSans(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      // Seats
                      Icon(Icons.event_seat_rounded, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text('$seats seats', style: AppTypography.dmSans(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                      const Spacer(),
                      // Book button
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isOwner ? 'View' : 'Book Spot',
                          style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  if (driverName.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 22, height: 22,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              driverName.isNotEmpty ? driverName[0].toUpperCase() : 'D',
                              style: AppTypography.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'by $driverName',
                          style: AppTypography.dmSans(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
