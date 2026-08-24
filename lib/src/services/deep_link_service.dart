import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../screens/ride_details_screen.dart';
import '../services/api_service.dart';
import '../utils/deep_links.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/motion.dart';

/// Routes incoming deep links to a screen.
///
/// Handles both the cold-start link (the app was launched by the link) and
/// links that arrive while the app is already running.
///
/// A ride link carries a *share token*, not a ride id, so the token is resolved
/// through the public `GET /rides/share/:token` endpoint before navigating. If
/// the link arrives before the navigator is ready — which is the normal case on
/// a cold start — it is held in [_pending] and drained on a later frame.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  GlobalKey<NavigatorState>? _navigatorKey;
  DeepLink? _pending;
  bool _started = false;

  /// Begins listening. Safe to call more than once.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Links that arrive while the app is running.
    _sub = _appLinks.uriLinkStream.listen(
      _handle,
      onError: (Object e) => debugPrint('[DeepLink] stream error: $e'),
    );

    // The link that launched the app, if any.
    try {
      _handle(await _appLinks.getInitialLink());
    } catch (e) {
      debugPrint('[DeepLink] initial link failed: $e');
    }
  }

  /// Supplies the navigator and replays anything that arrived before it existed.
  void attach(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
    _drainWhenReady();
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }

  void _handle(Uri? uri) {
    if (uri == null) return;
    final link = parseDeepLink(uri);
    if (link == null) {
      debugPrint('[DeepLink] ignoring unrecognised link: $uri');
      return;
    }
    if (_navigatorKey?.currentState == null) {
      // Cold start: the key is set in initState but the NavigatorState does not
      // exist until the first frame is built, and getInitialLink() can resolve
      // before that. Parking the link in _pending is only half the answer —
      // attach() has already run by then, so nothing would replay it. Drain on
      // the next frame instead, retrying until the navigator appears.
      _pending = link;
      _drainWhenReady();
      return;
    }
    _navigate(link);
  }

  /// Retries the pending link once per frame until a navigator exists.
  ///
  /// Bounded so a link that arrives while the app is being torn down cannot
  /// schedule frames forever.
  void _drainWhenReady([int attempt = 0]) {
    if (_pending == null || attempt > 60) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final link = _pending;
      if (link == null) return;
      if (_navigatorKey?.currentState == null) {
        _drainWhenReady(attempt + 1);
        return;
      }
      _pending = null;
      _navigate(link);
    });
  }

  Future<void> _navigate(DeepLink link) async {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      _pending = link;
      _drainWhenReady();
      return;
    }

    switch (link.kind) {
      case DeepLinkKind.ride:
        await _openRide(navigator, link.value);
    }
  }

  Future<void> _openRide(NavigatorState navigator, String token) async {
    try {
      // Public endpoint — resolves a share token to the full ride, so this
      // works before the person has signed in.
      final res = await ApiService().client.get('/rides/share/$token');
      final rideId = (res.data is Map ? res.data['id'] : null)?.toString();
      if (rideId == null || rideId.isEmpty) {
        _reportUnavailable(navigator);
        return;
      }
      await navigator.push(fadeThroughRoute(RideDetailsScreen(rideId: rideId)));
    } catch (e) {
      debugPrint('[DeepLink] could not resolve share token: $e');
      _reportUnavailable(navigator);
    }
  }

  void _reportUnavailable(NavigatorState navigator) {
    final context = navigator.context;
    showError(context, 'That ride link is no longer available.');
  }
}
