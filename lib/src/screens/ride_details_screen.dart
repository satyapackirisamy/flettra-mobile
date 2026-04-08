import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/chat_widget.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/network_image_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../utils/snackbar_helper.dart';
import 'edit_ride_screen.dart';
import 'create_ride_screen.dart' show TransportMode;

class RideDetailsScreen extends StatefulWidget {
  final String rideId;

  const RideDetailsScreen({super.key, required this.rideId});

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  
  Map<String, dynamic>? _ride;
  List<dynamic> _requests = [];
  Map<String, dynamic>? _userRequest;
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _isFavorite = false;
  String? _userId;

  String _displayName(Map<String, dynamic>? user, [String fallback = 'User']) {
    if (user == null) return fallback;
    final name = user['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name;
    final first = user['firstName'] as String? ?? '';
    final last = user['lastName'] as String? ?? '';
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    final email = user['email'] as String?;
    if (email != null && email.contains('@')) return email.split('@')[0];
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = await _authService.getUser();
    _userId = user['id'];
    await _fetchRideDetails();
  }

  Future<void> _fetchRideDetails() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getRideDetails(widget.rideId);
      final ride = response.data;
      
      setState(() {
        _ride = ride;
      });

      if (ride['driver']['id'] == _userId) {
        final reqResponse = await _apiService.getRideRequests(widget.rideId);
        setState(() => _requests = reqResponse.data);
      } else {
        try {
          final myReqResponse = await _apiService.getMyRequestForRide(widget.rideId);
          final myReqData = myReqResponse.data;
          setState(() {
            if (myReqData != null && myReqData is Map<String, dynamic> && myReqData.containsKey('id')) {
              _userRequest = myReqData;
            } else if (_userRequest == null) {
              // Keep existing state if we already have a pending request
              _userRequest = null;
            }
          });
        } catch (_) {
          // If the endpoint fails, keep existing state
        }
      }
    } catch (e) {
      debugPrint('Error fetching ride details: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showRegenerateDialog() async {
    final TextEditingController instructionsController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Text('✨ ', style: TextStyle(fontSize: 24)),
            Text('Regenerate Itinerary', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add custom instructions to personalize your AI-generated itinerary',
              style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: instructionsController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Custom Instructions',
                hintText: 'e.g., Prioritize vegetarian cuisine, include rest periods...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.0)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _generateItinerary(instructionsController.text);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF5500),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('GENERATE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.0)),
          ),
        ],
      ),
    );
  }

  Future<void> _generateItinerary([String? customInstructions]) async {
    setState(() => _isGenerating = true);
    try {
      await _apiService.client.post(
        '/itinerary/ride/${widget.rideId}',
        data: {'customInstructions': customInstructions},
      );
      await _fetchRideDetails();
      if (mounted) {
        showSuccess(context, 'AI Itinerary generated!');
      }
    } catch (e) {
      if (mounted) {
        showError(context, 'AI Generation failed: $e');
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _sendJoinRequest() async {
    try {
      final res = await _apiService.requestJoinRide(widget.rideId);
      // Optimistically mark as sent so button updates immediately
      setState(() => _userRequest = (res.data is Map) ? res.data : {'status': 'pending'});
      _fetchRideDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    }
  }

  Future<void> _handleRequest(String requestId, String status) async {
    try {
      await _apiService.handleRideRequest(requestId, status);
      _fetchRideDetails();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action failed: $e')),
      );
    }
  }

  Future<void> _updateRideStatus(String action) async {
    try {
      if (action == 'start') await _apiService.startRide(widget.rideId);
      if (action == 'complete') {
        await _apiService.completeRide(widget.rideId);
        if (mounted) {
           await showDialog(
             context: context,
             builder: (context) => AlertDialog(
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
               title: const Text('Ride Complete! 🏁', style: TextStyle(fontWeight: FontWeight.w900)),
               content: const Text('You and your passengers have earned 100 Compass Points! 🪙', style: TextStyle(fontWeight: FontWeight.bold)),
               actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('GREAT', style: TextStyle(fontWeight: FontWeight.w900)))],
             ),
           );
        }
        // Show rating dialog for driver (if user is passenger) or passengers (if user is driver)
        _fetchRideDetails(); // refresh ride data
      }
      if (action == 'cancel') await _apiService.cancelRide(widget.rideId);
      if (action == 'pause') await _apiService.pauseRide(widget.rideId);
      if (action == 'resume') await _apiService.resumeRide(widget.rideId);
      if (action == 'reset') await _apiService.resetRide(widget.rideId);
      if (action == 'delete') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Delete Ride? 🛑', style: TextStyle(fontWeight: FontWeight.w900)),
            content: const Text('This will permanently delete the ride and notify all passengers.', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w900))),
              TextButton(
                onPressed: () => Navigator.pop(context, true), 
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await _apiService.deleteRide(widget.rideId);
          if (mounted) {
            Navigator.pop(context);
            showSuccess(context, 'Ride deleted');
          }
          return;
        } else {
          return;
        }
      }
      _fetchRideDetails();
    } catch (e) {
       showError(context, 'Failed to $action ride');
    }
  }

  String _getCoverImage(String? coverImage, String destination) {
    if (coverImage != null && coverImage.trim().isNotEmpty) {
      if (coverImage.startsWith('http')) return coverImage;
      // Handle relative paths
      final baseUrl = ApiService.baseUrl;
      return '$baseUrl$coverImage';
    }

    // Destination mapping
    final destinationImages = {
      'Spiti': 'https://images.unsplash.com/photo-1581793745862-99fde7fa73d2?q=80&w=1200&auto=format&fit=crop',
      'Rajasthan': 'https://images.unsplash.com/photo-1590050752117-238cb0fb12b1?q=80&w=1200&auto=format&fit=crop',
      'Ladakh': 'https://images.unsplash.com/photo-1583141138031-6ec630489cf2?q=80&w=1200&auto=format&fit=crop',
      'Manali': 'https://images.unsplash.com/photo-1626621341517-bbf3d9990a23?q=80&w=1200&auto=format&fit=crop',
      'Goa': 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?q=80&w=1200&auto=format&fit=crop',
      'Kerala': 'https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?q=80&w=1200&auto=format&fit=crop',
    };

    final lowerDest = destination.toLowerCase();
    for (var entry in destinationImages.entries) {
      if (lowerDest.contains(entry.key.toLowerCase())) return entry.value;
    }

    return 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?q=80&w=1200&auto=format&fit=crop';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF5500))));
    if (_ride == null) return const Scaffold(body: Center(child: Text('Ride not found')));

    final isDriver = _ride!['driver']['id'] == _userId;
    final passengers = (_ride!['passengers'] as List);
    final isPassenger = passengers.any((p) => p['id'] == _userId);
    final canChat = isDriver || isPassenger;
    final driverName = _displayName(_ride!['driver']);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Hero image with back + share buttons
                SliverAppBar(
                  expandedHeight: 320,
                  pinned: true,
                  backgroundColor: Colors.white,
                  elevation: 0,
                  leading: Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.9),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.black87),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  actions: [
                    if (_ride?['shareToken'] != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: CircleAvatar(
                          backgroundColor: Colors.white.withOpacity(0.9),
                          child: IconButton(
                            icon: const Icon(Icons.share_rounded, size: 18, color: Color(0xFFFF5500)),
                            onPressed: () {
                              final url = '${ApiService.baseUrl}/rides/share/${_ride!['shareToken']}';
                              Clipboard.setData(ClipboardData(text: url));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share link copied!')));
                            },
                          ),
                        ),
                      ),
                    if (isDriver)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: CircleAvatar(
                          backgroundColor: Colors.white.withOpacity(0.9),
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.black87),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            onSelected: (value) async {
                              if (value == 'edit') {
                                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditRideScreen(ride: _ride!)));
                                if (result == true) _fetchRideDetails();
                              } else if (value == 'cancel') {
                                _updateRideStatus('cancel');
                              } else if (value == 'reset') {
                                _updateRideStatus('reset');
                              } else if (value == 'delete') {
                                _updateRideStatus('delete');
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 10), Text('Edit Ride')])),
                              if (_ride!['status'] == 'ongoing' || _ride!['status'] == 'paused')
                                const PopupMenuItem(value: 'reset', child: Row(children: [Icon(Icons.restart_alt_rounded, size: 18), SizedBox(width: 10), Text('Reset Ride')])),
                              if (_ride!['status'] != 'cancelled' && _ride!['status'] != 'completed')
                                const PopupMenuItem(value: 'cancel', child: Row(children: [Icon(Icons.cancel_outlined, size: 18, color: Colors.orange), SizedBox(width: 10), Text('Cancel Ride')])),
                              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red), SizedBox(width: 10), Text('Delete Ride', style: TextStyle(color: Colors.red))])),
                            ],
                          ),
                        ),
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Hero(
                      tag: 'ride-image-${widget.rideId}',
                      child: SafeNetworkImage(
                        url: _getCoverImage(_ride!['coverImage'], _ride!['destination']),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),

                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Destination + Price row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _ride!['destination'] ?? 'Destination',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
                                        child: Text(
                                          (_ride!['transportMode'] ?? 'car').toString().toUpperCase(),
                                          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFFF5500)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFBBF24)),
                                      const SizedBox(width: 2),
                                      Text('4.9', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('₹${_ride!['pricePerSeat']}', style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFFFF5500))),
                                Text('per person', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Creator card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: const Color(0xFFFFE0CC),
                                    child: Text(driverName[0].toUpperCase(), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: const Color(0xFFFF5500))),
                                  ),
                                  Positioned(
                                    bottom: 0, right: 0,
                                    child: Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFF10B981), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('CREATED BY', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 0.5)),
                                    const SizedBox(height: 2),
                                    Text(driverName, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Route info
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            children: [
                              Column(
                                children: [
                                  const Icon(Icons.circle_outlined, size: 12, color: Color(0xFFFF5500)),
                                  Container(width: 1, height: 24, color: Colors.grey[300]),
                                  const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFFF5500)),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_ride!['origin'] ?? '', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14)),
                                    const SizedBox(height: 16),
                                    Text(_ride!['destination'] ?? '', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(_ride!['departureDate'] ?? '', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 16),
                                  Text('${_ride!['seatsAvailable'] ?? 0} seats left', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFFFF5500), fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // All Riders (driver + passengers)
                        Text('Riders (${passengers.length + 1})', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        // Driver first
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFFFE0CC),
                                child: Text(driverName[0].toUpperCase(), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, color: const Color(0xFFFF5500))),
                              ),
                              const SizedBox(width: 12),
                              Text(driverName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(6)),
                                child: Text('Organizer', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFFFF5500))),
                              ),
                            ],
                          ),
                        ),
                        // Passengers
                        ...passengers.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFF1F5F9),
                                child: Text(_displayName(p as Map<String, dynamic>)[0].toUpperCase(), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.grey[600])),
                              ),
                              const SizedBox(width: 12),
                              Text(_displayName(p as Map<String, dynamic>), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14)),
                            ],
                          ),
                        )),
                        const SizedBox(height: 20),

                        // Pending requests (driver only)
                        if (isDriver && _requests.where((r) => r['status'] == 'pending').isNotEmpty) ...[
                          Text('Pending Requests', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          ..._requests.where((r) => r['status'] == 'pending').map((req) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(14)),
                            child: Row(
                              children: [
                                Expanded(child: Text(_displayName(req['user'] as Map<String, dynamic>?), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700))),
                                IconButton(icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28), onPressed: () => _handleRequest(req['id'], 'accepted')),
                                IconButton(icon: const Icon(Icons.cancel_rounded, color: Colors.red, size: 28), onPressed: () => _handleRequest(req['id'], 'rejected')),
                              ],
                            ),
                          )),
                          const SizedBox(height: 20),
                        ],

                        // Quick action cards (navigate to full pages)
                        _navCard(Icons.map_rounded, 'Itinerary', _ride!['itinerary'] != null ? 'AI-generated plan' : 'No itinerary yet', () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => _ItineraryPage(ride: _ride!, rideId: widget.rideId, isDriver: isDriver, onGenerate: _generateItinerary, onRegenerate: _showRegenerateDialog, isGenerating: _isGenerating)));
                        }),
                        const SizedBox(height: 8),
                        _navCard(Icons.chat_bubble_outline_rounded, 'Chat', canChat ? 'Message your group' : 'Join to chat', () {
                          if (canChat) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                              appBar: AppBar(title: Text('Ride Chat', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800))),
                              body: ChatWidget(rideId: widget.rideId, title: 'Chat'),
                            )));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Join this ride to access chat')));
                          }
                        }),
                        const SizedBox(height: 8),
                        _navCard(Icons.receipt_long_rounded, 'Expenses', (isDriver || isPassenger) ? 'Track & split costs' : '₹${_ride!['pricePerSeat']} per person', () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => _ExpensesPage(ride: _ride!, rideId: widget.rideId, canEdit: isDriver || isPassenger)));
                        }),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bottom action bar
          _buildBottomBar(isDriver, isPassenger),
        ],
      ),
    );
  }

  // Cost and Chat are now separate pages — see _CostPage and _ItineraryPage below

  Widget _buildBottomBar(bool isDriver, bool isPassenger) {
    final status = _ride!['status'];

    // Driver controls — single primary action only
    if (isDriver) {
      String? label;
      IconData? icon;
      VoidCallback? onTap;

      if (status == 'scheduled') { label = 'Start Ride'; icon = Icons.play_arrow_rounded; onTap = () => _updateRideStatus('start'); }
      if (status == 'ongoing') { label = 'Complete Ride'; icon = Icons.check_circle_rounded; onTap = () => _updateRideStatus('complete'); }
      if (status == 'paused') { label = 'Resume Ride'; icon = Icons.play_arrow_rounded; onTap = () => _updateRideStatus('resume'); }
      if (status == 'completed') {
        label = 'Rate Riders';
        icon = Icons.star_rounded;
        onTap = () {
          final passengers = (_ride!['passengers'] as List);
          if (passengers.isNotEmpty) {
            final p = passengers.first;
            showDialog(context: context, builder: (_) => RatingDialog(rideId: widget.rideId, rateeId: p['id'], rateeName: _displayName(p as Map<String, dynamic>), rateeRole: 'passenger', onSubmitted: _fetchRideDetails));
          }
        };
      }

      if (label == null) return const SizedBox.shrink();

      return Container(
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 20),
            label: Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5500),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
      );
    }

    // Passenger - rate driver
    if (isPassenger && status == 'completed') {
      return Container(
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
        child: _actionButton('Rate Driver', Icons.star_rounded, const Color(0xFFFBBF24), () {
          showDialog(context: context, builder: (_) => RatingDialog(rideId: widget.rideId, rateeId: _ride!['driver']['id'], rateeName: _displayName(_ride!['driver']), rateeRole: 'driver', onSubmitted: _fetchRideDetails));
        }, dark: true),
      );
    }

    // Non-member - request to join
    if (!isDriver && !isPassenger) {
      return Container(
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _userRequest == null ? () => _showJoinRequestSheet() : null,
            icon: Icon(_userRequest == null ? Icons.arrow_forward_rounded : Icons.check_rounded, size: 20),
            label: Text(_userRequest == null ? 'Request to Join' : 'Request Sent', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5500),
              disabledBackgroundColor: Colors.grey[300],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _showJoinRequestSheet() async {
    await _sendJoinRequest();
    if (!mounted) return;
    final driverName = _displayName(_ride!['driver']);
    final dest = _ride!['destination'] ?? 'this ride';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFFFFF3E0), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 40, color: Color(0xFFFF5500)),
            ),
            const SizedBox(height: 24),
            Text('Join Request Sent!', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey[600], height: 1.5),
                children: [
                  TextSpan(text: 'Your request to join the $dest trip has been sent to '),
                  TextSpan(text: driverName, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87)),
                  const TextSpan(text: '. You will be notified once they approve.'),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5500),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text('Got it, thanks!', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap, {bool dark = false}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: dark ? Colors.black87 : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    );
  }

  Widget _navCard(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: const Color(0xFFFF5500)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _iconAction(IconData icon, Color bg, VoidCallback onTap, {Color? iconColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, size: 20, color: iconColor ?? Colors.grey[700]),
      ),
    );
  }


}

