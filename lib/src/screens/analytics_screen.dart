import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/network_image_widget.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _stats;
  List<dynamic> _leaderboard = [];
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _api.getMyAnalytics(),
        _api.getLeaderboard(),
      ]);
      setState(() {
        _stats = results[0].data;
        _leaderboard = results[1].data ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFE),
      appBar: AppBar(
        title: Text('Analytics', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
          labelColor: const Color(0xFF4F46E5),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF4F46E5),
          tabs: const [Tab(text: 'My Stats'), Tab(text: 'Leaderboard')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : TabBarView(
              controller: _tabController,
              children: [_buildStats(), _buildLeaderboard()],
            ),
    );
  }

  Widget _buildStats() {
    if (_stats == null) return const Center(child: Text('No data available'));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _statCard('Total Rides', '${_stats!['totalRides']}', Icons.directions_car, const Color(0xFF3B82F6)),
              _statCard('Completed', '${_stats!['completedRides']}', Icons.check_circle, const Color(0xFF10B981)),
              _statCard('As Driver', '${_stats!['ridesAsDriver']}', Icons.sports_motorsports, const Color(0xFF8B5CF6)),
              _statCard('As Passenger', '${_stats!['ridesAsPassenger']}', Icons.airline_seat_recline_normal, const Color(0xFFF59E0B)),
              _statCard('Distance', '${_stats!['totalDistanceKm']} km', Icons.straighten, const Color(0xFFEF4444)),
              _statCard('Saved', '\u20B9${_stats!['moneySaved']}', Icons.savings, const Color(0xFF059669)),
            ],
          ),
          const SizedBox(height: 16),

          // Compass Points Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Compass Points', style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 8),
                Text('${_stats!['compassPoints']}', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 36)),
                Text('Keep riding to earn more!', style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Rating Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFF97316)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Average Rating', style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ...List.generate(5, (i) => Icon(
                      i < (double.tryParse('${_stats!['averageRating']}') ?? 0).round() ? Icons.star : Icons.star_border,
                      color: Colors.white, size: 28,
                    )),
                    const SizedBox(width: 8),
                    Text('${_stats!['averageRating']}', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28)),
                  ],
                ),
                Text('${_stats!['totalRatings']} reviews', style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Top Routes
          if ((_stats!['topRoutes'] as List?)?.isNotEmpty == true) ...[
            Text('Top Routes', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 12),
            ...(_stats!['topRoutes'] as List).asMap().entries.map((entry) {
              final i = entry.key;
              final route = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                      child: Center(child: Text('#${i + 1}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5), fontSize: 13))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(route['route'], style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14))),
                    Text('${route['trips']} trips', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5), fontSize: 13)),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildLeaderboard() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _leaderboard.length,
      itemBuilder: (context, i) {
        final user = _leaderboard[i];
        final rank = user['rank'] ?? i + 1;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: rank <= 3 ? const Color(0xFFFFFBEB) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: rank <= 3 ? const Color(0xFFFDE68A) : Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: rank == 1 ? const Color(0xFFFBBF24) : rank == 2 ? const Color(0xFFD1D5DB) : rank == 3 ? const Color(0xFFF97316) : const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text('$rank', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: rank <= 3 ? Colors.white : Colors.grey, fontSize: 14))),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFEEF2FF),
                backgroundImage: networkImageProvider(ApiService.getAvatarUrl(user['profilePicture'], name: user['name'] ?? 'U')),
                child: null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(user['name'] ?? 'User', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15))),
              Text('${user['compassPoints']} pts', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5), fontSize: 14)),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 22, color: color)),
          Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 11, color: color.withOpacity(0.7))),
        ],
      ),
    );
  }
}
