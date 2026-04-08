import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../widgets/network_image_widget.dart' as img_helper;

class ApiService {
  late Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Set via: flutter run --dart-define=API_URL=http://192.168.x.x:3000
  // Production builds use https://api.flettra.com by default
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://api.flettra.com',
  );

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        // Unwrap { success, data, timestamp } envelope from backend
        if (response.data is Map && response.data['success'] != null && response.data.containsKey('data')) {
          response.data = response.data['data'];
        }
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        // Auto-refresh token on 401
        if (e.response?.statusCode == 401 && !e.requestOptions.path.contains('/auth/')) {
          try {
            final refreshToken = await _storage.read(key: 'refresh_token');
            if (refreshToken != null) {
              final refreshRes = await Dio(BaseOptions(baseUrl: baseUrl)).post(
                '/auth/refresh',
                data: {'refreshToken': refreshToken},
              );
              final newData = refreshRes.data;
              // Unwrap envelope if present
              final payload = (newData is Map && newData['success'] != null && newData.containsKey('data')) ? newData['data'] : newData;
              if (payload['access_token'] != null) {
                await _storage.write(key: 'jwt_token', value: payload['access_token']);
                if (payload['refresh_token'] != null) {
                  await _storage.write(key: 'refresh_token', value: payload['refresh_token']);
                }
                // Retry the original request
                final opts = e.requestOptions;
                opts.headers['Authorization'] = 'Bearer ${payload['access_token']}';
                final retryRes = await _dio.fetch(opts);
                return handler.resolve(retryRes);
              }
            }
          } catch (_) {}
        }
        return handler.next(e);
      },
    ));
  }

  Dio get client => _dio;

  // Profile
  Future<Response> getProfile() => _dio.get('/users/profile');
  Future<Response> updateProfile(Map<String, dynamic> data) => _dio.patch('/users/profile', data: data);
  
  // Buddies
  Future<Response> getBuddies() => _dio.get('/users/buddies');
  Future<Response> getBuddyRequests() => _dio.get('/users/buddies/requests');
  Future<Response> sendBuddyRequest(String id) => _dio.post('/users/buddies/requests/$id');
  Future<Response> acceptBuddyRequest(String requestId) => _dio.post('/users/buddies/requests/$requestId/accept');
  Future<Response> rejectBuddyRequest(String requestId) => _dio.post('/users/buddies/requests/$requestId/reject');
  Future<Response> searchUsers(String query) => _dio.get('/users/search', queryParameters: {'location': query});

  // Rides
  Future<Response> getRideDetails(String id) => _dio.get('/rides/$id');
  Future<Response> requestJoinRide(String id) => _dio.post('/rides/$id/request');
  Future<Response> getRideRequests(String id) => _dio.get('/rides/$id/requests');
  Future<Response> getMyRequestForRide(String rideId) => _dio.get('/rides/my-request/$rideId');
  Future<Response> handleRideRequest(String requestId, String status) => _dio.post('/rides/requests/$requestId/respond', data: {'status': status});
  Future<Response> getMyRides() => _dio.get('/rides/my-rides');
  
  // Ride Lifecycle
  Future<Response> startRide(String id) => _dio.post('/rides/$id/start');
  Future<Response> completeRide(String id) => _dio.post('/rides/$id/complete');
  Future<Response> cancelRide(String id) => _dio.post('/rides/$id/cancel');
  Future<Response> pauseRide(String id) => _dio.post('/rides/$id/pause');
  Future<Response> resumeRide(String id) => _dio.post('/rides/$id/resume');
  Future<Response> resetRide(String id) => _dio.post('/rides/$id/reset');
  Future<Response> deleteRide(String id) => _dio.delete('/rides/$id');

  // Groups
  Future<Response> getGroups() => _dio.get('/groups');
  Future<Response> getMyGroups() => _dio.get('/groups/my-groups');
  Future<Response> getGroupDetails(String id) => _dio.get('/groups/$id');
  Future<Response> createGroup(Map<String, dynamic> data) => _dio.post('/groups', data: data);
  Future<Response> joinGroup(String id) => _dio.post('/groups/$id/join');
  Future<Response> respondToGroupRequest(String groupId, String requestId, String status) => _dio.put('/groups/requests/$requestId', data: {'status': status});

  // Chat
  Future<Response> getRideMessages(String rideId) => _dio.get('/chat/ride/$rideId');
  Future<Response> getBuddyMessages(String buddyId) => _dio.get('/chat/buddy/$buddyId');
  Future<Response> getGroupMessages(String groupId) => _dio.get('/chat/group/$groupId');

  // Expenses
  Future<Response> getExpenses(String rideId) => _dio.get('/expenses/ride/$rideId');
  Future<Response> getBalances(String rideId) => _dio.get('/expenses/ride/$rideId/balance');

  // Timeline
  Future<Response> getGlobalTimeline() => _dio.get('/timeline/global');
  Future<Response> getFriendsTimeline() => _dio.get('/timeline/friends');
  Future<Response> createPost(Map<String, dynamic> data) => _dio.post('/timeline', data: data);
  Future<Response> updatePost(String id, Map<String, dynamic> data) => _dio.patch('/timeline/$id', data: data);
  Future<Response> deletePost(String id) => _dio.delete('/timeline/$id');
  Future<Response> likePost(String id) => _dio.post('/timeline/$id/like');

  // Admin
  Future<Response> getAdminStats() => _dio.get('/admin/dashboard/stats');
  Future<Response> getAdminUsers({int page = 1, int limit = 20, String? search}) => _dio.get('/admin/users', queryParameters: {'page': page, 'limit': limit, if (search != null) 'search': search});
  Future<Response> deleteUser(String id) => _dio.delete('/admin/users/$id');
  Future<Response> getAdminVendors({int page = 1, int limit = 20, String? type}) => _dio.get('/admin/vendors', queryParameters: {'page': page, 'limit': limit, if (type != null) 'type': type});
  Future<Response> deleteVendor(String id) => _dio.delete('/admin/vendors/$id');
  Future<Response> getAdminRides({int page = 1, int limit = 20}) => _dio.get('/admin/rides', queryParameters: {'page': page, 'limit': limit});
  Future<Response> deleteAdminRide(String id) => _dio.delete('/admin/rides/$id');
  Future<Response> subscribeToPlan(String userId, String planName, DateTime expiry) => _dio.put('/admin/users/$userId/subscription', data: {'plan': planName, 'expiryDate': expiry.toIso8601String()});

  // Destinations
  Future<Response> getDestinations() => _dio.get('/destinations');
  Future<Response> getDestinationDetails(String id) => _dio.get('/destinations/$id');
  Future<Response> createDestination(Map<String, dynamic> data) => _dio.post('/destinations', data: data);
  Future<Response> updateDestination(String id, Map<String, dynamic> data) => _dio.put('/destinations/$id', data: data);
  Future<Response> deleteDestination(String id) => _dio.delete('/destinations/$id');

  // Analytics
  Future<Response> getMyAnalytics() => _dio.get('/analytics/me');
  Future<Response> getLeaderboard() => _dio.get('/analytics/leaderboard');

  // Ratings
  Future<Response> createRating(Map<String, dynamic> data) => _dio.post('/ratings', data: data);
  Future<Response> getRideRatings(String rideId) => _dio.get('/ratings/ride/$rideId');
  Future<Response> getUserRating(String userId) => _dio.get('/ratings/user/$userId');

  // Payments & Subscriptions
  Future<Response> getSubscriptionPlans() => _dio.get('/payments/plans');
  Future<Response> getMySubscription() => _dio.get('/payments/subscription');
  Future<Response> createPaymentOrder(String planId) => _dio.post('/payments/create-order', data: {'planId': planId});
  Future<Response> verifyPayment(Map<String, dynamic> data) => _dio.post('/payments/verify', data: data);

  // Shared Rides
  Future<Response> getSharedRide(String token) => _dio.get('/rides/share/$token');

  // FCM Token
  Future<Response> registerFcmToken(String token, String platform) => _dio.post('/notifications/register-token', data: {'token': token, 'platform': platform});

  // Onboarding
  Future<Response> completeOnboarding() => _dio.patch('/users/onboarding/complete');

  // Ride with GPS
  Future<Response> startRideWithGps(String id, {double? lat, double? lng}) => _dio.post('/rides/$id/start', data: {if (lat != null) 'lat': lat, if (lng != null) 'lng': lng});
  Future<Response> completeRideWithGps(String id, {double? lat, double? lng}) => _dio.post('/rides/$id/complete', data: {if (lat != null) 'lat': lat, if (lng != null) 'lng': lng});

  static const String _placeholderImage = 'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?q=80&w=800';
  static const String _placeholderAvatar = 'https://ui-avatars.com/api/?background=4F46E5&color=fff&size=128&name=U';

  // Helper for all network images — always returns an absolute URL
  static String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return _placeholderImage;
    if (path.startsWith('http')) return path;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return "$baseUrl$cleanPath";
  }

  // Returns an ImageProvider that uses <img> element on web to bypass CanvasKit CORS issues.
  static ImageProvider networkImageProvider(String url) => img_helper.networkImageProvider(url);

  // Helper for user avatars — falls back to generated initials avatar
  static String getAvatarUrl(String? path, {String name = 'U'}) {
    if (path == null || path.isEmpty) {
      final encoded = Uri.encodeComponent(name.isNotEmpty ? name : 'U');
      return 'https://ui-avatars.com/api/?background=4F46E5&color=fff&size=128&name=$encoded';
    }
    if (path.startsWith('http')) return path;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return "$baseUrl$cleanPath";
  }

  Future<String> uploadImage(dynamic xFile) async {
    String fileName = xFile.name;
    final bytes = await xFile.readAsBytes();
    FormData formData = FormData.fromMap({
      "file": MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final response = await _dio.post('/uploads', data: formData);
    return getFullImageUrl(response.data['url']);
  }
}