// ─── Separate Full Pages ──────────────────────────────────────────────────────

class _ItineraryPage extends StatefulWidget {
  final Map<String, dynamic> ride;
  final String rideId;
  final bool isDriver;
  final Function([String?]) onGenerate;
  final VoidCallback onRegenerate;
  final bool isGenerating;

  const _ItineraryPage({required this.ride, required this.rideId, required this.isDriver, required this.onGenerate, required this.onRegenerate, required this.isGenerating});

  @override
  State<_ItineraryPage> createState() => _ItineraryPageState();
}

class _ItineraryPageState extends State<_ItineraryPage> {
  bool _isEditing = false;
  late TextEditingController _summaryController;
  Map<String, dynamic>? _editableItinerary;
  String? _statusMessage;
  bool _isSuccess = true;

  @override
  void initState() {
    super.initState();
    _initItinerary();
  }

  void _initItinerary() {
    dynamic itin = widget.ride['itinerary'];
    if (itin is String) itin = null;
    if (itin != null) {
      _editableItinerary = _deepCopy(itin);
    }
    _summaryController = TextEditingController(text: _editableItinerary?['summary'] ?? '');
  }

  Map<String, dynamic> _deepCopy(dynamic src) {
    if (src is Map) {
      return src.map((k, v) => MapEntry(k.toString(), v is Map ? _deepCopy(v) : v is List ? v.map((e) => e is Map ? _deepCopy(e) : e).toList() : v));
    }
    return {};
  }

