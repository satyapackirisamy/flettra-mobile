import 'dart:convert';
import '../theme/flettra_colors.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  static const String _cloudName    = 'ddr50k5wv';
  static const String _uploadPreset = 'flettra_preset_upload';
  static const String _uploadUrl    =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  /// Pick an image from gallery or camera, upload to Cloudinary,
  /// and return the secure URL. Returns null if user cancelled.
  static Future<String?> pickAndUpload(
    BuildContext context, {
    int imageQuality = 80,
    int maxWidth = 1200,
  }) async {
    // 1. Ask user: gallery or camera
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.c.surfaceRaised,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E5E5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B2C).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFFFF6B2C)),
                ),
                title: const Text('Choose from Gallery',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                subtitle: const Text('Pick an existing photo'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B2C).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFFF6B2C)),
                ),
                title: const Text('Take a Photo',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                subtitle: const Text('Use your camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );

    if (source == null) return null;

    // 2. Pick image
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: source,
      maxWidth: maxWidth.toDouble(),
      imageQuality: imageQuality,
    );
    if (file == null) return null;

    // 3. Read bytes and build base64 data URI
    //    (base64 upload is more reliable than multipart for unsigned presets)
    final Uint8List bytes = await file.readAsBytes();
    final String ext      = file.name.split('.').last.toLowerCase();
    final String mime     = (ext == 'png') ? 'image/png'
                          : (ext == 'webp') ? 'image/webp'
                          : 'image/jpeg';
    final String dataUri  = 'data:$mime;base64,${base64Encode(bytes)}';

    // 4. POST to Cloudinary as JSON (base64 method doesn't need multipart)
    final dio = Dio();
    try {
      final response = await dio.post(
        _uploadUrl,
        data: {
          'file':           dataUri,
          'upload_preset':  _uploadPreset,
        },
        options: Options(
          contentType: 'application/json',
          validateStatus: (_) => true,   // never throw — let us read the body
        ),
      );

      debugPrint('☁️ Cloudinary status: ${response.statusCode}');
      debugPrint('☁️ Cloudinary body: ${response.data}');

      if (response.statusCode == 200) {
        return response.data['secure_url'] as String?;
      }

      // Surface the real Cloudinary error message
      final errMsg = (response.data is Map)
          ? (response.data['error']?['message'] as String?) ?? response.data.toString()
          : response.data?.toString() ?? 'Unknown error (${response.statusCode})';
      throw Exception('Cloudinary ${response.statusCode}: $errMsg');

    } finally {
      dio.close();
    }
  }
}
