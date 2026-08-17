import 'dart:async';
import '../theme/flettra_colors.dart';
import '../theme/app_typography.dart';
import 'dart:math' show cos, sqrt, asin, sin, pi;
import 'dart:ui' as ui;

import 'package:dio/dio.dart' show CancelToken, DioException;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../services/api_service.dart';
import '../services/nearby_poi_service.dart';

class GroupLiveMapScreen extends StatefulWidget {
  final String rideId;
  final List<Map<String, dynamic>> participants;
  final String? currentUserId;
  final String? destinationName;
  final String? originName;

  const GroupLiveMapScreen({
    super.key,
    required this.rideId,
    required this.participants,
    this.currentUserId,
    this.destinationName,
    this.originName,
  });

  @override
  State<GroupLiveMapScreen> createState() => _GroupLiveMapScreenState();
}

class _GroupLiveMapScreenState extends State<GroupLiveMapScreen> {
  GoogleMapController? _mapController;
  IO.Socket? _socket;
  StreamSubscription<Position>? _positionSub;

  // ── Member tracking ────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _members = [];
  Set<Marker> _memberMarkers = {};
  String? _selectedMemberId;
  bool _locationDenied = false;
  Position? _myPosition;

  // ── POI overlay ───────────────────────────────────────────────────────────
  String? _activeCategoryKey;
  List<PoiResult> _pois = [];
  bool _poisLoading = false;
  String? _poisError;
  Set<Marker> _poiMarkers = {};
  PoiResult? _nextOnRoute;
  CancelToken? _poiCancelToken;

  // Destination coordinates (geocoded lazily)
  double? _destLat;
  double? _destLng;
  bool _geocodingDest = false;

