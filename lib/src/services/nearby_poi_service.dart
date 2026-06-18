import 'dart:math' as math;
import 'package:dio/dio.dart';

// ── POI category descriptor ────────────────────────────────────────────────────

class PoiCategory {
  final String key;
  final String label;
  final String emoji;
  final String osmQuery;
  final int colorValue;

  const PoiCategory({
    required this.key,
    required this.label,
    required this.emoji,
    required this.osmQuery,
    required this.colorValue,
  });
}

// ── Single POI result ─────────────────────────────────────────────────────────

class PoiResult {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String category;
  final Map<String, dynamic> tags;

  /// Straight-line km from the query origin
  double? distanceKm;

  /// 0–1: how far along the route from current pos → destination
  double? routeProgress;

  PoiResult({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.category,
    required this.tags,
    this.distanceKm,
    this.routeProgress,
  });

  String get address {
    final t = tags;
    final parts = <String>[
      if (t['addr:street'] != null) t['addr:street'],
      if (t['addr:city'] != null) t['addr:city'],
    ];
    return parts.join(', ');
  }

  String get subtitle {
    final t = tags;
    if (category == 'fuel') return t['brand'] ?? t['operator'] ?? 'Fuel station';
    if (category == 'stay')  return t['tourism']?.toString().replaceAll('_', ' ') ?? 'Accommodation';
    if (category == 'mechanic') return 'Auto repair';
    if (category == 'bike') return 'Motorcycle shop';
    if (category == 'food') return t['cuisine'] ?? t['amenity'] ?? 'Restaurant';
    if (category == 'medical') return t['amenity']?.toString() ?? 'Medical';
    return '';
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class NearbyPoiService {
  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://overpass-api.de/api',
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
  ));

