import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/network_image_widget.dart';
import 'ride_details_screen.dart';

class AllRidesScreen extends StatefulWidget {
  const AllRidesScreen({super.key});

  @override
  State<AllRidesScreen> createState() => _AllRidesScreenState();
}

class _AllRidesScreenState extends State<AllRidesScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _allRides = [];
  List<dynamic> _myRides = [];
  bool _isLoading = true;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  static const Color primaryOrange = Color(0xFFFF5500);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetch();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final resAll = await _apiService.client.get('/rides');
      final resMy = await _apiService.getMyRides();
      if (mounted) setState(() { _allRides = resAll.data; _myRides = resMy.data ?? []; _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  List<dynamic> _filter(List<dynamic> list) {
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((r) => (r['name'] ?? '').toString().toLowerCase().contains(q) || (r['origin'] ?? '').toString().toLowerCase().contains(q) || (r['destination'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF9FAFB),
      child: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildSearchBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildList(_filter(_allRides)),
                  _buildList(_filter(_myRides)),
                  _buildList(_filter(_myRides.where((r) => DateTime.tryParse(r['departureDate'] ?? '')?.isAfter(DateTime.now().subtract(const Duration(hours: 12))) ?? false).toList())),
                  _buildList(_filter(_myRides.where((r) => DateTime.tryParse(r['departureDate'] ?? '')?.isBefore(DateTime.now()) ?? false).toList())),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rides', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -1)),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: primaryOrange,
            unselectedLabelColor: Colors.grey[400],
            indicatorColor: primaryOrange,
            indicatorWeight: 4,
            dividerColor: Colors.transparent,
            labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [Tab(text: 'ALL'), Tab(text: 'MY RIDES'), Tab(text: 'ONGOING'), Tab(text: 'HISTORY')],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey[100]!))),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)), child: TextField(controller: _searchController, onChanged: (v) => setState(() => _searchQuery = v), decoration: InputDecoration(hintText: 'Search destinations...', prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey), border: InputBorder.none))),
    );
  }

  Widget _buildList(List<dynamic> rides) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: primaryOrange));
    if (rides.isEmpty) return const Center(child: Text('No rides found'));
    return RefreshIndicator(onRefresh: _fetch, color: primaryOrange, child: ListView.builder(padding: const EdgeInsets.all(20), itemCount: rides.length, itemBuilder: (context, i) => _buildCard(rides[i])));
  }

  Widget _buildCard(dynamic r) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailsScreen(rideId: r['id']))),
      child: Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]), child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(16), child: SafeNetworkImage(url: ApiService.getFullImageUrl(r['coverImage']), width: 60, height: 60, fit: BoxFit.cover)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r['name'] ?? 'Route', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1),
          Text('${r['origin']} to ${r['destination']}', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 8),
          Text('₹${r['pricePerSeat']}', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w900, color: primaryOrange)),
        ])),
      ])),
    );
  }
}
