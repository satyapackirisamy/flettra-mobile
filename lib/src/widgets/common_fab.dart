import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../screens/create_post_screen.dart';
import '../screens/create_ride_screen.dart';
import '../screens/buddies_screen.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';

class CommonFab extends StatelessWidget {
  final VoidCallback? onPostCreated;
  final VoidCallback? onRideCreated;

  const CommonFab({
    super.key, 
    this.onPostCreated,
    this.onRideCreated,
  });

  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, 
                height: 4, 
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))
              ),
            ),
            const SizedBox(height: 24),
            Text("Create New", style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
            const SizedBox(height: 24),
            _buildOptionTile(
              context, 
              "Post", 
              "Share an update", 
              Icons.edit_note_rounded, 
              const Color(0xFF4F46E5),
              const Color(0xFFEFF6FF),
              () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostScreen()))
                    .then((_) => onPostCreated?.call());
              }
            ),
            const SizedBox(height: 16),
            _buildOptionTile(
              context, 
              "Ride",
              "Create a new ride", 
              Icons.directions_car_rounded, 
              const Color(0xFFFF5500),
              const Color(0xFFFFF1EB),
               () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRideScreen()))
                    .then((_) => onRideCreated?.call());
              }
            ),
            const SizedBox(height: 16),
            _buildOptionTile(
              context, 
              "Buddy", 
              "Find travel buddies", 
              Icons.person_add_rounded, 
              Colors.teal,
              const Color(0xFFECFDF5),
               () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BuddiesScreen()));
              }
            ),
            const SizedBox(height: 16),
            _buildOptionTile(
              context,
              "Group",
              "Start a new group",
              Icons.groups_rounded,
              Colors.pink,
              const Color(0xFFFFF1F5),
               () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (ctx) {
                    final nameController = TextEditingController();
                    final descController = TextEditingController();
                    bool isPrivate = false;
                    return StatefulBuilder(
                      builder: (ctx, setDialogState) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        title: const Text('Create Group', style: TextStyle(fontWeight: FontWeight.w900)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(hintText: 'Group name', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: descController,
                              decoration: const InputDecoration(hintText: 'Description (optional)', border: OutlineInputBorder()),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              title: const Text('Private Group', style: TextStyle(fontWeight: FontWeight.w700)),
                              value: isPrivate,
                              onChanged: (v) => setDialogState(() => isPrivate = v),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () async {
                              if (nameController.text.trim().isEmpty) return;
                              try {
                                await ApiService().createGroup({
                                  'name': nameController.text.trim(),
                                  'description': descController.text.trim(),
                                  'isPrivate': isPrivate,
                                });
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  showSuccess(context, 'Group created!');
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  showError(ctx, 'Failed to create group');
                                }
                              }
                            },
                            child: const Text('Create'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(BuildContext context, String title, String subtitle, IconData icon, Color color, Color bgColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[100]!),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF1E293B))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.plusJakartaSans(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCreateOptions(context),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFFFF5500),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: const Color(0xFFFF5500).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
      ),
    );
  }
}