  static final _geocodeDio = Dio(BaseOptions(
    baseUrl: 'https://nominatim.openstreetmap.org',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent': 'TravelConnect/1.0 (satya@berrystudio.ai)',
      'Accept-Language': 'en',
    },
  ));

  static const Map<String, PoiCategory> categories = {
    'fuel': PoiCategory(
      key: 'fuel',
      label: 'Fuel',
      emoji: '⛽',
      osmQuery: '["amenity"="fuel"]',
      colorValue: 0xFFFF6B2C,
    ),
    'stay': PoiCategory(
      key: 'stay',
      label: 'Stay',
      emoji: '🏨',
      osmQuery: '["tourism"~"hotel|guest_house|hostel|motel"]',
      colorValue: 0xFF3B82F6,
    ),
    'mechanic': PoiCategory(
      key: 'mechanic',
      label: 'Mechanic',
      emoji: '🔧',
      osmQuery: '["shop"="car_repair"]',
      colorValue: 0xFFEF4444,
    ),
    'bike': PoiCategory(
      key: 'bike',
      label: 'Bike Shop',
      emoji: '🏍️',
      osmQuery: '["shop"="motorcycle"]',
      colorValue: 0xFF8B5CF6,
    ),
    'food': PoiCategory(
      key: 'food',
      label: 'Food',
      emoji: '🍽️',
      osmQuery: '["amenity"~"restaurant|fast_food|cafe|dhaba"]',
      colorValue: 0xFF10B981,
    ),
    'medical': PoiCategory(
      key: 'medical',
      label: 'Medical',
      emoji: '🏥',
      osmQuery: '["amenity"~"hospital|clinic|pharmacy"]',
      colorValue: 0xFFEC4899,
    ),
  };

  // ── Nearby search ──────────────────────────────────────────────────────────

  static Future<List<PoiResult>> searchNearby({
    required double lat,
    required double lng,
    required String categoryKey,
    int radiusM = 10000,
    CancelToken? cancelToken,
  }) async {
    final cat = categories[categoryKey];
    if (cat == null) return [];

    final query = '''[out:json][timeout:20];
(
  node${cat.osmQuery}(around:$radiusM,${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)});
  way${cat.osmQuery}(around:$radiusM,${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)});
);
out center;''';

    try {
      final res = await _dio.post(
        '/interpreter',
        data: query,
        cancelToken: cancelToken,
        options: Options(headers: {'Content-Type': 'text/plain'}),
      );

      return _parseElements(res.data['elements'] as List? ?? [], categoryKey, lat, lng);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── On-route search ────────────────────────────────────────────────────────
  // Uses a bounding box around the route + corridor, then filters client-side.

  static Future<List<PoiResult>> searchOnRoute({
    required double currentLat,
    required double currentLng,
    required double destLat,
    required double destLng,
    required String categoryKey,
    double corridorKm = 30.0,
    CancelToken? cancelToken,
  }) async {
    final cat = categories[categoryKey];
    if (cat == null) return [];

    // Expand bbox by corridor width
    final latPad = corridorKm / 111.0;
    final avgLat  = (currentLat + destLat) / 2;
    final lngPad  = corridorKm / (111.0 * math.cos(avgLat * math.pi / 180));

    final minLat = math.min(currentLat, destLat) - latPad;
    final maxLat = math.max(currentLat, destLat) + latPad;
    final minLng = math.min(currentLng, destLng) - lngPad;
    final maxLng = math.max(currentLng, destLng) + lngPad;

    final query = '''[out:json][timeout:20];
(
  node${cat.osmQuery}($minLat,$minLng,$maxLat,$maxLng);
  way${cat.osmQuery}($minLat,$minLng,$maxLat,$maxLng);
);
out center;''';

    try {
      final res = await _dio.post(
        '/interpreter',
        data: query,
        cancelToken: cancelToken,
        options: Options(headers: {'Content-Type': 'text/plain'}),
      );

      final all = _parseElements(
          res.data['elements'] as List? ?? [], categoryKey, currentLat, currentLng);

      // Filter: only POIs ahead of current pos and within the corridor
      final onRoute = <PoiResult>[];
      for (final poi in all) {
        final t = _project(currentLat, currentLng, destLat, destLng, poi.lat, poi.lng);
        if (t <= 0.01) continue; // behind or at current position

        final projLat = currentLat + t * (destLat - currentLat);
        final projLng = currentLng + t * (destLng - currentLng);
        final perp = _haversineKm(poi.lat, poi.lng, projLat, projLng);
        if (perp > corridorKm) continue;

        final totalKm = _haversineKm(currentLat, currentLng, destLat, destLng);
        poi.distanceKm = t * totalKm;
        poi.routeProgress = t;
        onRoute.add(poi);
      }

      onRoute.sort((a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));
      return onRoute.take(15).toList();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Geocode place name → (lat, lng) ────────────────────────────────────────

  static Future<(double lat, double lng)?> geocode(String placeName) async {
    try {
      final res = await _geocodeDio.get('/search', queryParameters: {
        'q': placeName,
        'format': 'json',
        'limit': 1,
        'countrycodes': 'in',
      });
      final list = res.data as List?;
      if (list == null || list.isEmpty) return null;
      final lat = double.tryParse(list[0]['lat'].toString());
      final lng = double.tryParse(list[0]['lon'].toString());
      if (lat == null || lng == null) return null;
      return (lat, lng);
    } catch (_) {
      return null;
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static List<PoiResult> _parseElements(
      List elements, String categoryKey, double originLat, double originLng) {
    final cat = categories[categoryKey]!;
    final results = <PoiResult>[];

    for (final e in elements) {
      final elat = (e['lat'] ?? e['center']?['lat']) as num?;
      final elng = (e['lon'] ?? e['center']?['lon']) as num?;
      if (elat == null || elng == null) continue;

      final tags = Map<String, dynamic>.from(e['tags'] as Map? ?? {});
      final name = (tags['name'] ?? tags['brand'] ?? tags['operator'] ?? cat.label).toString();

      final poi = PoiResult(
        id: e['id'].toString(),
        name: name,
        lat: elat.toDouble(),
        lng: elng.toDouble(),
        category: categoryKey,
        tags: tags,
        distanceKm: _haversineKm(originLat, originLng, elat.toDouble(), elng.toDouble()),
      );
      results.add(poi);
    }

    results.sort((a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));
    return results.take(25).toList();
  }

  /// Scalar projection of point P onto segment A→B.  Returns t ∈ (-∞, +∞).
  static double _project(
    double aLat, double aLng,
    double bLat, double bLng,
    double pLat, double pLng,
  ) {
    final abLat = bLat - aLat;
    final abLng = bLng - aLng;
    final ab2   = abLat * abLat + abLng * abLng;
    if (ab2 == 0) return 0;
    return ((pLat - aLat) * abLat + (pLng - aLng) * abLng) / ab2;
  }

  static double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return R * 2 * math.asin(math.sqrt(a));
  }
}