  void _showStatus(String message, {bool success = true}) {
    setState(() { _statusMessage = message; _isSuccess = success; });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _statusMessage = null);
    });
  }

  Future<void> _saveManualEdits() async {
    if (_editableItinerary == null) return;
    _editableItinerary!['summary'] = _summaryController.text;
    try {
      await ApiService().client.patch('/itinerary/ride/${widget.rideId}', data: _editableItinerary);
      setState(() => _isEditing = false);
      _showStatus('Itinerary saved successfully');
    } catch (e) {
      _showStatus('Failed to save changes', success: false);
    }
  }

  Future<void> _pickDayImage(int dayIndex) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    try {
      final url = await ApiService().uploadImage(image);
      setState(() {
        final days = _editableItinerary!['dailyPlan'] as List;
        if (days[dayIndex] is Map) {
          (days[dayIndex] as Map)['imageUrl'] = url;
        }
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    dynamic itinerary = _editableItinerary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Itinerary', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.isDriver && itinerary != null)
            TextButton(
              onPressed: _isEditing ? _saveManualEdits : () => setState(() => _isEditing = true),
              child: Text(_isEditing ? 'Save' : 'Edit', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: const Color(0xFFFF5500))),
            ),
        ],
      ),
      body: widget.isGenerating
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: Color(0xFFFF5500)),
              SizedBox(height: 16),
              Text('Generating itinerary...', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
            ]))
          : itinerary == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('No Itinerary Yet', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(
                          widget.isDriver ? 'Generate a travel plan using AI' : 'The organizer hasn\'t created an itinerary yet.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontSize: 14),
                        ),
                        if (widget.isDriver) ...[
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => widget.onGenerate(),
                            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                            label: Text('Generate Itinerary', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5500), foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : _buildContent(itinerary),
    );
  }

  Widget _buildContent(dynamic itinerary) {
    final dailyPlan = itinerary['dailyPlan'] as List? ?? [];
    return Column(
      children: [
        // Status banner
        if (_statusMessage != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _isSuccess ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _isSuccess ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                Icon(_isSuccess ? Icons.check_circle_rounded : Icons.error_rounded, size: 18, color: _isSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                const SizedBox(width: 10),
                Expanded(child: Text(_statusMessage!, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: _isSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626)))),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Full Itinerary', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
                    child: Text('AI GENERATED', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey[600], letterSpacing: 0.5)),
                  ),
                ],
              ),
              // Summary — only show in edit mode
              if (_isEditing) ...[
                const SizedBox(height: 16),
                Text('Summary', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey[500])),
                const SizedBox(height: 8),
                TextField(
                  controller: _summaryController,
                  maxLines: null,
                  minLines: 2,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.5),
                  decoration: InputDecoration(
                    hintText: 'Edit summary...',
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Daily plan — editable activities
              ...dailyPlan.asMap().entries.map((entry) {
                final dayIndex = entry.key;
                final day = entry.value;
                final dayImage = day['imageUrl'] as String?;
                final activities = (day['activities'] as List?) ?? [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFFF5500), shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Text('DAY ${day['day']}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: const Color(0xFFFF5500), fontSize: 13, letterSpacing: 0.5)),
                        const Spacer(),
                        if (widget.isDriver && _isEditing)
                          GestureDetector(
                            onTap: () => _pickDayImage(dayIndex),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_photo_alternate_rounded, size: 14, color: Color(0xFFFF5500)),
                                  const SizedBox(width: 4),
                                  Text(dayImage != null ? 'Change' : 'Add Photo', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFFF5500))),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (dayImage != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SafeNetworkImage(url: ApiService.getFullImageUrl(dayImage), height: 160, width: double.infinity, fit: BoxFit.cover),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 16),
                        padding: const EdgeInsets.only(left: 16),
                        decoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFFFFE0CC), width: 2))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...activities.asMap().entries.map((actEntry) {
                              final actIndex = actEntry.key;
                              final act = actEntry.value;
                              if (_isEditing) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(12)),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 70,
                                            child: TextFormField(
                                              initialValue: act['time'] ?? '',
                                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFFF5500)),
                                              decoration: const InputDecoration(hintText: 'Time', isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                                              onChanged: (v) => (activities[actIndex] as Map)['time'] = v,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              initialValue: act['description'] ?? '',
                                              style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.4),
                                              maxLines: null,
                                              decoration: const InputDecoration(hintText: 'Activity description', isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                                              onChanged: (v) => (activities[actIndex] as Map)['description'] = v,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => setState(() => activities.removeAt(actIndex)),
                                            child: Icon(Icons.close_rounded, size: 16, color: Colors.grey[400]),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(act['time'] ?? '', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFFF5500))),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(act['description'] ?? '', style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.4, color: Colors.grey[800]))),
                                  ],
                                ),
                              );
                            }),
                            // Add activity button in edit mode
                            if (_isEditing)
                              GestureDetector(
                                onTap: () => setState(() => activities.add({'time': '', 'description': ''})),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.add_circle_outline_rounded, size: 16, color: Color(0xFFFF5500)),
                                      const SizedBox(width: 8),
                                      Text('Add activity', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFFF5500))),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
              if (widget.isDriver && !_isEditing) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: widget.onRegenerate,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text('Regenerate with AI', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF5500),
                    side: const BorderSide(color: Color(0xFFFF5500)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpensesPage extends StatefulWidget {
  final Map<String, dynamic> ride;
  final String rideId;
  final bool canEdit;
  const _ExpensesPage({required this.ride, required this.rideId, required this.canEdit});

  @override
  State<_ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<_ExpensesPage> {
  final ApiService _api = ApiService();
  List<dynamic> _expenses = [];
  Map<String, dynamic>? _balances;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getExpenses(widget.rideId),
        _api.getBalances(widget.rideId),
      ]);
      if (mounted) {
        setState(() {
          _expenses = (results[0].data as List?) ?? [];
          _balances = results[1].data is Map ? results[1].data : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _personName(dynamic p) {
    if (p == null) return 'Unknown';
    final name = p['name']?.toString() ?? '';
    if (name.isNotEmpty && name != 'null') return name;
    final first = p['firstName']?.toString() ?? '';
    final last = p['lastName']?.toString() ?? '';
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    return p['email']?.toString().split('@')[0] ?? 'Unknown';
  }

  void _addExpense() {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    // Build participant list with proper names
    final List<Map<String, String>> allParticipants = [];
    final driver = widget.ride['driver'];
    if (driver != null) {
      allParticipants.add({'id': driver['id'].toString(), 'name': _personName(driver)});
    }
    for (final p in (widget.ride['passengers'] as List?) ?? []) {
      if (p != null) {
        allParticipants.add({'id': p['id'].toString(), 'name': _personName(p)});
      }
    }

    // Default: current user paid, split among all
    String paidById = allParticipants.isNotEmpty ? allParticipants[0]['id']! : '';
    final Set<String> splitIds = allParticipants.map((p) => p['id']!).toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('Add Expense', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),

                // Description
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(hintText: 'What was it for? (e.g. Fuel, Dinner)', filled: true, fillColor: const Color(0xFFF8F9FA), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 12),

                // Amount
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: 'Amount', prefixText: '₹ ', filled: true, fillColor: const Color(0xFFF8F9FA), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 20),

                // Paid by
                Text('Paid by', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey[700])),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allParticipants.map((p) {
                    final selected = paidById == p['id'];
                    return ChoiceChip(
                      label: Text(p['name']!, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: selected ? Colors.white : const Color(0xFF475569))),
                      selected: selected,
                      onSelected: (_) => setSheetState(() => paidById = p['id']!),
                      selectedColor: const Color(0xFFFF5500),
                      backgroundColor: const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide.none,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Split among
                Text('Split among', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey[700])),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allParticipants.map((p) {
                    final id = p['id']!;
                    final isSelected = splitIds.contains(id);
                    return FilterChip(
                      label: Text(p['name']!, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: isSelected ? Colors.white : const Color(0xFF475569))),
                      selected: isSelected,
                      onSelected: (val) {
                        setSheetState(() {
                          if (val) { splitIds.add(id); } else if (splitIds.length > 1) { splitIds.remove(id); }
                        });
                      },
                      selectedColor: const Color(0xFFFF5500),
                      backgroundColor: const Color(0xFFF1F5F9),
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide.none,
                    );
                  }).toList(),
                ),
                if (splitIds.length < allParticipants.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Splitting among ${splitIds.length} of ${allParticipants.length} riders', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 24),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (descCtrl.text.trim().isEmpty || amountCtrl.text.trim().isEmpty) return;
                      try {
                        final data = <String, dynamic>{
                          'rideId': widget.rideId,
                          'description': descCtrl.text.trim(),
                          'amount': double.parse(amountCtrl.text.trim()),
                        };
                        if (splitIds.length < allParticipants.length) {
                          data['splitAmong'] = splitIds.toList();
                        }
                        await _api.client.post('/expenses', data: data);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadExpenses();
                      } catch (e) {
                        if (ctx.mounted) showError(ctx, 'Failed to add expense');
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5500), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                    child: Text('Add Expense', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _displayName(dynamic user) {
    if (user == null) return 'User';
    final name = user['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name;
    final first = user['firstName'] as String? ?? '';
    final last = user['lastName'] as String? ?? '';
    return '$first $last'.trim().isEmpty ? 'User' : '$first $last'.trim();
  }

  IconData _expenseIcon(String desc) {
    final d = desc.toLowerCase();
    if (d.contains('fuel') || d.contains('petrol') || d.contains('gas') || d.contains('diesel')) return Icons.local_gas_station_rounded;
    if (d.contains('food') || d.contains('dinner') || d.contains('lunch') || d.contains('breakfast') || d.contains('restaurant')) return Icons.restaurant_rounded;
    if (d.contains('hotel') || d.contains('stay') || d.contains('room') || d.contains('airbnb') || d.contains('villa')) return Icons.hotel_rounded;
    if (d.contains('toll') || d.contains('parking')) return Icons.local_parking_rounded;
    if (d.contains('car') || d.contains('rental') || d.contains('cab')) return Icons.directions_car_rounded;
    if (d.contains('ticket') || d.contains('entry')) return Icons.confirmation_number_rounded;
    return Icons.receipt_long_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final total = _balances?['total'] ?? _expenses.fold<double>(0, (s, e) => s + (double.tryParse('${e['amount']}') ?? 0));
    final perPerson = _balances?['perPersonShare'] ?? 0;
    final balancesList = (_balances?['balances'] as List?) ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Trip Expenses', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white, elevation: 0,
      ),
      floatingActionButton: widget.canEdit ? FloatingActionButton(
        onPressed: _addExpense,
        backgroundColor: const Color(0xFFFF5500),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ) : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5500)))
          : RefreshIndicator(
              onRefresh: _loadExpenses,
              color: const Color(0xFFFF5500),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Total card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF5500), Color(0xFFFF7733)]),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Trip Expense', style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('₹${(total is num ? total : double.tryParse('$total') ?? 0).toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 16),
                        Container(height: 1, color: Colors.white24),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('YOUR SHARE', style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                  const SizedBox(height: 4),
                                  Text('₹${(perPerson is num ? perPerson : double.tryParse('$perPerson') ?? 0).toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('EXPENSES', style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                  const SizedBox(height: 4),
                                  Text('${_expenses.length}', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Recent expenses
                  if (_expenses.isNotEmpty) ...[
                    Text('Recent Expenses', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    ..._expenses.map((exp) {
                      final desc = exp['description'] ?? 'Expense';
                      final amount = double.tryParse('${exp['amount']}') ?? 0;
                      final payer = exp['payer'];
                      final payerName = _displayName(payer);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
                              child: Icon(_expenseIcon(desc), color: const Color(0xFFFF5500), size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(desc, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text('Paid by $payerName', style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            Text('₹${amount.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
                          ],
                        ),
                      );
                    }),
                  ] else ...[
                    const SizedBox(height: 40),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('No expenses yet', style: GoogleFonts.plusJakartaSans(color: Colors.grey[400], fontWeight: FontWeight.w600)),
                          if (widget.canEdit)
                            Text('Tap + to add an expense', style: GoogleFonts.plusJakartaSans(color: Colors.grey[400], fontSize: 12)),
                        ],
                      ),
                    ),
                  ],

                  // Balances
                  if (balancesList.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BALANCES', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 0.5)),
                          const SizedBox(height: 16),
                          ...balancesList.map((b) {
                            final balance = (b['balance'] as num?)?.toDouble() ?? 0;
                            final isPositive = balance >= 0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFFFFE0CC),
                                    child: Text((b['userName'] ?? 'U')[0].toUpperCase(), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 11, color: const Color(0xFFFF5500))),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(b['userName'] ?? 'User', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14))),
                                  Text(
                                    '${isPositive ? '+' : ''}₹${balance.toStringAsFixed(0)}',
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: isPositive ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }
}

