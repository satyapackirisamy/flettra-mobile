import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class AdminVendorManagementScreen extends StatefulWidget {
  const AdminVendorManagementScreen({super.key});

  @override
  State<AdminVendorManagementScreen> createState() => _AdminVendorManagementScreenState();
}

class _AdminVendorManagementScreenState extends State<AdminVendorManagementScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _vendors = [];
  bool _isLoading = true;
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    _loadVendors();
  }

  Future<void> _loadVendors() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getAdminVendors(type: _selectedType);
      setState(() {
        _vendors = response.data['vendors'];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load vendors: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteVendor(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vendor'),
        content: const Text('Are you sure you want to remove this vendor? This action cannot be undone.'),
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
        await _apiService.deleteVendor(id);
        _loadVendors();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete vendor: $e')),
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
        title: const Text('Manage Vendors'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip(null, 'All'),
                _buildFilterChip('hotel', 'Hotels'),
                _buildFilterChip('houseboat', 'Houseboats'),
                _buildFilterChip('restaurant', 'Restaurants'),
                _buildFilterChip('activity', 'Activities'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadVendors,
              child: _vendors.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.storefront_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No vendors found',
                            style: GoogleFonts.plusJakartaSans(fontSize: 18, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _vendors.length,
                      itemBuilder: (context, index) {
                        final vendor = _vendors[index];
                        return _buildVendorCard(vendor);
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add Vendor Logic
        },
        backgroundColor: const Color(0xFF10B981),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterChip(String? type, String label) {
    final isSelected = _selectedType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (selected) {
          setState(() {
            _selectedType = type;
            _loadVendors();
          });
        },
        selectedColor: const Color(0xFF10B981).withOpacity(0.2),
        checkmarkColor: const Color(0xFF10B981),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: isSelected ? const Color(0xFF065F46) : const Color(0xFF64748B),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildVendorCard(dynamic vendor) {
    return Card(
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
              child: const Icon(Icons.business_rounded, color: Color(0xFF10B981)),
            ),
            title: Text(
              vendor['name'] ?? 'Unknown Vendor',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(vendor['location'] ?? 'No location'),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    vendor['type']?.toString().toUpperCase() ?? 'OTHER',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') _deleteVendor(vendor['id']);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₹${vendor['price'] ?? 0} / night',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5)),
                ),
                Switch.adaptive(
                  value: vendor['isActive'] ?? true,
                  onChanged: (val) {
                    // Update Active Status
                  },
                  activeColor: const Color(0xFF10B981),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
