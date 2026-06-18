import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/locations.dart';
import '../services/api_service.dart';
import '../services/cloudinary_service.dart';
import '../widgets/network_image_widget.dart';
import 'create_ride_screen.dart' show TransportMode, GenderPreference;

class EditRideScreen extends StatefulWidget {
  final Map<String, dynamic> ride;
  const EditRideScreen({super.key, required this.ride});

  @override
  State<EditRideScreen> createState() => _EditRideScreenState();
}

class _EditRideScreenState extends State<EditRideScreen> {
  // ─── Brand colours (matches create_ride_screen) ───────────────────────────
  static const _orange    = Color(0xFFFF6B2C);
  static const _orangeEnd = Color(0xFFFF8C5A);
  static const _dark      = Color(0xFF1A0A08);

  final _formKey   = GlobalKey<FormState>();
  final _apiService = ApiService();

  late TextEditingController _originController;
  late TextEditingController _destinationController;
  late TextEditingController _nameController;
  late TextEditingController _seatsController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late TextEditingController _rulesController;
  late TextEditingController _coverImageController;

  late DateTime _selectedDate;
  late DateTime _arrivalDate;
  late TransportMode _transportMode;
  late GenderPreference _genderPreference;
  bool _isPrivateCircle = false;
  bool _isLoading   = false;
  bool _isUploading = false;

  // ─── Init ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final r = widget.ride;

    _originController      = TextEditingController(text: r['origin']      as String? ?? '');
    _destinationController = TextEditingController(text: r['destination'] as String? ?? '');
    _nameController        = TextEditingController(text: r['name']        as String? ?? '');
    _seatsController       = TextEditingController(text: (r['seatsAvailable'] ?? 1).toString());
    _priceController       = TextEditingController(text: (r['pricePerSeat']    ?? 0).toString());
    _descriptionController = TextEditingController(text: r['description'] as String? ?? '');
    _rulesController       = TextEditingController(text: r['rules']       as String? ?? '');
    _coverImageController  = TextEditingController(text: r['coverImage']  as String? ?? '');

    _selectedDate = _parseDateTime(r['departureDate'], r['departureTime']);
    _arrivalDate  = _parseDateTime(r['arrivalDate'],   r['arrivalTime'],
        fallback: _selectedDate.add(const Duration(days: 1)));

    final modeStr = r['transportMode'] as String? ?? 'car';
    _transportMode = TransportMode.values.firstWhere(
      (m) => m.value == modeStr, orElse: () => TransportMode.car);

    final prefStr = r['genderPreference'] as String? ?? 'any';
    _genderPreference = GenderPreference.values.firstWhere(
      (p) => p.value == prefStr, orElse: () => GenderPreference.any);

