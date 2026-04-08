import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../widgets/network_image_widget.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() => _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _users = [];
  bool _isLoading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getAdminUsers(search: _search);
      setState(() {
        _users = response.data['users'];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove User'),
        content: const Text('Are you sure you want to delete this user? This action is permanent.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteUser(id);
        _loadUsers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove user: $e')),
          );
        }
      }
    }
  }

  Future<void> _updateSubscription(String userId, String currentPlan) async {
    String? selectedPlan = currentPlan;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Subscription'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPlanTile('free', 'Free Tier', selectedPlan, (p) => setDialogState(() => selectedPlan = p)),
              _buildPlanTile('basic', 'Basic Tier', selectedPlan, (p) => setDialogState(() => selectedPlan = p)),
              _buildPlanTile('premium', 'Premium Tier', selectedPlan, (p) => setDialogState(() => selectedPlan = p)),
              _buildPlanTile('enterprise', 'Enterprise Tier', selectedPlan, (p) => setDialogState(() => selectedPlan = p)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && selectedPlan != null) {
      try {
        await _apiService.subscribeToPlan(userId, selectedPlan!, DateTime.now().add(const Duration(days: 30)));
        _loadUsers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update subscription: $e')),
          );
        }
      }
    }
  }

  Widget _buildPlanTile(String id, String label, String? selectedPlan, Function(String) onTap) {
    final isSelected = selectedPlan == id;
    return ListTile(
      onTap: () => onTap(id),
      leading: Radio<String>(
        value: id,
        groupValue: selectedPlan,
        onChanged: (v) => onTap(v!),
        activeColor: const Color(0xFF4F46E5),
      ),
      title: Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Platform Users'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFEDF2F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                onChanged: (val) {
                  _search = val;
                  _loadUsers();
                },
                decoration: InputDecoration(
                  hintText: 'Search by name or email',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUsers,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final user = _users[index];
                  return _buildUserTile(user);
                },
              ),
            ),
    );
  }

  Widget _buildUserTile(dynamic user) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1),
          backgroundImage: networkImageProvider(ApiService.getAvatarUrl(user['profilePicture'], name: user['name'] ?? 'U')),
          child: null,
        ),
        title: Text(
          user['name'] ?? 'No Name',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email'] ?? 'No email', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildRoleBadge(user['role']),
                const SizedBox(width: 8),
                _buildPlanBadge(user['subscriptionPlan']),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') _deleteUser(user['id']);
            if (value == 'subscription') _updateSubscription(user['id'], user['subscriptionPlan'] ?? 'free');
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'subscription', child: Text('Update Subscription')),
            const PopupMenuItem(value: 'delete', child: Text('Delete User', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String? role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(
        role?.toUpperCase() ?? 'USER',
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue),
      ),
    );
  }

  Widget _buildPlanBadge(String? plan) {
    Color planColor;
    switch (plan) {
      case 'premium': planColor = Colors.purple; break;
      case 'basic': planColor = Colors.green; break;
      default: planColor = Colors.grey; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: planColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(
        plan?.toUpperCase() ?? 'FREE',
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: planColor),
      ),
    );
  }
}
