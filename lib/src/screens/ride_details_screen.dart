import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart' show Options;
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../theme/app_spacing.dart';
import '../theme/flettra_colors.dart';
import '../services/auth_service.dart';
import '../widgets/chat_widget.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/network_image_widget.dart';
import 'package:intl/intl.dart';
import '../utils/snackbar_helper.dart';
import 'edit_ride_screen.dart';
import 'create_ride_screen.dart' show TransportMode;
import 'rider_profile_screen.dart';
import 'group_live_map_screen.dart';
import '../widgets/moderation_sheet.dart';

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
            Flexible(child: Text('Regenerate Itinerary', style: TextStyle(fontWeight: FontWeight.w700))),
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
            child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.0)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _generateItinerary(instructionsController.text);
            },
            style: FilledButton.styleFrom(
              backgroundColor: context.c.brand,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('GENERATE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.0)),
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
        options: Options(receiveTimeout: const Duration(seconds: 90)),
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
             builder: (_) => const _RideCompleteSheet(points: 100),
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
            title: const Text('Delete Ride? 🛑', style: TextStyle(fontWeight: FontWeight.w700)),
            content: const Text('This will permanently delete the ride and notify all passengers.', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w700))),
              TextButton(
                onPressed: () => Navigator.pop(context, true), 
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.w700)),
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

  // ─── Status helpers ───────────────────────────────────────────────────────

  Color get _statusColor {
    switch (_ride!['status']) {
      case 'ongoing': return context.c.ok;
      case 'completed': return const Color(0xFF6366F1);
      case 'cancelled': return Colors.red;
      case 'paused': return const Color(0xFFF59E0B);
      default: return context.c.brand;
    }
  }

  String get _statusLabel {
    final s = (_ride!['status'] ?? 'scheduled').toString();
    return s[0].toUpperCase() + s.substring(1);
  }

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('d MMM yyyy').format(dt);
    } catch (_) { return raw; }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(body: Center(child: CircularProgressIndicator(color: context.c.brand)));
    if (_ride == null) return const Scaffold(body: Center(child: Text('Ride not found')));

    final isDriver   = _ride!['driver']['id'] == _userId;
    final passengers = (_ride!['passengers'] as List);
    final isPassenger = passengers.any((p) => p['id'] == _userId);
    final canChat    = isDriver || isPassenger;
    final driverName = _displayName(_ride!['driver']);
    final driverAvatar = ApiService.getAvatarUrl(_ride!['driver']['profilePicture'], name: driverName);
    final itinerary  = _ride!['itinerary'];
    final dailyPlan  = (itinerary is Map ? itinerary['dailyPlan'] as List? : null) ?? [];
    final description = _ride!['description'] ?? '';
    final hasDescription = description.toString().isNotEmpty;

    final inRide = isDriver || isPassenger;
    final isOngoing = _ride!['status'] == 'ongoing';
    final isRejected = (_ride!['adminStatus']?.toString() ?? 'active') == 'rejected';
    final rejectionReason = _ride!['adminRejectionReason']?.toString() ?? '';

    return Scaffold(
      backgroundColor: context.c.surface,
      floatingActionButton: (inRide && isOngoing)
          ? _LiveMapFab(
              onTap: () {
                final allParticipants = [
                  _ride!['driver'] as Map<String, dynamic>,
                  ...(passengers.cast<Map<String, dynamic>>()),
                ];
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => GroupLiveMapScreen(
                      rideId: widget.rideId,
                      participants: allParticipants,
                      currentUserId: _userId,
                      destinationName: _ride?['destination'] as String?,
                      originName: _ride?['origin'] as String?,
                    ),
                    transitionsBuilder: (_, anim, __, child) => SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                      child: child,
                    ),
                    transitionDuration: const Duration(milliseconds: 380),
                  ),
                );
              },
            )
          : null,
      body: Opacity(
        opacity: isRejected ? 0.75 : 1.0,
        child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── AppBar ──────────────────────────────────────────────────
                SliverAppBar(
                  pinned: true,
                  backgroundColor: context.c.surface,
                  elevation: 0,
                  leading: Padding(
                    padding: const EdgeInsets.all(8),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        decoration: BoxDecoration(color: context.c.brand, shape: BoxShape.circle),
                        child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: context.c.onBrand),
                      ),
                    ),
                  ),
                  title: Text(
                    'Trip Journal',
                    style: AppTypography.dmSans(fontWeight: FontWeight.w700, fontSize: 17, color: context.c.ink),
                  ),
                  centerTitle: true,
                  actions: [
                    if (_ride?['shareToken'] != null)
                      IconButton(
                        icon: Icon(Icons.share_rounded, color: context.c.brand, size: 22),
                        onPressed: () {
                          final url = '${ApiService.baseUrl}/rides/share/${_ride!['shareToken']}';
                          Clipboard.setData(ClipboardData(text: url));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share link copied!')));
                        },
                      ),
                    if (isDriver)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, color: context.c.ink, size: 22),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        onSelected: (value) async {
                          if (value == 'edit') {
                            final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditRideScreen(ride: _ride!)));
                            if (result == true) _fetchRideDetails();
                          } else {
                            _updateRideStatus(value);
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
                    const SizedBox(width: 4),
                  ],
                ),

                // ── Rejection Banner ────────────────────────────────────────
                if (isRejected)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEDED),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE53935).withOpacity(0.35)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.block_rounded, color: Color(0xFFE53935), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Removed by Admin',
                                  style: TextStyle(
                                    color: Color(0xFFE53935),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                if (rejectionReason.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    rejectionReason,
                                    style: const TextStyle(
                                      color: Color(0xFFB71C1C),
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Content ─────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Action chips ─────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                        child: Row(
                          children: [
                            _actionChip(
                              icon: Icons.chat_bubble_rounded,
                              label: 'Chat',
                              enabled: canChat,
                              onTap: canChat
                                  ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                                      appBar: AppBar(title: Text('Ride Chat', style: AppTypography.dmSans(fontWeight: FontWeight.w800)), backgroundColor: context.c.surface, elevation: 0),
                                      body: ChatWidget(rideId: widget.rideId, title: 'Chat'),
                                    )))
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            _actionChip(
                              icon: Icons.receipt_long_rounded,
                              label: 'Expenses',
                              enabled: true,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ExpensesPage(ride: _ride!, rideId: widget.rideId, canEdit: isDriver || isPassenger))),
                            ),
                            const Spacer(),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: _statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                              child: Text(_statusLabel, style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: _statusColor)),
                            ),
                          ],
                        ),
                      ),

                      // ── Hero ─────────────────────────────────────────────
                      // Full-bleed and 200pt, down from a 240pt inset card with
                      // a 24pt radius. Bleeding it to the edges reads larger
                      // while occupying less, and it stops the screen opening
                      // with a band of white on three sides.
                      Hero(
                        tag: 'ride-image-${widget.rideId}',
                        child: SizedBox(
                          height: 200,
                          width: double.infinity,
                          child: SafeNetworkImage(
                            url: _getCoverImage(
                                _ride!['coverImage'], _ride!['destination']),
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      // ── Headline block ───────────────────────────────────
                      // Was a shadowed card floating over the image, then a
                      // second labelled card for the host, then a third for the
                      // description. Three containers, three shadows, ~600pt to
                      // carry five facts. Flat on the surface, hairline
                      // separated, the host and the journey now sit above the
                      // fold instead of below it.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                            AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xs, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: context.c.brandWash,
                                      borderRadius: AppRadius.chipR),
                                  child: Text(
                                    '${_ride!['seatsAvailable'] ?? 0} seats left',
                                    style: AppTypography.caption
                                        .copyWith(color: context.c.brand),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs - 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xs, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: _statusColor.withValues(alpha: 0.12),
                                      borderRadius: AppRadius.chipR),
                                  child: Text(_statusLabel,
                                      style: AppTypography.caption
                                          .copyWith(color: _statusColor)),
                                ),
                                const Spacer(),
                                Text(
                                  '₹${_ride!["pricePerSeat"]}',
                                  style: AppTypography.title
                                      .copyWith(color: context.c.ink),
                                ),
                                const SizedBox(width: 3),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text('/seat',
                                      style: AppTypography.footnote
                                          .copyWith(color: context.c.ink3)),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _ride!['name'] ?? _ride!['destination'] ?? 'Trip',
                              style: AppTypography.display
                                  .copyWith(color: context.c.ink),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              '${_ride!['origin'] ?? ''}  →  ${_ride!['destination'] ?? ''}',
                              style: AppTypography.body
                                  .copyWith(color: context.c.ink2),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${_fmtDate(_ride!['departureDate'])}  ·  ${(_ride!['transportMode'] ?? 'Car').toString().capitalize()}',
                              style: AppTypography.footnote
                                  .copyWith(color: context.c.ink3),
                            ),
                          ],
                        ),
                      ),

                      Divider(height: 1, thickness: 1, color: context.c.ruleSoft),

                      // ── Host ─────────────────────────────────────────────
                      // The "HOSTED BY" overline cost a row plus 12pt of gap to
                      // label a row whose avatar already says what it is.
                      InkWell(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => RiderProfileScreen(
                                    userId: _ride!['driver']['id'],
                                    knownName: driverName))),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs),
                          child: Row(
                            children: [
                              WebCircleAvatar(radius: 19, url: driverAvatar),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(driverName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.bodyStrong
                                                  .copyWith(color: context.c.ink)),
                                        ),
                                        const SizedBox(width: AppSpacing.xxs),
                                        Icon(Icons.verified_rounded,
                                            size: 14, color: context.c.ok),
                                      ],
                                    ),
                                    Text(
                                      'Host  ·  ★ 4.8  ·  ${passengers.length} trips',
                                      style: AppTypography.footnote
                                          .copyWith(color: context.c.ink3),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isDriver)
                                IconButton(
                                  onPressed: () => showModerationSheet(
                                    context,
                                    targetUserId: _ride!['driver']['id'],
                                    targetName: driverName,
                                    onActionDone: _fetchRideDetails,
                                  ),
                                  tooltip: 'More',
                                  iconSize: 18,
                                  color: context.c.ink3,
                                  constraints: const BoxConstraints(
                                      minWidth: AppTouch.iosMin,
                                      minHeight: AppTouch.iosMin),
                                  icon: const Icon(Icons.more_horiz_rounded),
                                ),
                            ],
                          ),
                        ),
                      ),

                      Divider(height: 1, thickness: 1, color: context.c.ruleSoft),

                      // ── The Journey (description) ─────────────────────────
                      if (hasDescription) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                              AppSpacing.sm, AppSpacing.md, AppSpacing.xxs),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('About this trip',
                                  style: AppTypography.heading
                                      .copyWith(color: context.c.ink)),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                description.toString(),
                                style: AppTypography.body
                                    .copyWith(color: context.c.ink2),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ── Joined Travelers ─────────────────────────────────
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Who\'s coming',
                                    style: AppTypography.heading
                                        .copyWith(color: context.c.ink)),
                                const SizedBox(width: AppSpacing.xxs + 2),
                                Text('${passengers.length}',
                                    style: AppTypography.heading
                                        .copyWith(color: context.c.ink3)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (passengers.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                                decoration: BoxDecoration(
                                  color: context.c.surfaceRaised,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: context.c.brandWash, width: 1.5),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(color: context.c.brandWash, shape: BoxShape.circle),
                                      child: Icon(
                                        isDriver ? Icons.people_outline_rounded : Icons.emoji_people_rounded,
                                        color: context.c.brand,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      isDriver ? 'Waiting for travelers' : 'No one yet!',
                                      style: AppTypography.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: context.c.ink),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isDriver
                                          ? 'Share this ride to attract fellow adventurers'
                                          : 'Be the first to join this adventure!',
                                      style: AppTypography.dmSans(fontSize: 12, color: context.c.ink3, fontWeight: FontWeight.w500),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: context.c.surfaceRaised,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        ...passengers.take(6).toList().asMap().entries.map((e) {
                                          final p = e.value as Map<String, dynamic>;
                                          final name = _displayName(p);
                                          final colors = [
                                            context.c.brand, const Color(0xFF6366F1), context.c.ok,
                                            const Color(0xFFF59E0B), const Color(0xFFEC4899), const Color(0xFF3B82F6),
                                          ];
                                          return Align(
                                            widthFactor: 0.7,
                                            child: Container(
                                              width: 44, height: 44,
                                              decoration: BoxDecoration(
                                                color: colors[e.key % colors.length],
                                                shape: BoxShape.circle,
                                                border: Border.all(color: context.c.surfaceRaised, width: 2.5),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                                  style: AppTypography.dmSans(fontWeight: FontWeight.w700, fontSize: 15, color: context.c.surfaceRaised),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                        if (passengers.length > 6)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 6),
                                            child: Container(
                                              width: 44, height: 44,
                                              decoration: BoxDecoration(color: context.c.surfaceSunken, shape: BoxShape.circle, border: Border.all(color: context.c.surfaceRaised, width: 2.5)),
                                              child: Center(child: Text('+${passengers.length - 6}', style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: context.c.ink2))),
                                            ),
                                          ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(color: context.c.okWash, borderRadius: BorderRadius.circular(10)),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check_circle_rounded, size: 12, color: context.c.ok),
                                              const SizedBox(width: 4),
                                              Text('${passengers.length} joined', style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: context.c.ok)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (passengers.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      const Divider(height: 1),
                                      const SizedBox(height: 10),
                                      ...passengers.take(3).map((p) {
                                        final pMap = p as Map<String, dynamic>;
                                        final name = _displayName(pMap);
                                        final pid  = pMap['id']?.toString() ?? '';
                                        final isMe = pid == _userId;
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Row(
                                            children: [
                                              Icon(Icons.person_rounded, size: 13, color: context.c.brand),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: pid.isNotEmpty
                                                      ? () => Navigator.push(context, MaterialPageRoute(
                                                          builder: (_) => RiderProfileScreen(userId: pid, knownName: name)))
                                                      : null,
                                                  child: Text(name, style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: context.c.ink)),
                                                ),
                                              ),
                                              if (!isMe && pid.isNotEmpty)
                                                GestureDetector(
                                                  onTap: () => showModerationSheet(
                                                    context,
                                                    targetUserId: pid,
                                                    targetName: name,
                                                    onActionDone: _fetchRideDetails,
                                                  ),
                                                  child: const Padding(
                                                    padding: EdgeInsets.only(left: 8),
                                                    child: Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF9CA3AF)),
                                                  ),
                                                )
                                              else
                                                Icon(Icons.chevron_right_rounded, size: 14, color: context.c.brand),
                                            ],
                                          ),
                                        );
                                      }),
                                      if (passengers.length > 3)
                                        Text('and ${passengers.length - 3} more...', style: AppTypography.dmSans(fontSize: 12, color: context.c.ink3, fontWeight: FontWeight.w500)),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      // ── Pending requests (driver only) ────────────────────
                      if (isDriver && _requests.where((r) => r['status'] == 'pending').isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(padding: EdgeInsets.all(6), decoration: BoxDecoration(color: context.c.surface, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.person_add_rounded, size: 16, color: context.c.brand)),
                                  const SizedBox(width: 10),
                                  Text('Join Requests', style: AppTypography.dmSans(fontSize: 15, fontWeight: FontWeight.w800)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(color: context.c.brand, borderRadius: BorderRadius.circular(6)),
                                    child: Text('${_requests.where((r) => r['status'] == 'pending').length}', style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: context.c.surfaceRaised)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ..._requests.where((r) => r['status'] == 'pending').map((req) {
                                final reqUser = req['user'] as Map<String, dynamic>?;
                                final reqName = _displayName(reqUser);
                                final reqUserId = reqUser?['id']?.toString() ?? '';
                                return GestureDetector(
                                  onTap: reqUserId.isNotEmpty
                                      ? () => Navigator.push(context, MaterialPageRoute(
                                          builder: (_) => RiderProfileScreen(userId: reqUserId, knownName: reqName)))
                                      : null,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(color: context.c.surface, borderRadius: BorderRadius.circular(14)),
                                    child: Row(
                                      children: [
                                        Container(width: 36, height: 36, decoration: BoxDecoration(color: context.c.brandWash, shape: BoxShape.circle),
                                          child: Center(child: Text(reqName.isNotEmpty ? reqName[0].toUpperCase() : '?', style: AppTypography.dmSans(fontWeight: FontWeight.w800, color: context.c.brand))),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(reqName, style: AppTypography.dmSans(fontWeight: FontWeight.w700)),
                                          ],
                                        )),
                                        GestureDetector(onTap: () => _handleRequest(req['id'], 'accepted'), child: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: context.c.okWash, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.check_rounded, color: context.c.ok, size: 18))),
                                        const SizedBox(width: 8),
                                        GestureDetector(onTap: () => _handleRequest(req['id'], 'rejected'), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: context.c.badWash, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.close_rounded, color: Colors.red, size: 18))),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],

                      // ── Itinerary section ─────────────────────────────────
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Itinerary', style: AppTypography.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: context.c.ink)),
                                    Container(height: 3, width: 60, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: context.c.brand, borderRadius: BorderRadius.circular(2))),
                                  ],
                                ),
                                if (isDriver)
                                  GestureDetector(
                                    onTap: itinerary != null ? _showRegenerateDialog : () => _generateItinerary(),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: context.c.brandWash,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: context.c.brand.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.auto_awesome_rounded, size: 13, color: context.c.brand),
                                          const SizedBox(width: 4),
                                          Text(
                                            _isGenerating ? 'Generating...' : itinerary != null ? 'Regenerate' : 'Generate AI',
                                            style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: context.c.brand),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (!isDriver && itinerary != null)
                                  GestureDetector(
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ItineraryPage(ride: _ride!, rideId: widget.rideId, isDriver: false, onGenerate: _generateItinerary, onRegenerate: _showRegenerateDialog, isGenerating: _isGenerating))),
                                    child: Text('View all', style: AppTypography.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: context.c.brand)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (_isGenerating)
                              Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: context.c.brand)))
                            else if (itinerary == null)
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(color: context.c.surfaceRaised, borderRadius: BorderRadius.circular(16)),
                                child: Row(
                                  children: [
                                    Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: context.c.brandWash, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.map_outlined, color: context.c.brand, size: 24)),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('No itinerary yet', style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 14)),
                                          Text(isDriver ? 'Tap "Generate AI" to create one' : 'The organizer will add one soon', style: AppTypography.dmSans(fontSize: 12, color: context.c.ink3)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ...dailyPlan.asMap().entries.map((entry) {
                                final day = entry.value;
                                final activities = (day['activities'] as List?) ?? [];
                                final isOnlyDay = dailyPlan.length == 1;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: context.c.surfaceRaised,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Theme(
                                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                    child: ExpansionTile(
                                      initiallyExpanded: isOnlyDay,
                                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      childrenPadding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                      leading: Container(
                                        width: 36, height: 36,
                                        decoration: BoxDecoration(color: context.c.brand, shape: BoxShape.circle),
                                        child: Center(child: Text('${day['day']}', style: AppTypography.dmSans(fontWeight: FontWeight.w700, color: context.c.surfaceRaised, fontSize: 13))),
                                      ),
                                      title: Text(
                                        'Day ${day['day']}${day['title'] != null ? ' · ${day['title']}' : ''}',
                                        style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 14, color: context.c.ink),
                                      ),
                                      subtitle: Text(
                                        '${activities.length} ${activities.length == 1 ? 'activity' : 'activities'}',
                                        style: AppTypography.dmSans(fontSize: 11, color: context.c.ink3, fontWeight: FontWeight.w600),
                                      ),
                                      iconColor: context.c.brand,
                                      collapsedIconColor: context.c.ink3,
                                      children: [
                                        if (activities.isEmpty)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                            child: Text('No activities listed', style: AppTypography.dmSans(fontSize: 13, color: context.c.ink3)),
                                          )
                                        else
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                            child: Column(
                                              children: activities.asMap().entries.map((actEntry) {
                                                final a = actEntry.value;
                                                final isLast = actEntry.key == activities.length - 1;
                                                final time = (a['time'] as String? ?? '').trim();
                                                final desc = (a['description'] as String? ?? a['name'] as String? ?? a['activity'] as String? ?? '').trim();
                                                return IntrinsicHeight(
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      // Time column
                                                      SizedBox(
                                                        width: 70,
                                                        child: Padding(
                                                          padding: const EdgeInsets.only(top: 2),
                                                          child: Text(
                                                            time,
                                                            style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: context.c.brand),
                                                          ),
                                                        ),
                                                      ),
                                                      // Timeline dot + line
                                                      Column(
                                                        children: [
                                                          Container(
                                                            width: 8, height: 8,
                                                            decoration: BoxDecoration(color: context.c.brand, shape: BoxShape.circle),
                                                          ),
                                                          if (!isLast)
                                                            Expanded(
                                                              child: Container(width: 1.5, color: context.c.brandWash),
                                                            ),
                                                        ],
                                                      ),
                                                      const SizedBox(width: 12),
                                                      // Description
                                                      Expanded(
                                                        child: Padding(
                                                          padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                                                          child: Text(
                                                            desc,
                                                            style: AppTypography.dmSans(fontSize: 13, color: context.c.ink2, height: 1.4, fontWeight: FontWeight.w500),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            if (dailyPlan.isNotEmpty)
                              GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ItineraryPage(ride: _ride!, rideId: widget.rideId, isDriver: isDriver, onGenerate: _generateItinerary, onRegenerate: _showRegenerateDialog, isGenerating: _isGenerating))),
                                child: Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: context.c.surfaceRaised,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: context.c.brand.withOpacity(0.3)),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.calendar_month_rounded, size: 14, color: context.c.brand),
                                        const SizedBox(width: 6),
                                        Text('View full itinerary', style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: context.c.brand)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // ── Estimated Cost ────────────────────────────────────
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ESTIMATED COST', style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: context.c.ink3, letterSpacing: 1.2)),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: context.c.surfaceRaised, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
                              child: Column(
                                children: [
                                  _costRow('Est. Budget/seat', '~₹${_ride!["pricePerSeat"]}'),
                                  const Divider(height: 20),
                                  _costRow('Seats Available', '${_ride!['seatsAvailable']}'),
                                  const Divider(height: 20),
                                  _costRow('Transport', (_ride!['transportMode'] ?? 'Car').toString().capitalize()),
                                  const Divider(height: 20),
                                  _costRow('Status', _statusLabel, valueColor: _statusColor),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildBottomBar(isDriver, isPassenger),
        ],
        ),
      ),
    );
  }

  // ─── Section helpers ──────────────────────────────────────────────────────

  Widget _actionChip({required IconData icon, required String label, required bool enabled, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: enabled ? context.c.brand : context.c.ink3,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: enabled ? context.c.onBrand : context.c.ink3),
            const SizedBox(width: 6),
            Text(label, style: AppTypography.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: enabled ? context.c.onBrand : context.c.ink3)),
          ],
        ),
      ),
    );
  }

  Widget _costRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.dmSans(fontSize: 13, color: context.c.ink2, fontWeight: FontWeight.w600)),
        Text(value, style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: valueColor ?? context.c.ink)),
      ],
    );
  }

  Widget _buildBottomBar(bool isDriver, bool isPassenger) {
    final status = _ride!['status'];

    if (isDriver) {
      String? label; IconData? icon; VoidCallback? onTap;
      if (status == 'scheduled') { label = 'Start Ride'; icon = Icons.play_arrow_rounded; onTap = () => _updateRideStatus('start'); }
      if (status == 'ongoing')   { label = 'Complete Ride'; icon = Icons.check_circle_rounded; onTap = () => _updateRideStatus('complete'); }
      if (status == 'paused')    { label = 'Resume Ride'; icon = Icons.play_arrow_rounded; onTap = () => _updateRideStatus('resume'); }
      if (status == 'completed') {
        label = 'Rate Riders'; icon = Icons.star_rounded;
        onTap = () {
          final pax = (_ride!['passengers'] as List);
          if (pax.isNotEmpty) {
            final p = pax.first;
            showDialog(context: context, builder: (_) => RatingDialog(rideId: widget.rideId, rateeId: p['id'], rateeName: _displayName(p as Map<String, dynamic>), rateeRole: 'passenger', onSubmitted: _fetchRideDetails));
          }
        };
      }
      if (label == null) return const SizedBox.shrink();
      return _bottomBar(label, icon!, onTap!);
    }

    if (isPassenger && status == 'completed') {
      return _bottomBar('Rate Driver', Icons.star_rounded, () {
        showDialog(context: context, builder: (_) => RatingDialog(rideId: widget.rideId, rateeId: _ride!['driver']['id'], rateeName: _displayName(_ride!['driver']), rateeRole: 'driver', onSubmitted: _fetchRideDetails));
      });
    }

    if (!isDriver && !isPassenger) {
      return _bottomBar(
        _userRequest == null ? 'Request to Join ⚡' : 'Request Sent ✓',
        _userRequest == null ? Icons.flash_on_rounded : Icons.check_circle_rounded,
        _userRequest == null ? () => _showJoinRequestSheet() : null,
        enabled: _userRequest == null,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _bottomBar(String label, IconData icon, VoidCallback? onTap, {bool enabled = true}) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: context.c.surfaceRaised,
        border: Border(top: BorderSide(color: context.c.rule, width: 0.5)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: enabled ? onTap : null,
          icon: Icon(icon, size: 20),
          label: Text(label, style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.c.brand,
            disabledBackgroundColor: context.c.ink3,
            foregroundColor: context.c.onBrand,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
      ),
    );
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
        decoration: BoxDecoration(color: context.c.surfaceRaised, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: context.c.ink3, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: context.c.brandWash, shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, size: 40, color: context.c.brand),
            ),
            const SizedBox(height: 24),
            Text('Join Request Sent!', style: AppTypography.dmSans(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: AppTypography.dmSans(fontSize: 14, color: context.c.ink2, height: 1.5),
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
                  backgroundColor: context.c.brand,
                  foregroundColor: context.c.onBrand,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text('Got it, thanks!', style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

// ─── String extension ─────────────────────────────────────────────────────────

extension StringCapitalize on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
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
      backgroundColor: context.c.surface,
      appBar: AppBar(
        title: Text('Itinerary', style: AppTypography.dmSans(fontWeight: FontWeight.w800)),
        backgroundColor: context.c.surface,
        elevation: 0,
        actions: [
          if (widget.isDriver && itinerary != null)
            TextButton(
              onPressed: _isEditing ? _saveManualEdits : () => setState(() => _isEditing = true),
              child: Text(_isEditing ? 'Save' : 'Edit', style: AppTypography.dmSans(fontWeight: FontWeight.w800, color: context.c.brand)),
            ),
        ],
      ),
      body: widget.isGenerating
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: context.c.brand),
              SizedBox(height: 16),
              Text('Generating itinerary...', style: TextStyle(color: context.c.ink3, fontWeight: FontWeight.w600)),
            ]))
          : itinerary == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 64, color: context.c.ink3),
                        const SizedBox(height: 16),
                        Text('No Itinerary Yet', style: AppTypography.dmSans(fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(
                          widget.isDriver ? 'Generate a travel plan using AI' : 'The organizer hasn\'t created an itinerary yet.',
                          textAlign: TextAlign.center,
                          style: AppTypography.dmSans(color: context.c.ink2, fontSize: 14),
                        ),
                        if (widget.isDriver) ...[
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => widget.onGenerate(),
                            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                            label: Text('Generate Itinerary', style: AppTypography.dmSans(fontWeight: FontWeight.w800)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.c.brand, foregroundColor: context.c.onBrand,
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
              color: _isSuccess ? context.c.okWash : context.c.badWash,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _isSuccess ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                Icon(_isSuccess ? Icons.check_circle_rounded : Icons.error_rounded, size: 18, color: _isSuccess ? context.c.ok : context.c.bad),
                const SizedBox(width: 10),
                Expanded(child: Text(_statusMessage!, style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: _isSuccess ? context.c.ok : context.c.bad))),
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
                  Text('Full Itinerary', style: AppTypography.dmSans(fontSize: 20, fontWeight: FontWeight.w800)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: context.c.surfaceSunken, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.c.ink3!)),
                    child: Text('AI GENERATED', style: AppTypography.dmSans(fontSize: 10, fontWeight: FontWeight.w800, color: context.c.ink2, letterSpacing: 0.5)),
                  ),
                ],
              ),
              // Summary — only show in edit mode
              if (_isEditing) ...[
                const SizedBox(height: 16),
                Text('Summary', style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: context.c.ink2)),
                const SizedBox(height: 8),
                TextField(
                  controller: _summaryController,
                  maxLines: null,
                  minLines: 2,
                  style: AppTypography.dmSans(fontSize: 14, height: 1.5),
                  decoration: InputDecoration(
                    hintText: 'Edit summary...',
                    filled: true,
                    fillColor: context.c.surfaceSunken,
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
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: context.c.brand, shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Text('DAY ${day['day']}', style: AppTypography.dmSans(fontWeight: FontWeight.w800, color: context.c.brand, fontSize: 13, letterSpacing: 0.5)),
                        const Spacer(),
                        if (widget.isDriver && _isEditing)
                          GestureDetector(
                            onTap: () => _pickDayImage(dayIndex),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: context.c.brandWash, borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_photo_alternate_rounded, size: 14, color: context.c.brand),
                                  const SizedBox(width: 4),
                                  Text(dayImage != null ? 'Change' : 'Add Photo', style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: context.c.brand)),
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
                        decoration: BoxDecoration(border: Border(left: BorderSide(color: context.c.brandWash, width: 2))),
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
                                  decoration: BoxDecoration(color: context.c.surfaceSunken, borderRadius: BorderRadius.circular(12)),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 70,
                                            child: TextFormField(
                                              initialValue: act['time'] ?? '',
                                              style: AppTypography.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: context.c.brand),
                                              decoration: const InputDecoration(hintText: 'Time', isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                                              onChanged: (v) => (activities[actIndex] as Map)['time'] = v,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              initialValue: act['description'] ?? '',
                                              style: AppTypography.dmSans(fontSize: 14, height: 1.4),
                                              maxLines: null,
                                              decoration: const InputDecoration(hintText: 'Activity description', isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                                              onChanged: (v) => (activities[actIndex] as Map)['description'] = v,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => setState(() => activities.removeAt(actIndex)),
                                            child: Icon(Icons.close_rounded, size: 16, color: context.c.ink3),
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
                                    Text(act['time'] ?? '', style: AppTypography.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: context.c.brand)),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(act['description'] ?? '', style: AppTypography.dmSans(fontSize: 14, height: 1.4, color: context.c.ink2))),
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
                                      Icon(Icons.add_circle_outline_rounded, size: 16, color: context.c.brand),
                                      const SizedBox(width: 8),
                                      Text('Add activity', style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: context.c.brand)),
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
                  label: Text('Regenerate with AI', style: AppTypography.dmSans(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.c.brand,
                    side: BorderSide(color: context.c.brand),
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
          decoration: BoxDecoration(color: context.c.surfaceRaised, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.c.ink3, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('Add Expense', style: AppTypography.dmSans(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),

                // Description
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(hintText: 'What was it for? (e.g. Fuel, Dinner)', filled: true, fillColor: context.c.surfaceSunken, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 12),

                // Amount
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: 'Amount', prefixText: '₹ ', filled: true, fillColor: context.c.surfaceSunken, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 20),

                // Paid by
                Text('Paid by', style: AppTypography.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: context.c.ink2)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allParticipants.map((p) {
                    final selected = paidById == p['id'];
                    return ChoiceChip(
                      label: Text(p['name']!, style: AppTypography.dmSans(fontWeight: FontWeight.w700, fontSize: 13, color: selected ? context.c.onBrand : context.c.ink2)),
                      selected: selected,
                      onSelected: (_) => setSheetState(() => paidById = p['id']!),
                      selectedColor: context.c.brand,
                      backgroundColor: context.c.surfaceSunken,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide.none,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Split among
                Text('Split among', style: AppTypography.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: context.c.ink2)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allParticipants.map((p) {
                    final id = p['id']!;
                    final isSelected = splitIds.contains(id);
                    return FilterChip(
                      label: Text(p['name']!, style: AppTypography.dmSans(fontWeight: FontWeight.w700, fontSize: 13, color: isSelected ? context.c.onBrand : context.c.ink2)),
                      selected: isSelected,
                      onSelected: (val) {
                        setSheetState(() {
                          if (val) { splitIds.add(id); } else if (splitIds.length > 1) { splitIds.remove(id); }
                        });
                      },
                      selectedColor: context.c.brand,
                      backgroundColor: context.c.surfaceSunken,
                      checkmarkColor: context.c.onBrand,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide.none,
                    );
                  }).toList(),
                ),
                if (splitIds.length < allParticipants.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Splitting among ${splitIds.length} of ${allParticipants.length} riders', style: AppTypography.dmSans(fontSize: 11, color: context.c.ink2, fontWeight: FontWeight.w600)),
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
                    style: ElevatedButton.styleFrom(backgroundColor: context.c.brand, foregroundColor: context.c.onBrand, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                    child: Text('Add Expense', style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 15)),
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
      backgroundColor: context.c.surface,
      appBar: AppBar(
        title: Text('Trip Expenses', style: AppTypography.dmSans(fontWeight: FontWeight.w800)),
        backgroundColor: context.c.surface, elevation: 0,
      ),
      floatingActionButton: widget.canEdit ? FloatingActionButton(
        onPressed: _addExpense,
        backgroundColor: context.c.brand,
        child: Icon(Icons.add_rounded, color: context.c.onBrand),
      ) : null,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: context.c.brand))
          : RefreshIndicator(
              onRefresh: _loadExpenses,
              color: context.c.brand,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Total card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.c.brand,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Trip Expense', style: AppTypography.dmSans(color: context.c.onBrand.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('₹${(total is num ? total : double.tryParse('$total') ?? 0).toStringAsFixed(0)}', style: AppTypography.dmSans(color: context.c.surfaceRaised, fontSize: 36, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 16),
                        Container(height: 1, color: context.c.onBrand.withValues(alpha: 0.24)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('YOUR SHARE', style: AppTypography.dmSans(color: context.c.onBrand.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                  const SizedBox(height: 4),
                                  Text('₹${(perPerson is num ? perPerson : double.tryParse('$perPerson') ?? 0).toStringAsFixed(0)}', style: AppTypography.dmSans(color: context.c.surfaceRaised, fontSize: 20, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('EXPENSES', style: AppTypography.dmSans(color: context.c.onBrand.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                  const SizedBox(height: 4),
                                  Text('${_expenses.length}', style: AppTypography.dmSans(color: context.c.surfaceRaised, fontSize: 20, fontWeight: FontWeight.w800)),
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
                    Text('Recent Expenses', style: AppTypography.dmSans(fontSize: 18, fontWeight: FontWeight.w800)),
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
                          color: context.c.surfaceSunken,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: context.c.brandWash, borderRadius: BorderRadius.circular(12)),
                              child: Icon(_expenseIcon(desc), color: context.c.brand, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(desc, style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text('Paid by $payerName', style: AppTypography.dmSans(color: context.c.ink2, fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            Text('₹${amount.toStringAsFixed(0)}', style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 16)),
                          ],
                        ),
                      );
                    }),
                  ] else ...[
                    const SizedBox(height: 40),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 48, color: context.c.ink3),
                          const SizedBox(height: 12),
                          Text('No expenses yet', style: AppTypography.dmSans(color: context.c.ink3, fontWeight: FontWeight.w600)),
                          if (widget.canEdit)
                            Text('Tap + to add an expense', style: AppTypography.dmSans(color: context.c.ink3, fontSize: 12)),
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
                        color: context.c.surfaceSunken,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.c.ink3!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BALANCES', style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: context.c.ink2, letterSpacing: 0.5)),
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
                                    backgroundColor: context.c.brandWash,
                                    child: Text((b['userName'] ?? 'U')[0].toUpperCase(), style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 11, color: context.c.brand)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(b['userName'] ?? 'User', style: AppTypography.dmSans(fontWeight: FontWeight.w700, fontSize: 14))),
                                  Text(
                                    '${isPositive ? '+' : ''}₹${balance.toStringAsFixed(0)}',
                                    style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 14, color: isPositive ? context.c.ok : context.c.bad),
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

// ── Floating Live Map Button ──────────────────────────────────────────────────

class _LiveMapFab extends StatefulWidget {
  final VoidCallback onTap;
  const _LiveMapFab({required this.onTap});

  @override
  State<_LiveMapFab> createState() => _LiveMapFabState();
}

class _LiveMapFabState extends State<_LiveMapFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.06).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            color: context.c.ink,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color: context.c.ink.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing green dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: context.c.ok, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.map_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                'LIVE MAP',
                style: AppTypography.dmSans(
                  color: context.c.surfaceRaised,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown once, when a ride is marked complete.
///
/// Replaces an AlertDialog whose title was "Ride Complete! 🏁", whose body was
/// bold 14pt, and whose only action shouted "GREAT". A moment worth marking
/// deserves composition rather than punctuation: the number is the hero, the
/// emoji are gone, and the button says what it does.
class _RideCompleteSheet extends StatelessWidget {
  const _RideCompleteSheet({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Dialog(
      backgroundColor: c.surfaceRaised,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration:
                  BoxDecoration(color: c.okWash, borderRadius: AppRadius.cardR),
              child: Icon(Icons.check_rounded, color: c.ok, size: 24),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Ride complete',
                style: AppTypography.title.copyWith(color: c.ink)),
            const SizedBox(height: AppSpacing.xxs),
            Text('Nice one. Everyone who travelled with you earned points too.',
                style: AppTypography.callout.copyWith(color: c.ink2)),
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm, horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                  color: c.brandWash, borderRadius: AppRadius.cardR),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('+$points',
                      style: AppTypography.display
                          .copyWith(color: c.brand, fontSize: 30)),
                  const SizedBox(width: AppSpacing.xs),
                  Text('Compass Points',
                      style: AppTypography.callout.copyWith(color: c.brand)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: c.brand,
                  textStyle: AppTypography.bodyStrong,
                  minimumSize: const Size(0, AppTouch.min),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