  // ── Palette ───────────────────────────────────────────────────────────────
  static List<Color> _memberPalette = [
    Color(0xFF6366F1), Color(0xFFF59E0B), Color(0xFF5FD98A),
    Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFF06B6D4), Color(0xFFF97316),
  ];

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _colorFor(String userId) {
    final sorted = widget.participants.map((p) => p['id'] as String).toList()..sort();
    final idx = sorted.indexOf(userId);
    return _memberPalette[(idx < 0 ? 0 : idx) % _memberPalette.length];
  }

  String _participantName(Map<String, dynamic> p) {
    final name = p['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final first = (p['firstName'] as String? ?? '').trim();
    final last  = (p['lastName']  as String? ?? '').trim();
    final full  = '$first $last'.trim();
    return full.isNotEmpty ? full : 'User';
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
            sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * asin(sqrt(a));
  }

  String _formatDist(double km) =>
      km < 1 ? '${(km * 1000).toStringAsFixed(0)} m' : '${km.toStringAsFixed(1)} km';

  // ── Member marker bitmap ──────────────────────────────────────────────────

  Future<BitmapDescriptor> _buildMemberMarker(
      String initial, Color color, bool isMe) async {
    final size = isMe ? 52.0 : 44.0;
    final pinH = size + 12.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, pinH));

    canvas.drawCircle(Offset(size / 2, size / 2 + 3), size / 2 - 4,
        Paint()
          ..color = Colors.black.withOpacity(0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 4, Paint()..color = color);
    if (isMe) {
      canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 7,
          Paint()
            ..color = Colors.white.withOpacity(0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
    final tp = TextPainter(
      text: TextSpan(
        text: initial.toUpperCase(),
        style: TextStyle(color: Colors.white, fontSize: isMe ? 18 : 15, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));

    final tri = Path()
      ..moveTo(size / 2 - 5, size - 3)
      ..lineTo(size / 2, pinH)
      ..lineTo(size / 2 + 5, size - 3)
      ..close();
    canvas.drawPath(tri, Paint()..color = color);

    final pic  = recorder.endRecording();
    final img  = await pic.toImage(size.toInt(), pinH.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  // ── POI marker bitmap ─────────────────────────────────────────────────────

  Future<BitmapDescriptor> _buildPoiMarker(PoiCategory cat, {bool highlight = false}) async {
    const size = 40.0;
    const pinH = 52.0;
    final color = Color(cat.colorValue);
    final bgColor = highlight ? color : color.withOpacity(0.85);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, pinH));

    // Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(2, 4, size - 4, size - 4), const Radius.circular(10)),
      Paint()
        ..color = Colors.black.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Rounded square
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size, size - 4), const Radius.circular(10)),
      Paint()..color = bgColor,
    );

    // White inner ring if highlighted (next on route)
    if (highlight) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(2, 2, size - 4, size - 6), const Radius.circular(8)),
        Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Letter
    final letter = cat.key == 'medical' ? '+' : cat.label[0].toUpperCase();
    final tp = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          color: context.c.surfaceRaised,
          fontSize: highlight ? 18 : 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rectH = size - 4;
    tp.paint(canvas, Offset((size - tp.width) / 2, (rectH - tp.height) / 2));

    // Pin triangle
    final tri = Path()
      ..moveTo(size / 2 - 4, size - 4)
      ..lineTo(size / 2, pinH)
      ..lineTo(size / 2 + 4, size - 4)
      ..close();
    canvas.drawPath(tri, Paint()..color = bgColor);

    final pic  = recorder.endRecording();
    final img  = await pic.toImage(size.toInt(), pinH.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  // ── Socket ────────────────────────────────────────────────────────────────

  Future<void> _connectSocket() async {
    final token = await const FlutterSecureStorage().read(key: 'jwt_token');
    _socket = IO.io(ApiService.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {'token': token},
    });
    _socket!.connect();
    _socket!.onConnect((_) {
      _socket!.emit('joinRide', widget.rideId);
      _socket!.emit('getMemberLocations', widget.rideId);
    });
    _socket!.on('memberLocations', (data) async {
      if (!mounted) return;
      final members = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      await _updateMemberMarkers(members);
    });
  }

  Future<void> _updateMemberMarkers(List<Map<String, dynamic>> members) async {
    final Set<Marker> newMarkers = {};
    for (final m in members) {
      final userId = m['userId'] as String;
      final name = (m['name'] as String?) ?? 'User';
      final lat = (m['lat'] as num).toDouble();
      final lng = (m['lng'] as num).toDouble();
      final isMe = userId == widget.currentUserId;
      final icon = await _buildMemberMarker(name[0], _colorFor(userId), isMe);
      newMarkers.add(Marker(
        markerId: MarkerId(userId),
        position: LatLng(lat, lng),
        icon: icon,
        zIndexInt: isMe ? 99 : 1,
        onTap: () => setState(() =>
            _selectedMemberId = _selectedMemberId == userId ? null : userId),
      ));
    }
    if (!mounted) return;
    setState(() {
      _members = members;
      _memberMarkers = newMarkers;
    });
    _fitCamera(members);
  }

  void _fitCamera(List<Map<String, dynamic>> members) {
    if (_mapController == null || members.isEmpty) return;
    if (members.length == 1) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng((members[0]['lat'] as num).toDouble(), (members[0]['lng'] as num).toDouble()),
        15,
      ));
    } else {
      double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
      for (final m in members) {
        final lat = (m['lat'] as num).toDouble();
        final lng = (m['lng'] as num).toDouble();
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
      }
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
        80,
      ));
    }
  }

  // ── GPS ───────────────────────────────────────────────────────────────────

  Future<void> _startLocationSharing() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => _locationDenied = true);
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      setState(() => _locationDenied = true);
      return;
    }
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((pos) {
      _myPosition = pos;
      _socket?.emit('updateMemberLocation', {
        'rideId': widget.rideId,
        'lat': pos.latitude,
        'lng': pos.longitude,
      });
    });
  }

  // ── POI search ────────────────────────────────────────────────────────────

  Future<void> _selectCategory(String key) async {
    // Toggle off
    if (_activeCategoryKey == key) {
      _poiCancelToken?.cancel();
      setState(() {
        _activeCategoryKey = null;
        _pois = [];
        _poiMarkers = {};
        _nextOnRoute = null;
        _poisError = null;
      });
      return;
    }

    _poiCancelToken?.cancel();
    _poiCancelToken = CancelToken();

    setState(() {
      _activeCategoryKey = key;
      _pois = [];
      _poiMarkers = {};
      _nextOnRoute = null;
      _poisLoading = true;
      _poisError = null;
    });

    // Get current position
    final pos = _myPosition ??
        (await Geolocator.getLastKnownPosition()) ??
        (_members.isNotEmpty
            ? null
            : null);

    double? lat = pos?.latitude;
    double? lng = pos?.longitude;

    // Fall back to first known member location
    if ((lat == null || lng == null) && _members.isNotEmpty) {
      final myMember = _members.where((m) => m['userId'] == widget.currentUserId).firstOrNull
          ?? _members.first;
      lat = (myMember['lat'] as num?)?.toDouble();
      lng = (myMember['lng'] as num?)?.toDouble();
    }

    if (lat == null || lng == null) {
      setState(() {
        _poisLoading = false;
        _poisError = 'Location unavailable. Enable location and try again.';
      });
      return;
    }

    try {
      List<PoiResult> results;

      // For fuel: if we have a destination, do on-route search
      if (key == 'fuel' && widget.destinationName != null) {
        final destCoords = await _getDestinationCoords();
        if (destCoords != null) {
          results = await NearbyPoiService.searchOnRoute(
            currentLat: lat,
            currentLng: lng,
            destLat: destCoords.$1,
            destLng: destCoords.$2,
            categoryKey: key,
            cancelToken: _poiCancelToken,
          );
          // If on-route search returns results, first one is "next on route"
          if (results.isNotEmpty) {
            if (mounted) setState(() => _nextOnRoute = results.first);
          }
          // Fall back to nearby if corridor is empty
          if (results.isEmpty) {
            results = await NearbyPoiService.searchNearby(
              lat: lat, lng: lng, categoryKey: key,
              cancelToken: _poiCancelToken,
            );
          }
        } else {
          results = await NearbyPoiService.searchNearby(
            lat: lat, lng: lng, categoryKey: key,
            cancelToken: _poiCancelToken,
          );
        }
      } else {
        results = await NearbyPoiService.searchNearby(
          lat: lat, lng: lng, categoryKey: key,
          cancelToken: _poiCancelToken,
        );
      }

      if (!mounted) return;

      // Build POI markers
      final cat = NearbyPoiService.categories[key]!;
      final Set<Marker> markers = {};
      for (final poi in results) {
        final isNext = poi.id == _nextOnRoute?.id;
        final icon = await _buildPoiMarker(cat, highlight: isNext);
        markers.add(Marker(
          markerId: MarkerId('poi_${poi.id}'),
          position: LatLng(poi.lat, poi.lng),
          icon: icon,
          zIndexInt: isNext ? 50 : 10,
          infoWindow: InfoWindow(
            title: poi.name,
            snippet: poi.distanceKm != null ? _formatDist(poi.distanceKm!) : null,
          ),
          onTap: () {
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(LatLng(poi.lat, poi.lng), 16));
          },
        ));
      }

      if (!mounted) return;
      setState(() {
        _pois = results;
        _poiMarkers = markers;
        _poisLoading = false;
      });

      // Pan to show next on route or first result
      final focusPoi = _nextOnRoute ?? (results.isNotEmpty ? results.first : null);
      if (focusPoi != null) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(focusPoi.lat, focusPoi.lng), 12));
      }
    } on DioException catch (e) {
      if (e.type.name == 'cancel') return;
      if (!mounted) return;
      setState(() { _poisLoading = false; _poisError = 'Search failed. Tap to retry.'; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _poisLoading = false; _poisError = 'Search failed. Tap to retry.'; });
    }
  }

  Future<(double, double)?> _getDestinationCoords() async {
    if (_destLat != null && _destLng != null) return (_destLat!, _destLng!);
    if (widget.destinationName == null) return null;
    if (_geocodingDest) return null;
    setState(() => _geocodingDest = true);
    final coords = await NearbyPoiService.geocode(widget.destinationName!);
    setState(() {
      _geocodingDest = false;
      if (coords != null) { _destLat = coords.$1; _destLng = coords.$2; }
    });
    return coords;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _connectSocket();
    _startLocationSharing();
  }

  @override
  void dispose() {
    _poiCancelToken?.cancel();
    _positionSub?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final myMember = _members.where((m) => m['userId'] == widget.currentUserId);
    final myLoc = myMember.isNotEmpty ? myMember.first : null;
    final allMarkers = {..._memberMarkers, ..._poiMarkers};

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: LatLng(20.5937, 78.9629), zoom: 5),
            markers: allMarkers,
            onMapCreated: (ctrl) {
              _mapController = ctrl;
              if (_members.isNotEmpty) _updateMemberMarkers(_members);
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // ── Top HUD ──────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  // Live badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 2))],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const _PulseDot(),
                      const SizedBox(width: 8),
                      Text(
                        'LIVE  ·  ${_members.length} / ${widget.participants.length} sharing',
                        style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w800, color: context.c.ink),
                      ),
                    ]),
                  ),
                  const Spacer(),
                  // Close
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12)],
                      ),
                      child: Icon(Icons.close_rounded, size: 18, color: context.c.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Next-on-route banner (fuel only) ─────────────────────────────
          if (_nextOnRoute != null && _activeCategoryKey == 'fuel')
            Positioned(
              top: MediaQuery.of(context).padding.top + 68,
              left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: context.c.brand,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: context.c.brand.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Row(children: [
                  const Text('⛽', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        'Next fuel: ${_nextOnRoute!.distanceKm != null ? _formatDist(_nextOnRoute!.distanceKm!) : "ahead"}',
                        style: AppTypography.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: context.c.surfaceRaised),
                      ),
                      Text(
                        _nextOnRoute!.name,
                        style: AppTypography.dmSans(fontSize: 11, color: Colors.white.withOpacity(0.85)),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ]),
                  ),
                  GestureDetector(
                    onTap: () => _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(LatLng(_nextOnRoute!.lat, _nextOnRoute!.lng), 15)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: context.c.surfaceRaised.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                      child: Text('Go', style: AppTypography.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: context.c.surfaceRaised)),
                    ),
                  ),
                ]),
              ),
            ),

          // ── Location denied warning ───────────────────────────────────────
          if (_locationDenied)
            Positioned(
              bottom: 240, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Location access denied — others can\'t see you',
                    style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
                  )),
                ]),
              ),
            ),

          // ── Bottom panel ──────────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.97),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.13), blurRadius: 24, offset: const Offset(0, -4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Category chips ────────────────────────────────────────
                  _buildCategoryChips(),

                  // ── Content: POI list OR member strip ─────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _activeCategoryKey != null
                        ? _buildPoiContent()
                        : _buildMemberStrip(myLoc),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Category chip strip ───────────────────────────────────────────────────

  Widget _buildCategoryChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: NearbyPoiService.categories.entries.map((entry) {
            final cat = entry.value;
            final isActive = _activeCategoryKey == cat.key;
            final isLoading = isActive && _poisLoading;
            final catColor = Color(cat.colorValue);

            return GestureDetector(
              onTap: () => _selectCategory(cat.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isActive ? catColor : const Color(0xFFF4F4F4),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isActive
                      ? [BoxShadow(color: catColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                      : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  isLoading
                      ? SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.withOpacity(0.8)))
                      : Text(cat.emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 5),
                  Text(
                    cat.label,
                    style: AppTypography.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isActive ? context.c.onBrand : const Color(0xFF555555),
                    ),
                  ),
                  if (isActive && _pois.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: context.c.surfaceRaised.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        '${_pois.length}',
                        style: AppTypography.dmSans(fontSize: 10, fontWeight: FontWeight.w800, color: context.c.surfaceRaised),
                      ),
                    ),
                  ],
                ]),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── POI list ──────────────────────────────────────────────────────────────

  Widget _buildPoiContent() {
    final cat = NearbyPoiService.categories[_activeCategoryKey]!;

    if (_poisLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(cat.colorValue))),
          const SizedBox(height: 10),
          Text('Searching nearby ${cat.label.toLowerCase()}…',
              style: AppTypography.dmSans(fontSize: 12, color: context.c.ink2)),
        ])),
      );
    }

    if (_poisError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: GestureDetector(
          onTap: () => _selectCategory(_activeCategoryKey!),
          child: Row(children: [
            Icon(Icons.refresh_rounded, color: Color(cat.colorValue), size: 18),
            const SizedBox(width: 8),
            Text(_poisError!, style: AppTypography.dmSans(fontSize: 12, color: context.c.ink2)),
          ]),
        ),
      );
    }

    if (_pois.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text(
          'No ${cat.label.toLowerCase()} found nearby',
          style: AppTypography.dmSans(fontSize: 12, color: context.c.ink3),
        )),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
        physics: const BouncingScrollPhysics(),
        itemCount: _pois.length,
        itemBuilder: (_, i) => _buildPoiTile(_pois[i], cat),
      ),
    );
  }

  Widget _buildPoiTile(PoiResult poi, PoiCategory cat) {
    final isNext = poi.id == _nextOnRoute?.id;
    final catColor = Color(cat.colorValue);

    return GestureDetector(
      onTap: () => _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(poi.lat, poi.lng), 16)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isNext ? catColor.withOpacity(0.07) : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(14),
          border: isNext ? Border.all(color: catColor.withOpacity(0.25)) : null,
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: catColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(cat.emoji, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(poi.name,
                  style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: context.c.ink),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (isNext)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: catColor, borderRadius: BorderRadius.circular(6)),
                  child: Text('NEXT', style: AppTypography.dmSans(fontSize: 8, fontWeight: FontWeight.w800, color: context.c.surfaceRaised, letterSpacing: 0.5)),
                ),
            ]),
            const SizedBox(height: 2),
            Text(poi.subtitle,
                style: AppTypography.dmSans(fontSize: 11, color: context.c.ink2),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (poi.distanceKm != null)
              Text(_formatDist(poi.distanceKm!),
                  style: AppTypography.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: catColor)),
            if (poi.routeProgress != null)
              Text('on route', style: AppTypography.dmSans(fontSize: 9, color: context.c.ink3)),
          ]),
        ]),
      ),
    );
  }

  // ── Member strip (original) ───────────────────────────────────────────────

  Widget _buildMemberStrip(Map<String, dynamic>? myLoc) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          child: Row(children: [
            const Icon(Icons.people_rounded, size: 14, color: Color(0xFF6366F1)),
            const SizedBox(width: 6),
            Text('GROUP MEMBERS',
                style: AppTypography.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: context.c.ink2, letterSpacing: 1.2)),
          ]),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Row(
            children: widget.participants.map((p) {
              final uid = p['id'] as String;
              final name = _participantName(p);
              final loc = _members.where((m) => m['userId'] == uid).firstOrNull;
              final hasLoc = loc != null;
              final isMe = uid == widget.currentUserId;
              final color = _colorFor(uid);
              final isSelected = _selectedMemberId == uid;

              double? dist;
              if (hasLoc && myLoc != null && !isMe) {
                dist = _haversineKm(
                  (myLoc['lat'] as num).toDouble(), (myLoc['lng'] as num).toDouble(),
                  (loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble(),
                );
              }

              return GestureDetector(
                onTap: () {
                  if (!hasLoc) return;
                  _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
                    LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble()), 15));
                  setState(() => _selectedMemberId = _selectedMemberId == uid ? null : uid);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.10) : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    border: isSelected ? Border.all(color: color.withOpacity(0.30)) : null,
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Stack(clipBehavior: Clip.none, children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          color: hasLoc ? color : context.c.ink3,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: hasLoc
                              ? [BoxShadow(color: color.withOpacity(0.30), blurRadius: 8, offset: const Offset(0, 3))]
                              : null,
                        ),
                        child: Center(child: Text(
                          name[0].toUpperCase(),
                          style: TextStyle(color: hasLoc ? context.c.onBrand : context.c.ink3, fontSize: 20, fontWeight: FontWeight.w700),
                        )),
                      ),
                      if (hasLoc)
                        Positioned(top: -3, right: -3,
                          child: Container(width: 13, height: 13,
                            decoration: BoxDecoration(
                              color: context.c.ok,
                              shape: BoxShape.circle,
                              border: Border.all(color: context.c.surfaceRaised, width: 2),
                            )),
                        ),
                    ]),
                    const SizedBox(height: 6),
                    Text(isMe ? 'You' : name.split(' ')[0],
                        style: AppTypography.dmSans(fontSize: 10, fontWeight: FontWeight.w800, color: context.c.ink)),
                    const SizedBox(height: 2),
                    if (dist != null)
                      Text(_formatDist(dist),
                          style: AppTypography.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF6366F1)))
                    else if (isMe && hasLoc)
                      Text('Here', style: AppTypography.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: context.c.ok))
                    else
                      Text(hasLoc ? '–' : 'offline',
                          style: AppTypography.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: context.c.ink3)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Pulsing live dot ───────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 9, height: 9,
        decoration: BoxDecoration(color: Color.fromRGBO(16, 185, 129, _anim.value), shape: BoxShape.circle),
      ),
    );
  }
}
