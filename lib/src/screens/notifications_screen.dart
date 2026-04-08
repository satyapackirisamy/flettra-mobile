import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'ride_details_screen.dart';
import 'buddies_screen.dart';
import 'group_details_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final response = await _apiService.client.get('/notifications');
      setState(() {
        _notifications = (response.data as List?) ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await _apiService.client.post('/notifications/$id/read');
      _fetchNotifications();
    } catch (_) {}
  }

  void _handleAction(Map<String, dynamic> n) {
    _markRead(n['id']);
    final type = n['type'] ?? '';
    final relatedId = n['relatedId'];
    final title = (n['title'] ?? '').toString().toLowerCase();
    final message = (n['message'] ?? '').toString().toLowerCase();

    if (relatedId == null) return;

    // Determine if this is a group notification by checking title/message
    final isGroupNotification = title.contains('group') || message.contains('group') ||
        title.contains('join') && !title.contains('ride');

    if (type == 'buddy_request' || type == 'buddy_accepted') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const BuddiesScreen()));
    } else if (isGroupNotification) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => GroupDetailsScreen(groupId: relatedId)));
    } else if (type == 'ride_request' || type == 'ride_joined' || type == 'ride_accepted' ||
               type == 'ride_cancelled' || type == 'ride_completed' || type == 'ride_started') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailsScreen(rideId: relatedId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Notifications', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: () async {
              await _apiService.client.post('/notifications/read-all');
              _fetchNotifications();
            },
            child: Text('Mark all read', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFF5500), fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5500)))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none_rounded, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No notifications yet', style: GoogleFonts.plusJakartaSans(color: Colors.grey[400], fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  color: const Color(0xFFFF5500),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final isUnread = n['isRead'] != true;
                      final iconInfo = _getIconForType(n);

                      return GestureDetector(
                        onTap: () => _handleAction(n),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isUnread ? const Color(0xFFFFF7ED) : const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(16),
                            border: isUnread ? Border.all(color: const Color(0xFFFFEDD5)) : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: iconInfo.bgColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(iconInfo.icon, color: iconInfo.iconColor, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n['title'] ?? '',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      n['message'] ?? '',
                                      style: GoogleFonts.plusJakartaSans(color: Colors.grey[600], fontSize: 12, height: 1.3),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (isUnread)
                                Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(color: Color(0xFFFF5500), shape: BoxShape.circle),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  _NotifIcon _getIconForType(Map<String, dynamic> n) {
    final type = n['type'] ?? '';
    final title = (n['title'] ?? '').toString().toLowerCase();

    // Group notifications
    if (title.contains('group') || title.contains('join') && !title.contains('ride')) {
      return _NotifIcon(Icons.groups_rounded, const Color(0xFF7C3AED), const Color(0xFFF3E8FF));
    }

    switch (type) {
      case 'buddy_request':
        return _NotifIcon(Icons.person_add_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF));
      case 'buddy_accepted':
        return _NotifIcon(Icons.people_rounded, const Color(0xFF059669), const Color(0xFFECFDF5));
      case 'ride_request':
        return _NotifIcon(Icons.front_hand_rounded, const Color(0xFFFF5500), const Color(0xFFFFF3E0));
      case 'ride_joined':
        return _NotifIcon(Icons.person_add_alt_1_rounded, const Color(0xFF059669), const Color(0xFFECFDF5));
      case 'ride_accepted':
        return _NotifIcon(Icons.check_circle_rounded, const Color(0xFF059669), const Color(0xFFECFDF5));
      case 'ride_cancelled':
        return _NotifIcon(Icons.cancel_rounded, const Color(0xFFDC2626), const Color(0xFFFEF2F2));
      case 'ride_completed':
        return _NotifIcon(Icons.flag_rounded, const Color(0xFFFF5500), const Color(0xFFFFF3E0));
      case 'ride_started':
        return _NotifIcon(Icons.play_circle_rounded, const Color(0xFF059669), const Color(0xFFECFDF5));
      case 'rating_received':
        return _NotifIcon(Icons.star_rounded, const Color(0xFFFBBF24), const Color(0xFFFFFBEB));
      case 'payment':
        return _NotifIcon(Icons.payment_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF));
      default:
        return _NotifIcon(Icons.notifications_rounded, Colors.grey, const Color(0xFFF8F9FA));
    }
  }
}

class _NotifIcon {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  const _NotifIcon(this.icon, this.iconColor, this.bgColor);
}
