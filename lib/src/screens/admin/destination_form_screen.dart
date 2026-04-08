import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';

class AdminDestinationFormScreen extends StatefulWidget {
  final Map<String, dynamic>? destination;
  const AdminDestinationFormScreen({super.key, this.destination});

  @override
  State<AdminDestinationFormScreen> createState() => _AdminDestinationFormScreenState();
}

class _AdminDestinationFormScreenState extends State<AdminDestinationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;
  bool _isActive = true;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.destination?['name']);
    _locationController = TextEditingController(text: widget.destination?['location']);
    _descriptionController = TextEditingController(text: widget.destination?['description']);
    _imageUrlController = TextEditingController(text: widget.destination?['imageUrl']);
    _isActive = widget.destination?['isActive'] ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final uploadUrl = await _apiService.uploadImage(image);
      setState(() {
        _imageUrlController.text = uploadUrl;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image uploaded successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final data = {
      'name': _nameController.text.trim(),
      'location': _locationController.text.trim(),
      'description': _descriptionController.text.trim(),
      'imageUrl': _imageUrlController.text.trim(),
      'isActive': _isActive,
    };

    try {
      if (widget.destination != null) {
        await _apiService.updateDestination(widget.destination!['id'], data);
      } else {
        await _apiService.createDestination(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save destination: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.destination != null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Destination' : 'New Destination'),
        actions: [
          _isLoading 
            ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5))))) 
            : TextButton(
                onPressed: _handleSave,
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4F46E5))),
              ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInputLabel('Destination Name'),
              _buildInputField(
                controller: _nameController,
                hint: 'e.g., Meghalaya',
                validator: (v) => v!.isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 24),

              _buildInputLabel('Location'),
              _buildInputField(
                controller: _locationController,
                hint: 'e.g., North East India',
              ),
              const SizedBox(height: 24),

              _buildInputLabel('Image URL'),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      controller: _imageUrlController,
                      hint: 'https://images.unsplash.com/...',
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _pickAndUploadImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isUploading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                        : const Icon(Icons.upload_file_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_imageUrlController.text.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    _imageUrlController.text,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 180,
                      color: Colors.grey[100],
                      child: const Center(child: Text('Invalid image URL')),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              _buildInputLabel('Description'),
              _buildInputField(
                controller: _descriptionController,
                hint: 'Write about this destination...',
                maxLines: 5,
              ),
              const SizedBox(height: 32),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Active hotspot', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                subtitle: Text('Should this appear on user home screen', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                activeColor: const Color(0xFF4F46E5),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      onChanged: (v) {
        if (controller == _imageUrlController) setState(() {});
      },
      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
      ),
    );
  }
}