    _isPrivateCircle = r['visibility'] == 'circle';
  }

  DateTime _parseDateTime(dynamic dateStr, dynamic timeStr, {DateTime? fallback}) {
    final d = dateStr as String? ?? '';
    final t = timeStr as String? ?? '00:00';
    if (d.isNotEmpty) {
      try {
        final date  = DateTime.parse(d);
        final parts = t.split(':');
        final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
        final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
        return DateTime(date.year, date.month, date.day, h, m);
      } catch (_) {}
    }
    return fallback ?? DateTime.now().add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _nameController.dispose();
    _seatsController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _rulesController.dispose();
    _coverImageController.dispose();
    super.dispose();
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _pickAndUploadImage() async {
    setState(() => _isUploading = true);
    try {
      final url = await CloudinaryService.pickAndUpload(context);
      if (url != null && mounted) {
        setState(() => _coverImageController.text = url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _selectDateTime(bool isArrival) async {
    final initial = isArrival ? _arrivalDate : _selectedDate;
    final date    = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (time != null && mounted) {
        setState(() {
          final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          if (isArrival) {
            _arrivalDate = dt;
          } else {
            _selectedDate = dt;
            if (_arrivalDate.isBefore(_selectedDate)) {
              _arrivalDate = _selectedDate.add(const Duration(hours: 4));
            }
          }
        });
      }
    }
  }

  int get _calculatedDuration {
    final diff = _arrivalDate.difference(_selectedDate);
    return diff.inDays > 0 ? diff.inDays : 1;
  }

  Future<void> _updateRide() async {
    if (!_formKey.currentState!.validate()) return;
    final seats = int.tryParse(_seatsController.text.trim());
    final price = double.tryParse(_priceController.text.trim());
    if (seats == null || price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid numbers for seats and price')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _apiService.client.patch('/rides/${widget.ride['id']}', data: {
        if (_nameController.text.trim().isNotEmpty) 'name': _nameController.text.trim(),
        'origin':          _originController.text.trim(),
        'destination':     _destinationController.text.trim(),
        'departureDate':   DateFormat('yyyy-MM-dd').format(_selectedDate),
        'departureTime':   DateFormat('HH:mm').format(_selectedDate),
        'arrivalDate':     DateFormat('yyyy-MM-dd').format(_arrivalDate),
        'arrivalTime':     DateFormat('HH:mm').format(_arrivalDate),
        'seatsAvailable':  seats,
        'pricePerSeat':    price,
        if (_descriptionController.text.trim().isNotEmpty) 'description': _descriptionController.text.trim(),
        if (_rulesController.text.trim().isNotEmpty)       'rules':       _rulesController.text.trim(),
        'transportMode':   _transportMode.value,
        'genderPreference': _genderPreference.value,
        'visibility':      _isPrivateCircle ? 'circle' : 'anyone',
        'duration':        _calculatedDuration,
        if (_coverImageController.text.trim().isNotEmpty) 'coverImage': _coverImageController.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      if (mounted) {
        final data = e.response?.data;
        String msg;
        if (data is Map) {
          final m = data['message'];
          msg = m is List ? m.join(', ') : m?.toString() ?? e.message ?? 'Unknown error';
        } else {
          msg = e.message ?? 'Unknown error';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ${e.response?.statusCode ?? ''}: $msg')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unexpected error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Ride?', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: _dark)),
        content: Text('This is permanent and cannot be undone. All passenger bookings will be cancelled.',
            style: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey[600])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _apiService.deleteRide(widget.ride['id'] as String);
        if (mounted) {
          Navigator.of(context).popUntil((r) => r.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ride deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _dark),
          ),
        ),
        title: Text('Edit Ride',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 18, color: _dark, letterSpacing: -0.5)),
        actions: [
          // Delete button
          GestureDetector(
            onTap: _deleteRide,
            child: Container(
              margin: const EdgeInsets.only(right: 8, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20)),
            ),
          ),
          // Save button
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_orange, _orangeEnd]),
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: GestureDetector(
              onTap: _isLoading ? null : _updateRide,
              child: Center(
                child: _isLoading
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Save',
                        style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Cover Photo ──────────────────────────────────────────────
              _sectionTitle('Cover Photo', Icons.photo_camera_rounded),
              const SizedBox(height: 12),
              _buildImageUploader(),
              const SizedBox(height: 24),

              // ── Route ────────────────────────────────────────────────────
              _sectionTitle('Route', Icons.route_rounded),
              const SizedBox(height: 12),
              _buildField(
                controller: _nameController,
                label: 'Ride Name (optional)',
                hint: 'e.g. Spiti Winter Ride',
                icon: Icons.drive_file_rename_outline_rounded,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildLocationAutocomplete(label: 'From', icon: Icons.my_location, controller: _originController)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildLocationAutocomplete(label: 'To', icon: Icons.location_on, controller: _destinationController)),
                ],
              ),
              const SizedBox(height: 24),

              // ── Timeline ─────────────────────────────────────────────────
              _sectionTitle('Timeline', Icons.schedule_rounded),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildDateCard('DEPARTURE', _selectedDate, _orange, false)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(children: [
                      Container(width: 1, height: 16, color: Colors.grey[300]),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: _orange.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_forward_rounded, size: 12, color: _orange),
                      ),
                      Container(width: 1, height: 16, color: Colors.grey[300]),
                    ]),
                  ),
                  Expanded(child: _buildDateCard('ARRIVAL', _arrivalDate, _orangeEnd, true)),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: _orange.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                  child: Text('$_calculatedDuration day${_calculatedDuration != 1 ? 's' : ''} total',
                      style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: _orange)),
                ),
              ),
              const SizedBox(height: 24),

              // ── Logistics ─────────────────────────────────────────────────
              _sectionTitle('Logistics', Icons.tune_rounded),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildField(controller: _seatsController, label: 'Seats', icon: Icons.event_seat, keyboard: TextInputType.number, validator: null)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField(controller: _priceController, label: 'Est. Budget (₹)', icon: Icons.currency_rupee, keyboard: TextInputType.number, validator: null)),
                ],
              ),
              const SizedBox(height: 12),

              // Visibility toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[100]!),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: _orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(_isPrivateCircle ? Icons.lock_outline_rounded : Icons.public_rounded, color: _orange, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Visibility', style: GoogleFonts.dmSans(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      Text(_isPrivateCircle ? 'Buddies & Groups Only' : 'Open to Anyone',
                          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w800, color: _dark)),
                    ]),
                  ),
                  Switch(value: _isPrivateCircle, onChanged: (v) => setState(() => _isPrivateCircle = v), activeColor: _orange),
                ]),
              ),
              const SizedBox(height: 12),

              // Transport mode
              _buildDropdown<TransportMode>(
                value: _transportMode,
                label: 'Transport Mode',
                icon: Icons.directions_car_rounded,
                items: TransportMode.values.map((m) =>
                  DropdownMenuItem(value: m, child: Text('${m.emoji} ${m.label}'))).toList(),
                onChanged: (v) => setState(() => _transportMode = v!),
              ),
              const SizedBox(height: 12),

              // Gender preference
              _buildDropdown<GenderPreference>(
                value: _genderPreference,
                label: 'Gender Preference',
                icon: Icons.people_alt_rounded,
                items: GenderPreference.values.map((p) =>
                  DropdownMenuItem(value: p, child: Text(p.label))).toList(),
                onChanged: (v) => setState(() => _genderPreference = v!),
              ),
              const SizedBox(height: 24),

              // ── Details ──────────────────────────────────────────────────
              _sectionTitle('Details', Icons.notes_rounded),
              const SizedBox(height: 12),
              _buildField(
                controller: _descriptionController,
                label: 'Journey Description',
                maxLines: 4,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _rulesController,
                label: 'Rules & Guidelines (optional)',
                maxLines: 2,
              ),
              const SizedBox(height: 32),

              // ── Submit ───────────────────────────────────────────────────
              GestureDetector(
                onTap: _isLoading ? null : _updateRide,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: _isLoading
                        ? null
                        : const LinearGradient(colors: [_orange, _orangeEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    color: _isLoading ? Colors.grey[200] : null,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: _isLoading ? null : [BoxShadow(color: _orange.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 10),
                            Text('Apply Changes', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                          ]),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Image uploader ───────────────────────────────────────────────────────

  Widget _buildImageUploader() {
    final hasImage = _coverImageController.text.trim().isNotEmpty;
    return GestureDetector(
      onTap: _isUploading ? null : _pickAndUploadImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: hasImage ? Colors.transparent : Colors.grey[300]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background: image or placeholder
              if (hasImage)
                SafeNetworkImage(url: _coverImageController.text, fit: BoxFit.cover)
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _orange.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_photo_alternate_rounded, size: 36, color: _orange),
                    ),
                    const SizedBox(height: 12),
                    Text('Tap to upload cover photo',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: Colors.grey[600], fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Gallery or camera',
                        style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey[400])),
                  ],
                ),

              // Upload progress overlay
              if (_isUploading)
                Container(
                  color: Colors.black45,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      const SizedBox(height: 12),
                      Text('Uploading…', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),

              // "Change photo" pill — shown when an image is already set
              if (hasImage && !_isUploading)
                Positioned(
                  bottom: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text('Change Photo', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Timeline date card ───────────────────────────────────────────────────

  Widget _buildDateCard(String label, DateTime dt, Color color, bool isArrival) {
    return GestureDetector(
      onTap: () => _selectDateTime(isArrival),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(isArrival ? Icons.flight_land_rounded : Icons.flight_takeoff_rounded, size: 13, color: color),
              const SizedBox(width: 5),
              Text(label, style: GoogleFonts.dmSans(fontSize: 9, color: color, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ]),
            const SizedBox(height: 6),
            Text(DateFormat('MMM dd').format(dt), style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: _dark)),
            Text(DateFormat('HH:mm').format(dt), style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionTitle(String title, IconData icon) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(color: _orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 15, color: _orange),
      ),
      const SizedBox(width: 10),
      Text(title, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: _dark, letterSpacing: -0.3)),
    ]);
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    int maxLines = 1,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboard,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        alignLabelWithHint: maxLines > 1,
        fillColor: Colors.grey[100],
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        fillColor: Colors.grey[100],
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildLocationAutocomplete({
    required String label,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue v) async {
        if (v.text.length < 2) return const Iterable<String>.empty();
        final local = indianCities
            .where((c) => c.toLowerCase().contains(v.text.toLowerCase()))
            .toList();
        try {
          final res = await Dio().get(
            'https://nominatim.openstreetmap.org/search',
            queryParameters: {'q': v.text, 'format': 'json', 'addressdetails': 1, 'limit': 10, 'countrycodes': 'in'},
          );
          if (res.statusCode == 200) {
            final networkCities = (res.data as List).map((item) {
              final addr = item['address'];
              return addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['state'] ?? item['display_name'];
            }).whereType<String>().toSet();
            return {...local, ...networkCities}.toList();
          }
        } catch (_) {}
        return local;
      },
      onSelected: (s) => controller.text = s,
      fieldViewBuilder: (ctx, textCtrl, focusNode, _) {
        if (textCtrl.text != controller.text) textCtrl.text = controller.text;
        textCtrl.addListener(() => controller.text = textCtrl.text);
        return TextFormField(
          controller: textCtrl,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            fillColor: Colors.grey[100],
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        );
      },
      optionsViewBuilder: (ctx, onSel, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: (MediaQuery.of(ctx).size.width - 64) / 2,
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final opt = options.elementAt(i);
                return ListTile(
                  dense: true,
                  title: Text(opt, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onTap: () => onSel(opt),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
