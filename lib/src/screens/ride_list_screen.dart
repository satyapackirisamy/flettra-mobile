import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/network_image_widget.dart';
import 'ride_details_screen.dart';
import 'main_screen.dart';
import 'notifications_screen.dart';

class RideListScreen extends StatefulWidget {
  const RideListScreen({super.key});

  @override
  State<RideListScreen> createState() => RideListScreenState();
}

class RideListScreenState extends State<RideListScreen> {
  /// Call this from outside (e.g. MainScreen) to reload rides.
  void refresh() => _fetchRides();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  
  List<dynamic> _rides = [];
  List<dynamic> _destinations = [];
  Set<String> _buddyIds = {};
  Set<String> _groupIds = {};
  String? _userCity;
  String _userName = 'Explorer';
  bool _isLoading = true;
  String _selectedCategory = 'Adventure';
  int _unreadNotifications = 0;

  static const Color primaryOrange = Color(0xFFFF5500);
  static const Color textDark = Color(0xFF1F2937);

  @override
  void initState() {
    super.initState();
    _fetchRides();
  }

  Future<void> _fetchRides() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.client.get('/rides').catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: [])),
        _apiService.getDestinations().catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: [])),
        _apiService.getBuddies().catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: [])),
        _apiService.getMyGroups().catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: [])),
        _getUserCity(),
        _apiService.getProfile().catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: {})),
      ]);

      if (mounted) {
        final profileRes = results[5] as Response;
        final profile = profileRes.data as Map?;
        
        setState(() {
          _rides = ((results[0] as Response).data as List?) ?? [];
          _destinations = ((results[1] as Response).data as List?) ?? [];
          _buddyIds = ((results[2] as Response).data as List?)?.map((b) => b['id']?.toString() ?? '').toSet() ?? {};
          _groupIds = ((results[3] as Response).data as List?)?.map((g) => g['id']?.toString() ?? '').toSet() ?? {};
          _userCity = results[4] as String?;
          _userName = _getName(profile).split(' ')[0];
          // Sort: nearby rides first
          if (_userCity != null && _userCity!.isNotEmpty) {
            _rides.sort((a, b) {
              final aMatch = (a['origin']?.toString().toLowerCase().contains(_userCity!.toLowerCase()) ?? false) ? 0 : 1;
              final bMatch = (b['origin']?.toString().toLowerCase().contains(_userCity!.toLowerCase()) ?? false) ? 0 : 1;
              return aMatch.compareTo(bMatch);
            });
            // Start nearby ride notifications
            NotificationService().startNearbyRideCheck(_userCity);
            // Show banner if nearby rides exist
            final nearbyCount = _rides.where((r) => r['origin']?.toString().toLowerCase().contains(_userCity!.toLowerCase()) ?? false).length;
            if (nearbyCount > 0 && mounted) {
              Future.microtask(() {
                if (mounted) {
                  NotificationService.showInAppNotification(
                    context,
                    'Rides near you!',
                    '$nearbyCount ride${nearbyCount > 1 ? 's' : ''} available from $_userCity',
                  );
                }
              });
            }
          }
          _isLoading = false;
        });
        // Fetch unread notification count
        _fetchUnreadCount();
      }
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final res = await _apiService.client.get('/notifications');
      final notifs = (res.data as List?) ?? [];
      final unread = notifs.where((n) => n['isRead'] != true).length;
      if (mounted) setState(() => _unreadNotifications = unread);
    } catch (_) {}
  }

  String _getName(dynamic u) {
    if (u == null) return 'Traveler';
    String n = u['name'] ?? u['fullName'] ?? '';
    if (n.isNotEmpty && n != 'null') return n;
    String first = u['firstName'] ?? '';
    String last = u['lastName'] ?? '';
    if (first.isNotEmpty) return '$first $last'.trim();
    return u['email']?.toString().split('@')[0] ?? 'Traveler';
  }

  Future<String?> _getUserCity() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) return null;
      final pos = await Geolocator.getCurrentPosition();
      final webRes = await Dio().get('https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${pos.latitude}&longitude=${pos.longitude}&localityLanguage=en');
      return webRes.data['city'] ?? webRes.data['locality'];
    } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(
              child: _isLoading ? _buildShimmer() : RefreshIndicator(
                onRefresh: _fetchRides,
                color: primaryOrange,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 120),
                  children: [
                    _buildCategories(),
                    const SizedBox(height: 24),
                    _buildNearbySection(),
                    const SizedBox(height: 32),
                    _buildDestinationsHeader(),
                    _buildDestinationsSection(),
                  ],
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
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          CircleAvatar(radius: 22, backgroundImage: networkImageProvider(ApiService.getAvatarUrl(null, name: _userName))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hello, $_userName', style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500)),
            Text("Discover rides", style: GoogleFonts.plusJakartaSans(color: textDark, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ])),
          GestureDetector(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              _fetchUnreadCount(); // Refresh count on return
            },
            child: Stack(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey[50], shape: BoxShape.circle), child: Icon(Icons.notifications_none_rounded, color: Colors.grey[600], size: 20)),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: 0, top: 0,
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
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: () => showSearch(context: context, delegate: RideSearchDelegate(_rides)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
            const SizedBox(width: 10),
            Text('Search trips...', style: GoogleFonts.plusJakartaSans(color: Colors.grey[400], fontSize: 14)),
          ]),
        ),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey[50], shape: BoxShape.circle), child: Icon(icon, color: Colors.grey[600], size: 20)));
  }

  Widget _buildCategories() {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 24),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: ['Adventure', 'Beach', 'Culture', 'City'].map((c) => _buildCatChip(c)).toList(),
      ),
    );
  }

  Widget _buildCatChip(String label) {
    bool active = _selectedCategory == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = label),
      child: Container(margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(color: active ? primaryOrange : Colors.transparent, borderRadius: BorderRadius.circular(30)), child: Text(label, style: GoogleFonts.plusJakartaSans(color: active ? Colors.white : Colors.grey[500], fontWeight: FontWeight.bold, fontSize: 13))),
    );
  }

  Widget _buildNearbySection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Rides Near You', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: textDark)),
            GestureDetector(onTap: () => context.switchToTab(2), child: const Icon(Icons.arrow_forward_rounded, color: primaryOrange, size: 20)),
          ]),
        ),
        const SizedBox(height: 16),
        _rides.isEmpty ? _buildEmptyNote('No rides available yet') : ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: _rides.length,
          itemBuilder: (context, i) => _buildRideCard(_rides[i]),
        ),
      ],
    );
  }

  Widget _buildDestinationsHeader() {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), child: Text('Top Destinations', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: textDark)));
  }

  Widget _buildDestinationsSection() {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 24),
        itemCount: _destinations.length,
        itemBuilder: (context, i) => _buildDestCard(_destinations[i]),
      ),
    );
  }

  Widget _buildRideCard(dynamic r) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailsScreen(rideId: r['id'].toString()))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey[50]!)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 180, width: double.infinity, decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), image: DecorationImage(image: networkImageProvider(ApiService.getFullImageUrl(r['imageUrl'])), fit: BoxFit.cover))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r['title'] ?? 'Ride', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
                  const SizedBox(height: 4),
                  Row(children: [const Icon(Icons.location_on_rounded, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(r['destination'] ?? '', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[500]))]),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: primaryOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Text('Join', style: GoogleFonts.plusJakartaSans(color: primaryOrange, fontSize: 12, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildDestCard(dynamic d) {
    return Container(
      width: 120, margin: const EdgeInsets.only(right: 16),
      child: Column(children: [
        CircleAvatar(radius: 40, backgroundImage: networkImageProvider(ApiService.getFullImageUrl(d['imageUrl'] ?? ''))),
        const SizedBox(height: 8),
        Text(d['name'] ?? 'Spot', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _buildEmptyNote(String msg) {
    return Center(child: Padding(padding: const EdgeInsets.all(40), child: Text(msg, style: GoogleFonts.plusJakartaSans(color: Colors.grey[400], fontSize: 13))));
  }

  Widget _buildShimmer() {
    return const Center(child: CircularProgressIndicator(color: primaryOrange));
  }
}

class RideSearchDelegate extends SearchDelegate {
  final List<dynamic> rides;
  RideSearchDelegate(this.rides);

  @override
  String get searchFieldLabel => 'Search by origin, destination...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(backgroundColor: Colors.white, elevation: 0, iconTheme: IconThemeData(color: Colors.black87)),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey[400], fontSize: 15),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty) IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () { query = ''; showSuggestions(context); }),
  ];

  @override
  Widget? buildLeading(BuildContext context) =>
    IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  List<dynamic> _filtered() {
    if (query.isEmpty) return rides;
    final q = query.toLowerCase();
    return rides.where((r) {
      final origin = (r['origin'] ?? '').toString().toLowerCase();
      final dest = (r['destination'] ?? '').toString().toLowerCase();
      final name = (r['name'] ?? '').toString().toLowerCase();
      return origin.contains(q) || dest.contains(q) || name.contains(q);
    }).toList();
  }

  Widget _buildList(BuildContext context) {
    final results = _filtered();
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Search rides', style: GoogleFonts.plusJakartaSans(color: Colors.grey[400], fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No rides found for "$query"', style: GoogleFonts.plusJakartaSans(color: Colors.grey[400], fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: results.length,
      padding: const EdgeInsets.all(20),
      itemBuilder: (context, i) {
        final r = results[i];
        return GestureDetector(
          onTap: () {
            close(context, null);
            Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailsScreen(rideId: r['id'])));
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.directions_car_rounded, color: Color(0xFFFF5500), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r['origin']} → ${r['destination']}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('${r['departureDate'] ?? ''} • ${r['seatsAvailable'] ?? 0} seats', style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Text('₹${r['pricePerSeat'] ?? '0'}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: const Color(0xFFFF5500), fontSize: 15)),
              ],
            ),
          ),
        );
      },
    );
  }
}
