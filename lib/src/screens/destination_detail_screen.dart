import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/network_image_widget.dart';
import 'create_ride_screen.dart';

class DestinationDetailScreen extends StatefulWidget {
  final String destinationId;
  const DestinationDetailScreen({super.key, required this.destinationId});

  @override
  State<DestinationDetailScreen> createState() => _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _destination;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final response = await _apiService.getDestinationDetails(widget.destinationId);
      setState(() {
        _destination = response.data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to load destination details: $e'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_destination == null) {
      return const Scaffold(body: Center(child: Text('Destination not found')));
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. Header Image
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                backgroundColor: Colors.white,
                leading: CircleAvatar(
                  backgroundColor: Colors.black26,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: SafeNetworkImage(
                    url: _destination!['imageUrl'] ?? 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?q=80&w=2021&auto=format&fit=crop',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _destination!['name'],
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.star_rounded, color: Colors.orange, size: 20),
                                SizedBox(width: 4),
                                Text('4.8', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Colors.grey, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            _destination!['location'] ?? 'India',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'About Destination',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _destination!['description'] ?? 'No description available for this destination.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 120), // Bottom padding for FAB
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // 2. Floating Action Button
          Positioned(
            bottom: 30,
            left: 24,
            right: 24,
            child: SizedBox(
              height: 64,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreateRideScreen(
                        initialDestination: _destination!['name'],
                        initialImage: _destination!['imageUrl'],
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5500),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'START JOURNEY TO ${_destination!['name'].toString().toUpperCase()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
