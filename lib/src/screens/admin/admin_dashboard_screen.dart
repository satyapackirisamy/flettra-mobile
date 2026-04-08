import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';
import 'vendor_management_screen.dart';
import 'ride_management_screen.dart';
import 'user_management_screen.dart';
import 'destination_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final response = await _apiService.getAdminStats();
      setState(() {
        _stats = response.data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load stats: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Admin Console'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await _authService.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Platform Overview',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Real-time metrics for Flettra',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Stats Grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.1,
                      children: [
                        _buildStatCard(
                          'Users',
                          _stats?['users']?.toString() ?? '0',
                          Icons.people_alt_rounded,
                          const Color(0xFF4F46E5),
                        ),
                        _buildStatCard(
                          'Vendors',
                          _stats?['vendors']?.toString() ?? '0',
                          Icons.storefront_rounded,
                          const Color(0xFF10B981),
                        ),
                        _buildStatCard(
                          'Rides',
                          _stats?['rides']?.toString() ?? '0',
                          Icons.directions_car_rounded,
                          const Color(0xFFF59E0B),
                        ),
                        _buildStatCard(
                          'Revenue',
                          '₹${_stats?['revenue'] ?? '0'}',
                          Icons.account_balance_wallet_rounded,
                          const Color(0xFFEC4899),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                    Text(
                      'Management Modules',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    _buildModuleTile(
                      'Vendor Management',
                      'Approve and manage travel partners',
                      Icons.business_rounded,
                      const Color(0xFF10B981),
                      () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminVendorManagementScreen()));
                      },
                    ),
                    _buildModuleTile(
                      'Rider Management',
                      'Monitor active rides and participants',
                      Icons.emoji_people_rounded,
                      const Color(0xFFF59E0B),
                      () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminRideManagementScreen()));
                      },
                    ),
                    _buildModuleTile(
                      'User Management',
                      'Platform users and subscriptions',
                      Icons.person_search_rounded,
                      const Color(0xFF4F46E5),
                      () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUserManagementScreen()));
                      },
                    ),
                    _buildModuleTile(
                      'Destinations & Analytics',
                      'Global travel hotspots and trends',
                      Icons.map_rounded,
                      const Color(0xFF8B5CF6),
                      () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDestinationManagementScreen()));
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModuleTile(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
      ),
    );
  }
}
