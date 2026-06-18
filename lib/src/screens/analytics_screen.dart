import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/network_image_widget.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _stats;
  List<dynamic> _leaderboard = [];
  bool _loading = true;
  late TabController _tabController;
  String _leaderboardScope = 'WEEKLY';

  static const Color _orange = Color(0xFFFF6B2C);
  static const Color _bg = Colors.white;
  static const Color _dark = Color(0xFF1A0A08);

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
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _orange),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Analytics',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: _dark, fontSize: 18),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: TabBar(
              controller: _tabController,
              labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[500],
              indicator: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(11)),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [Tab(text: 'My Stats'), Tab(text: 'Leaderboard')],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : TabBarView(
              controller: _tabController,
              children: [_buildStats(), _buildLeaderboard()],
            ),
    );
  }

  // ─── My Stats Tab ────────────────────────────────────────────────────────────

  Widget _buildStats() {
    if (_stats == null) {
      return Center(
        child: Text('No data available', style: GoogleFonts.dmSans(color: Colors.grey[400])),
      );
    }

    final totalRides    = _stats!['totalRides'] ?? 0;
    final completedRides = _stats!['completedRides'] ?? 0;
    final ridesAsDriver  = _stats!['ridesAsDriver'] ?? 0;
    final distanceKm    = _stats!['totalDistanceKm'] ?? 0;
    final compassPts    = _stats!['compassPoints'] ?? 0;
    final moneySaved    = _stats!['moneySaved'] ?? 0;
    final avgRating     = double.tryParse('${_stats!['averageRating'] ?? 0}') ?? 0;
    final totalRatings  = _stats!['totalRatings'] ?? 0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          Text(
            'PERSONAL DASHBOARD',
            style: GoogleFonts.dmSans(
              fontSize: 11, fontWeight: FontWeight.w800,
              color: _orange, letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'My Stats',
            style: GoogleFonts.dmSans(
              fontSize: 26, fontWeight: FontWeight.w700, color: _dark,
            ),
          ),
          const SizedBox(height: 20),

          // Primary stat cards
          Row(
            children: [
              Expanded(
                child: _bigStatCard(
                  label: 'Total Rides',
                  value: '$totalRides',
                  sub: '$completedRides completed',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A0A08), Color(0xFFFF6B2C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  textColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _bigStatCard(
                  label: 'Distance',
                  value: '${distanceKm}km',
                  sub: 'total covered',
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B2C), Color(0xFFFF8C5A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  textColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Compass points full-width
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: _orange.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 6))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('COMPASS POINTS', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: _orange, letterSpacing: 1.0)),
                      const SizedBox(height: 6),
                      Text('$compassPts', style: GoogleFonts.dmSans(fontSize: 36, fontWeight: FontWeight.w700, color: _dark, height: 1.0)),
                      Text('Keep riding to earn more!', style: GoogleFonts.dmSans(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _orange.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.explore_rounded, color: _orange, size: 32),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 30-Day Activity bar chart
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('30-Day Activity', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 15, color: _dark)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8)),
                      child: Text('Rides', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: _orange)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ActivityBarChart(totalRides: totalRides, completedRides: completedRides),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Secondary stats grid
          Text('Breakdown', style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w800, color: _dark)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _miniStatCard('As Driver', '$ridesAsDriver', Icons.drive_eta_rounded, const Color(0xFF8B5CF6)),
              _miniStatCard('Money Saved', '₹$moneySaved', Icons.savings_rounded, const Color(0xFF059669)),
              _miniStatCard('Avg Rating', avgRating.toStringAsFixed(1), Icons.star_rounded, const Color(0xFFF59E0B)),
              _miniStatCard('Reviews', '$totalRatings', Icons.reviews_rounded, const Color(0xFF3B82F6)),
            ],
          ),

          const SizedBox(height: 24),

          // Travel achievements
          Text('Travel Achievements', style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w800, color: _dark)),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _achievementBadge('First Ride', Icons.flight_takeoff_rounded, totalRides >= 1),
                _achievementBadge('Road Warrior', Icons.route_rounded, totalRides >= 5),
                _achievementBadge('100km Club', Icons.straighten_rounded, (distanceKm is num && distanceKm >= 100)),
                _achievementBadge('Top Rated', Icons.star_rounded, avgRating >= 4.5),
                _achievementBadge('Driver', Icons.drive_eta_rounded, ridesAsDriver >= 1),
              ],
            ),
          ),

          // Top Routes
          if ((_stats!['topRoutes'] as List?)?.isNotEmpty == true) ...[
            const SizedBox(height: 24),
            Text('Top Routes', style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w800, color: _dark)),
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
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: i == 0 ? _orange : _orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text('#${i + 1}', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: i == 0 ? Colors.white : _orange, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(route['route'], style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 14, color: _dark))),
                    Text('${route['trips']} trips', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: _orange, fontSize: 12)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _bigStatCard({
    required String label,
    required String value,
    required String sub,
    required Gradient gradient,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: textColor.withOpacity(0.7))),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w700, color: textColor, height: 1.0)),
          const SizedBox(height: 2),
          Text(sub, style: GoogleFonts.dmSans(fontSize: 10, color: textColor.withOpacity(0.6), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _miniStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: color, height: 1.0)),
          Text(label, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: color.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _achievementBadge(String title, IconData icon, bool earned) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: earned ? _orange.withOpacity(0.10) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: earned ? _orange.withOpacity(0.3) : Colors.transparent),
      ),
      child: Column(
        children: [
          Icon(icon, color: earned ? _orange : Colors.grey[300], size: 28),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: earned ? _dark : Colors.grey[400]),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── Leaderboard Tab ─────────────────────────────────────────────────────────

  Widget _buildLeaderboard() {
    if (_leaderboard.isEmpty) {
      return Center(child: Text('No data available', style: GoogleFonts.dmSans(color: Colors.grey[400])));
    }

    final top3 = _leaderboard.take(3).toList();
    final rest = _leaderboard.skip(3).toList();

    // Find current user's rank
    final myStats   = _stats;
    final myPoints  = myStats?['compassPoints'] ?? 0;
    final myRankIdx = _leaderboard.indexWhere((u) => u['compassPoints'] == myPoints);
    final myRank    = myRankIdx >= 0 ? myRankIdx + 1 : null;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + scope chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Leaderboard', style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w700, color: _dark)),
              Row(
                children: ['WEEKLY', 'GLOBAL'].map((s) {
                  final active = _leaderboardScope == s;
                  return GestureDetector(
                    onTap: () => setState(() => _leaderboardScope = s),
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? _orange : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? _orange : Colors.grey[200]!),
                      ),
                      child: Text(s, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w800, color: active ? Colors.white : Colors.grey[500])),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Podium top-3
          if (top3.isNotEmpty) _buildPodium(top3),

          const SizedBox(height: 20),

          // My rank + points cards
          if (myRank != null) ...[
            Row(
              children: [
                Expanded(
                  child: _rankInfoCard(
                    label: 'YOUR RANK',
                    value: '#$myRank',
                    icon: Icons.emoji_events_rounded,
                    color: _orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _rankInfoCard(
                    label: 'COMPASS POINTS',
                    value: '$myPoints',
                    icon: Icons.explore_rounded,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // Rank 4+ list
          if (rest.isNotEmpty) ...[
            Text('All Riders', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: _dark)),
            const SizedBox(height: 10),
            ...rest.asMap().entries.map((entry) {
              final user = entry.value;
              final rank = user['rank'] ?? (entry.key + 4);
              return _leaderboardRow(user, rank, false);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildPodium(List<dynamic> top3) {
    // Podium order: 2nd (left), 1st (center/taller), 3rd (right)
    final order = [
      if (top3.length > 1) top3[1],  // 2nd
      top3[0],                         // 1st
      if (top3.length > 2) top3[2],  // 3rd
    ];
    final ranks = top3.length > 1 ? [2, 1, 3] : [1];
    final heights = top3.length > 1 ? [90.0, 120.0, 70.0] : [120.0];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFFFE8E0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Avatars row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: order.asMap().entries.map((entry) {
              final i = entry.key;
              final user = entry.value;
              final rank = ranks[i];
              final isFirst = rank == 1;
              final name = (user['name'] ?? 'User').toString();
              final pts = user['compassPoints'] ?? 0;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isFirst)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFBBF24), size: 24),
                    ),
                  Stack(
                    children: [
                      Container(
                        width: isFirst ? 72 : 58,
                        height: isFirst ? 72 : 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: rank == 1
                                ? [const Color(0xFFFFBB00), const Color(0xFFFF6B2C)]
                                : rank == 2
                                    ? [const Color(0xFF94A3B8), const Color(0xFF64748B)]
                                    : [const Color(0xFFCD7C3A), const Color(0xFF92400E)],
                          ),
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: WebCircleAvatar(
                          radius: isFirst ? 36 : 29,
                          url: ApiService.getAvatarUrl(user['profilePicture'], name: name),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: rank == 1
                                ? const Color(0xFFFBBF24)
                                : rank == 2
                                    ? const Color(0xFFD1D5DB)
                                    : const Color(0xFFF97316),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Center(
                            child: Text('$rank', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 72,
                    child: Text(
                      name.split(' ')[0],
                      style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: _dark),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$pts pts',
                    style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: _orange),
                  ),
                ],
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Pedestal bars
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: order.asMap().entries.map((entry) {
              final rank = ranks[entry.key];
              final h    = heights[entry.key];
              return Container(
                width: 76,
                height: h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: rank == 1
                        ? [const Color(0xFFFFBB00), const Color(0xFFFF8800)]
                        : rank == 2
                            ? [const Color(0xFFB0BAC9), const Color(0xFF8E9BAB)]
                            : [const Color(0xFFD49B6A), const Color(0xFFA0673A)],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Center(
                  child: Text(
                    '${rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉'}',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _rankInfoCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 0.8)),
                Text(value, style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: _dark, height: 1.1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaderboardRow(dynamic user, int rank, bool isTop3) {
    final name = (user['name'] ?? 'User').toString();
    final pts  = user['compassPoints'] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: _orange.withOpacity(0.10), shape: BoxShape.circle),
            child: Center(child: Text('$rank', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: _orange, fontSize: 13))),
          ),
          const SizedBox(width: 12),
          WebCircleAvatar(radius: 18, url: ApiService.getAvatarUrl(user['profilePicture'], name: name)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 14, color: _dark)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _orange.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
            child: Text('$pts pts', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: _orange, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ─── Activity Bar Chart ───────────────────────────────────────────────────────

class _ActivityBarChart extends StatelessWidget {
  final int totalRides;
  final int completedRides;

  const _ActivityBarChart({required this.totalRides, required this.completedRides});

  @override
  Widget build(BuildContext context) {
    // Generate mock 30-day bars from the totalRides value
    final maxVal = (totalRides / 4).ceil().clamp(1, 100);
    final bars = List.generate(30, (i) {
      // Distribute rides pseudo-randomly across 30 days using ride count
      final seed = ((i * 7 + totalRides * 3) % maxVal).toDouble();
      return seed / maxVal;
    });

    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: bars.asMap().entries.map((e) {
          final frac = e.value;
          final isWeekend = e.key % 7 == 5 || e.key % 7 == 6;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: frac > 0.5
                    ? const Color(0xFFFF6B2C)
                    : isWeekend
                        ? const Color(0xFFFFB399)
                        : const Color(0xFFFFD5C8),
                borderRadius: BorderRadius.circular(4),
              ),
              height: (frac * 60).clamp(4, 60),
            ),
          );
        }).toList(),
      ),
    );
  }
}
