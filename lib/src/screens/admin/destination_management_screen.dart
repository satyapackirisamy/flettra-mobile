import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../widgets/network_image_widget.dart';
import 'destination_form_screen.dart';

class AdminDestinationManagementScreen extends StatefulWidget {
  const AdminDestinationManagementScreen({super.key});

  @override
  State<AdminDestinationManagementScreen> createState() => _AdminDestinationManagementScreenState();
}

class _AdminDestinationManagementScreenState extends State<AdminDestinationManagementScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _destinations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDestinations();
  }

  Future<void> _loadDestinations() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getDestinations();
      setState(() {
        _destinations = response.data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load destinations: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDestination(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Destination'),
        content: const Text('Are you sure you want to delete this destination?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteDestination(id);
        _loadDestinations();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete destination: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Travel Hotspots'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminDestinationFormScreen()),
              );
              if (result == true) _loadDestinations();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDestinations,
              child: _destinations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No destinations created yet',
                            style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontSize: 16),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AdminDestinationFormScreen()),
                              );
                              if (result == true) _loadDestinations();
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Destination'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: _destinations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final dest = _destinations[index];
                        return _buildDestinationCard(dest);
                      },
                    ),
            ),
    );
  }

  Widget _buildDestinationCard(dynamic dest) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: (dest['imageUrl'] != null && dest['imageUrl'].toString().isNotEmpty)
                ? SafeNetworkImage(
                    url: dest['imageUrl'],
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 160,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: Icon(Icons.image_not_supported_outlined, color: Colors.grey[400], size: 48),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        dest['name'] ?? 'Untitled',
                        style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    _buildActiveBadge(dest['isActive'] ?? true),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      dest['location'] ?? 'Global',
                      style: GoogleFonts.plusJakartaSans(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  dest['description'] ?? 'No description provided.',
                  style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontSize: 13, height: 1.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AdminDestinationFormScreen(destination: dest)),
                          );
                          if (result == true) _loadDestinations();
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteDestination(dest['id']),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: isActive ? Colors.green : Colors.red,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
