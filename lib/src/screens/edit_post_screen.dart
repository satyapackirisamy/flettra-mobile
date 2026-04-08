import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../widgets/network_image_widget.dart';

class EditPostScreen extends StatefulWidget {
  final dynamic post;

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController _contentController;
  final ImagePicker _imagePicker = ImagePicker();

  // Existing remote image URLs (already uploaded)
  late List<String> _existingImageUrls;
  // New locally picked images
  final List<XFile> _newImages = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.post['content'] ?? '');
    final raw = widget.post['imageUrls'];
    _existingImageUrls = raw != null ? List<String>.from(raw as List) : [];
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await _imagePicker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() => _newImages.addAll(images));
    }
  }

  void _removeExistingImage(int index) {
    setState(() => _existingImageUrls.removeAt(index));
  }

  void _removeNewImage(int index) {
    setState(() => _newImages.removeAt(index));
  }

  Future<void> _submitEdit() async {
    if (_contentController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // Upload any newly selected images
      final List<String> uploadedUrls = [];
      for (final image in _newImages) {
        final url = await ApiService().uploadImage(image);
        uploadedUrls.add(url);
      }

      final allImageUrls = [..._existingImageUrls, ...uploadedUrls];

      await ApiService().updatePost(widget.post['id'], {
        'content': _contentController.text.trim(),
        'imageUrls': allImageUrls,
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update post. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Edit Post', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF5500))),
                  )
                : FilledButton(
                    onPressed: _contentController.text.trim().isEmpty ? null : _submitEdit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5500),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: Text('Save', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    minLines: 5,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.plusJakartaSans(fontSize: 17, height: 1.6),
                    decoration: InputDecoration(
                      hintText: "What's on your mind?",
                      hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey[400], fontSize: 17),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  // Existing images
                  if (_existingImageUrls.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Current photos', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _existingImageUrls.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image(
                                    image: networkImageProvider(ApiService.getFullImageUrl(_existingImageUrls[index])),
                                    width: 140,
                                    height: 140,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 140, height: 140,
                                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(16)),
                                      child: const Icon(Icons.broken_image, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 6, right: 6,
                                  child: GestureDetector(
                                    onTap: () => _removeExistingImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  // Newly picked images
                  if (_newImages.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('New photos', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _newImages.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: FutureBuilder<Uint8List>(
                                    future: _newImages[index].readAsBytes(),
                                    builder: (context, snap) {
                                      if (!snap.hasData) {
                                        return Container(
                                          width: 140, height: 140,
                                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                        );
                                      }
                                      return Image.memory(snap.data!, width: 140, height: 140, fit: BoxFit.cover);
                                    },
                                  ),
                                ),
                                Positioned(
                                  top: 6, right: 6,
                                  child: GestureDetector(
                                    onTap: () => _removeNewImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Bottom toolbar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            padding: EdgeInsets.only(
              left: 12, right: 12, top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            child: Row(
              children: [
                _toolbarButton(Icons.photo_library_rounded, 'Add Photos', _pickImages),
                if (_newImages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFFF5500).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text('+${_newImages.length} new',
                        style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFF5500), fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbarButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFFF5500), size: 22),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.grey[700], fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
