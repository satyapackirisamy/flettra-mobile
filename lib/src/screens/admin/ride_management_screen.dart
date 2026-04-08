import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class AdminRideManagementScreen extends StatefulWidget {
  const AdminRideManagementScreen({super.key});

  @override
  State<AdminRideManagementScreen> createState() => _AdminRideManagementScreenState();
}

class _AdminRideManagementScreenState extends State<AdminRideManagementScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _rides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  Future<void> _loadRides() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getAdminRides();
      setState(() {
        _rides = response.data['rides'];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load rides: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRide(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel & Delete Ride'),
        content: const Text('Are you sure you want to remove this ride? This action cannot be undone and will notify all participants.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteAdminRide(id);
        _loadRides();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete ride: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Manage Rides'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRides,
              child: _rides.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No active rides found',
                            style: GoogleFonts.plusJakartaSans(fontSize: 18, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rides.length,
                      itemBuilder: (context, index) {
                        final ride = _rides[index];
                        return _buildRideCard(ride);
                      },
                    ),
            ),
    );
  }

  Widget _buildRideCard(dynamic ride) {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${ride['origin']} → ${ride['destination']}',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                    ),
                    _buildStatusBadge(ride['status']),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoColumn('Driver', ride['driver']?['name'] ?? 'Unknown'),
                    _buildInfoColumn('Passengers', '${ride['passengers']?.length} / ${ride['seatsAvailable']}'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoColumn('Departure', ride['departureTime']?.toString().substring(0, 10) ?? 'No date'), // Quick formatting
                    _buildInfoColumn('Price/Seat', '₹${ride['pricePerSeat']}'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // View Details Logic
                        },
                        child: const Text('VIEW DETAILS'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      onPressed: () => _deleteRide(ride['id']),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color badgeColor;
    switch (status) {
      case 'ongoing': badgeColor = Colors.blue; break;
      case 'completed': badgeColor = const Color(0xFF10B981); break;
      case 'cancelled': badgeColor = Colors.red; break;
      case 'paused': badgeColor = Colors.amber; break;
      default: badgeColor = const Color(0xFF4F46E5); break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withOpacity(0.5)),
      ),
      child: Text(
        status?.toUpperCase() ?? 'SCHEDULED',
        style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
