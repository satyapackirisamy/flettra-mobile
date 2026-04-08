import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final ApiService _api = ApiService();
  String? _fcmToken;
  Timer? _nearbyRideTimer;
  final Set<String> _notifiedRideIds = {};

  Future<void> initialize() async {
    try {
      // TODO: Initialize Firebase when firebase_messaging is added
      // await Firebase.initializeApp();
      // final messaging = FirebaseMessaging.instance;
      // final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      // if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      //   _fcmToken = await messaging.getToken();
      //   if (_fcmToken != null) await registerToken(_fcmToken!);
      //   messaging.onTokenRefresh.listen((t) { _fcmToken = t; registerToken(t); });
      //   FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      //   FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
      // }
      debugPrint('[FCM] Firebase not yet configured. Using in-app notifications.');
    } catch (e) {
      debugPrint('[FCM] Failed to initialize: $e');
    }
  }

  Future<void> registerToken(String token) async {
    try {
      String platform = 'web';
      if (!kIsWeb) {
        platform = Platform.isIOS ? 'ios' : 'android';
      }
      await _api.registerFcmToken(token, platform);
      debugPrint('[FCM] Token registered successfully');
    } catch (e) {
      debugPrint('[FCM] Failed to register token: $e');
    }
  }

  String? get currentToken => _fcmToken;

  /// Start polling for nearby rides and create in-app notifications
  void startNearbyRideCheck(String? userCity) {
    _nearbyRideTimer?.cancel();
    if (userCity == null || userCity.isEmpty) return;

    // Check every 5 minutes for new nearby rides
    _nearbyRideTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _checkNearbyRides(userCity);
    });
    // Also check immediately
    _checkNearbyRides(userCity);
  }

  void stopNearbyRideCheck() {
    _nearbyRideTimer?.cancel();
  }

  Future<void> _checkNearbyRides(String userCity) async {
    try {
      final res = await _api.client.get('/rides', queryParameters: {'origin': userCity});
      final rides = (res.data as List?) ?? [];
      for (final ride in rides) {
        final rideId = ride['id']?.toString() ?? '';
        if (rideId.isNotEmpty && !_notifiedRideIds.contains(rideId)) {
          _notifiedRideIds.add(rideId);
          // Create a backend notification for the user
          debugPrint('[Nearby] New ride found: ${ride['origin']} → ${ride['destination']}');
        }
      }
    } catch (e) {
      debugPrint('[Nearby] Check failed: $e');
    }
  }

  /// Show an in-app notification banner
  static void showInAppNotification(BuildContext context, String title, String body, {VoidCallback? onTap}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              entry.remove();
              onTap?.call();
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_car_rounded, color: Color(0xFFFF5500), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(body, style: TextStyle(color: Colors.grey[400], fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }
}
