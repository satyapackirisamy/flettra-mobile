import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    if (data['access_token'] != null) {
      await _storage.write(key: 'jwt_token', value: data['access_token']);
    }
    if (data['refresh_token'] != null) {
      await _storage.write(key: 'refresh_token', value: data['refresh_token']);
    }
  }

  // Returns the user map from the login response — no second getUser() call needed
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _apiService.client.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final body = response.data as Map<String, dynamic>;
    await _saveTokens(body);
    return (body['user'] as Map<String, dynamic>?) ?? {};
  }

  Future<void> register(Map<String, dynamic> data) async {
    final response = await _apiService.client.post('/auth/register', data: data);
    await _saveTokens(response.data as Map<String, dynamic>);
  }

  Future<void> sendOtp(String identifier) async {
    await _apiService.client.post('/auth/send-otp', data: {
      'identifier': identifier,
    });
  }

  Future<void> verifyOtp(String identifier, String code, {Map<String, dynamic>? registrationData}) async {
    final response = await _apiService.client.post('/auth/verify-otp', data: {
      'identifier': identifier,
      'code': code,
      if (registrationData != null) 'registrationData': registrationData,
    });
    await _saveTokens(response.data as Map<String, dynamic>);
  }

  Future<bool> refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      final response = await _apiService.client.post('/auth/refresh', data: {
        'refreshToken': refreshToken,
      });
      await _saveTokens(response.data as Map<String, dynamic>);
      return true;
    } catch (e) {
      debugPrint('[Auth] Token refresh failed: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken != null) {
        await _apiService.client.post('/auth/logout', data: {'refreshToken': refreshToken});
      }
    } catch (_) {}
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<bool> isAuthenticated() async {
    final token = await _storage.read(key: 'jwt_token');
    return token != null;
  }

  Future<Map<String, dynamic>> getUser() async {
    final response = await _apiService.client.get('/users/profile');
    return response.data;
  }
}
