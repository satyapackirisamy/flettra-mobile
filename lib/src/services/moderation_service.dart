import 'package:dio/dio.dart';
import 'api_service.dart';

class ModerationService {
  static final _api = ApiService();

  // ── Block ──────────────────────────────────────────────────────────────────

  static Future<void> blockUser(String userId) async {
    await _api.client.post('/moderation/block/$userId');
  }

  static Future<void> unblockUser(String userId) async {
    await _api.client.delete('/moderation/block/$userId');
  }

  static Future<bool> isBlocked(String userId) async {
    try {
      final res = await _api.client.get('/moderation/block/$userId');
      final data = res.data is Map ? res.data['data'] : res.data;
      return data == true;
    } catch (_) {
      return false;
    }
  }

  // ── Mute ───────────────────────────────────────────────────────────────────

  static Future<void> muteUser(String userId) async {
    await _api.client.post('/moderation/mute/$userId');
  }

  static Future<void> unmuteUser(String userId) async {
    await _api.client.delete('/moderation/mute/$userId');
  }

  static Future<bool> isMuted(String userId) async {
    try {
      final res = await _api.client.get('/moderation/mute/$userId');
      final data = res.data is Map ? res.data['data'] : res.data;
      return data == true;
    } catch (_) {
      return false;
    }
  }

  // ── Report ─────────────────────────────────────────────────────────────────

  static Future<void> reportPost(
    String postId, {
    required String reason,
    String? details,
  }) async {
    await _api.client.post(
      '/moderation/report/post/$postId',
      data: {'reason': reason, if (details != null) 'details': details},
    );
  }
}
