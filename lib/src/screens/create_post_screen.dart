import 'package:flutter/foundation.dart';
import '../theme/flettra_colors.dart';
import '../theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class CreatePostScreen extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  const CreatePostScreen({super.key, this.currentUser});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {

  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _selectedImages = [];
  bool _isLoading = false;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    if (widget.currentUser != null) {
      _profile = widget.currentUser;
    } else {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    try {
      final res = await ApiService().getProfile();
      if (mounted) setState(() => _profile = res.data as Map<String, dynamic>?);
    } catch (_) {}
  }

  bool get _canPost => _contentController.text.trim().isNotEmpty;

  Future<void> _pickImages() async {
    final images = await _imagePicker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() => _selectedImages.addAll(images));
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _submitPost() async {
    if (!_canPost) return;
    setState(() => _isLoading = true);
    try {
      final List<String> imageUrls = [];
      for (final image in _selectedImages) {
        final url = await ApiService().uploadImage(image);
        imageUrls.add(url);
      }
      await ApiService().createPost({
        'content': _contentController.text.trim(),
        if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post. Please try again.', style: AppTypography.dmSans()),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile?['name'] as String? ?? '';
    final avatarUrl = ApiService.getAvatarUrl(_profile?['profilePicture'] as String?, name: name.isNotEmpty ? name : 'U');
    final charCount = _contentController.text.length;
    const maxChars = 500;

    return Scaffold(
      backgroundColor: context.c.surface,
      appBar: AppBar(
        backgroundColor: context.c.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: context.c.surface, shape: BoxShape.circle),
            child: Icon(Icons.close_rounded, size: 18, color: context.c.ink),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('New Post',
          style: AppTypography.dmSans(fontWeight: FontWeight.w800, fontSize: 17, color: context.c.ink),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isLoading
                ? SizedBox(width: 36, height: 36,
                    child: Center(child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: context.c.brand))))
                : AnimatedOpacity(
                    opacity: _canPost ? 1.0 : 0.45,
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      onTap: _canPost ? _submitPost : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.c.brand,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Post',
                          style: AppTypography.dmSans(color: context.c.onBrand, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey[100]),
        ),
      ),
      body: Column(
        children: [
          // Compose area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar column
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: name.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        backgroundColor: name.isNotEmpty ? null : context.c.ink3,
                        child: name.isEmpty
                            ? SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: context.c.brand))
                            : null,
                      ),
                      if (_canPost) ...[
                        const SizedBox(height: 8),
                        Container(width: 2, height: 30, decoration: BoxDecoration(
                          color: context.c.ink3,
                          borderRadius: BorderRadius.circular(2),
                        )),
                      ],
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Text + images
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (name.isNotEmpty)
                        Text(name,
                          style: AppTypography.dmSans(fontWeight: FontWeight.w700, fontSize: 15, color: context.c.ink),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _contentController,
                          maxLines: null,
                          minLines: 4,
                          autofocus: true,
                          maxLength: maxChars,
                          onChanged: (_) => setState(() {}),
                          style: AppTypography.dmSans(fontSize: 16, height: 1.6, color: context.c.ink),
                          decoration: InputDecoration(
                            hintText: "Share your travel story, tip, or moment…",
                            hintStyle: AppTypography.dmSans(color: const Color(0xFFBBBBBB), fontSize: 16, height: 1.6),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                            counterText: '',
                            isDense: true,
                          ),
                        ),
                        // Image previews
                        if (_selectedImages.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _buildImageGrid(),
                        ],
                        // Character count
                        if (charCount > 400) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text('${maxChars - charCount}',
                              style: AppTypography.dmSans(
                                fontSize: 13,
                                color: charCount > 480 ? Colors.red[400] : context.c.ink3,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom toolbar
          Container(
            decoration: BoxDecoration(
              color: context.c.surfaceRaised,
              border: Border(top: BorderSide(color: Colors.grey[100]!)),
            ),
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 10,
              bottom: MediaQuery.of(context).padding.bottom + 10,
            ),
            child: Row(
              children: [
                // Photo button
                _mediaButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Photo',
                  onTap: _pickImages,
                  badge: _selectedImages.isNotEmpty ? '${_selectedImages.length}' : null,
                ),
                const SizedBox(width: 4),
                _mediaButton(
                  icon: Icons.location_on_rounded,
                  label: 'Location',
                  onTap: () {},
                ),
                const Spacer(),
                if (charCount > 0)
                  SizedBox(
                    width: 28, height: 28,
                    child: CircularProgressIndicator(
                      value: charCount / maxChars,
                      strokeWidth: 2.5,
                      backgroundColor: context.c.ink3,
                      color: charCount > 480 ? Colors.red[400] : context.c.brand,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid() {
    final count = _selectedImages.length;
    if (count == 1) {
      return _imageThumb(0, height: 200, width: double.infinity);
    }
    if (count == 2) {
      return Row(children: [
        Expanded(child: _imageThumb(0, height: 160)),
        const SizedBox(width: 4),
        Expanded(child: _imageThumb(1, height: 160)),
      ]);
    }
    // 3+: first big + column of two
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 3, child: _imageThumb(0, height: 180)),
      const SizedBox(width: 4),
      Expanded(flex: 2, child: Column(children: [
        _imageThumb(1, height: 88),
        const SizedBox(height: 4),
        Stack(children: [
          _imageThumb(2, height: 88),
          if (count > 3)
            Positioned.fill(child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(child: Text('+${count - 3}',
                  style: AppTypography.dmSans(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                )),
              ),
            )),
        ]),
      ])),
    ]);
  }

  Widget _imageThumb(int index, {double? height, double? width}) {
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FutureBuilder<Uint8List>(
          future: _selectedImages[index].readAsBytes(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return Container(
                width: width, height: height,
                color: Colors.grey[100],
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return Image.memory(snap.data!, width: width, height: height, fit: BoxFit.cover);
          },
        ),
      ),
      Positioned(
        top: 6, right: 6,
        child: GestureDetector(
          onTap: () => _removeImage(index),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle),
            child: const Icon(Icons.close, color: Colors.white, size: 14),
          ),
        ),
      ),
    ]);
  }

  Widget _mediaButton({required IconData icon, required String label, required VoidCallback onTap, String? badge}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: context.c.brand, size: 20),
          const SizedBox(width: 5),
          Text(label, style: AppTypography.dmSans(color: context.c.ink2, fontSize: 13, fontWeight: FontWeight.w600)),
          if (badge != null) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: context.c.brand.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Text(badge, style: AppTypography.dmSans(color: context.c.brand, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ),
    );
  }
}
