import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../widgets/network_image_widget.dart';
import 'onboarding_screen.dart';
import 'analytics_screen.dart';
import 'all_rides_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    final u = await _authService.getUser();
    if (mounted) setState(() { _user = u; _isLoading = false; });
    _apiService.getMyAnalytics().then((res) {
      if (mounted) setState(() => _stats = res.data);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            children: [
              const SizedBox(height: 32),
              _buildProfileHeader(),
              const SizedBox(height: 48),
              _buildStats(),
              const SizedBox(height: 48),
              _buildListTile(Icons.analytics_rounded, 'My Analytics', 'Stats, leaderboard & insights', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
              }),
              _buildListTile(Icons.history_rounded, 'Trip History', 'View your past trips', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AllRidesScreen()));
              }),
              _buildListTile(Icons.loyalty_rounded, 'Rewards', 'Check your points', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
              }),
              _buildListTile(Icons.settings_suggest_rounded, 'Preferences', 'Customize settings', () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preferences coming soon. Stay tuned!')));
              }),
              _buildListTile(Icons.help_outline_rounded, 'Support', 'Get help', () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support center coming soon. Email us at help@travelconnect.app')));
              }),
              const SizedBox(height: 32),
              _buildLogout(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        CircleAvatar(
          radius: 56, 
          backgroundImage: networkImageProvider(ApiService.getAvatarUrl(_user?['profilePicture'], name: '${_user?['firstName'] ?? 'U'}')),
          child: Align(
            alignment: Alignment.bottomRight, 
            child: CircleAvatar(
              radius: 18, 
              backgroundColor: const Color(0xFFFF5500), 
              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16)
            )
          )
        ),
        const SizedBox(height: 20),
        Text('${_user?['firstName'] ?? 'User'} ${_user?['lastName'] ?? ''}', style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1)),
        Text(_user?['email'] ?? '', style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStat('${_stats?['totalRides'] ?? 0}', 'Trips'),
        _buildStat('${_stats?['compassPoints'] ?? 0}', 'Points'),
        _buildStat('${_stats?['totalRatings'] ?? 0}', 'Reviews'),
      ],
    );
  }

  Widget _buildStat(String val, String label) {
    return Column(children: [Text(val, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900)), Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.bold))]);
  }

  Widget _buildListTile(IconData icon, String title, String sub, VoidCallback onTap) {
    return ListTile(onTap: onTap, leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: Colors.black54, size: 24)), title: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)), subtitle: Text(sub, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey[400])), trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey));
  }

  Widget _buildLogout() {
    return TextButton.icon(
      onPressed: () async {
        await _authService.logout();
        if (mounted) {
          // Navigate to root to force AuthCheck to rebuild or just show onboarding
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
            (route) => false,
          );
        }
      },
      icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 18),
      label: Text('Logout', style: GoogleFonts.plusJakartaSans(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14))
    );
  }
}
