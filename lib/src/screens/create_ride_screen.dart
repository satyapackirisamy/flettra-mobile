import 'package:dio/dio.dart';
import '../theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/cloudinary_service.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/network_image_widget.dart';
import '../widgets/places_autocomplete_field.dart';

// Values mirror backend ride.enums.ts
enum TransportMode {
  car('car', '🚗', 'Car'),
  bike('bike', '🏍️', 'Bike');

  final String value;
  final String emoji;
  final String label;
  const TransportMode(this.value, this.emoji, this.label);
}

enum GenderPreference {
  any('any', 'Any'),
  maleOnly('male_only', 'Male Only'),
  femaleOnly('female_only', 'Female Only');

  final String value;
  final String label;
  const GenderPreference(this.value, this.label);
}

class CreateRideScreen extends StatefulWidget {
  final List<dynamic>? selectedMembers;
  final String? initialDestination;
  final String? initialImage;
  const CreateRideScreen({super.key, this.selectedMembers, this.initialDestination, this.initialImage});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _nameController = TextEditingController();
  final _seatsController = TextEditingController(text: '3');
  final _priceController = TextEditingController(text: '0');
  final _descriptionController = TextEditingController();
  final _rulesController = TextEditingController();
  final _coverImageController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  DateTime _arrivalDate = DateTime.now().add(const Duration(days: 1, hours: 1));
  TransportMode _transportMode = TransportMode.bike;
  GenderPreference _genderPreference = GenderPreference.any;
  bool _isPrivateCircle = false; // Visibility: false = ANYONE, true = CIRCLE
  bool _generateItinerary = false;
  bool _isLoading   = false;
  bool _isUploading = false;
  late List<dynamic> _currentSelectedMembers;

  final Map<String, String> _themes = {
    'Mountain': 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?q=80&w=800&auto=format&fit=crop',
    'Beach': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?q=80&w=800&auto=format&fit=crop',
    'City': 'https://images.unsplash.com/photo-1449824913935-59a10b8d2000?q=80&w=800&auto=format&fit=crop',
    'Road Trip': 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?q=80&w=800&auto=format&fit=crop',
    'Countryside': 'https://images.unsplash.com/photo-1544735716-392fe2489ffa?q=80&w=800&auto=format&fit=crop',
  };

  @override
  void initState() {
    super.initState();
    _coverImageController.text = widget.initialImage ?? _themes['Road Trip']!;
    _destinationController.text = widget.initialDestination ?? '';
    _currentSelectedMembers = widget.selectedMembers != null ? List.from(widget.selectedMembers!) : [];
    if (_currentSelectedMembers.isNotEmpty) {
      _seatsController.text = (4 - _currentSelectedMembers.length).clamp(1, 4).toString();
      _descriptionController.text = "Group ride for: ${_currentSelectedMembers.map((m) => m['name']).join(', ')}";
    }
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

  Future<void> _selectDateTime(BuildContext context, bool isArrival) async {
    final initial = isArrival ? _arrivalDate : _selectedDate;
    final first = isArrival ? _selectedDate : DateTime.now();
    
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFFF6B2C),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF1A1A1A),
          ),
        ),
        child: child!,
      ),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF6B2C),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1A1A1A),
            ),
          ),
          child: child!,
        ),
      );
      if (time != null) {
        setState(() {
          if (isArrival) {
            _arrivalDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          } else {
            _selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
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

  Future<void> _pickAndUploadImage() async {
    setState(() => _isUploading = true);
    try {
      final url = await CloudinaryService.pickAndUpload(context);
      if (url != null && mounted) {
        setState(() => _coverImageController.text = url);
      }
    } catch (e) {
      if (mounted) showError(context, 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _submitRide() async {
    if (!_formKey.currentState!.validate()) return;

    final seats = int.tryParse(_seatsController.text.trim());
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;

    if (seats == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number of seats')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Send separated departureDate (YYYY-MM-DD) and departureTime (HH:mm)
      await _apiService.client.post('/rides', data: {
        if (_nameController.text.trim().isNotEmpty) 'name': _nameController.text.trim(),
        'origin': _originController.text.trim(),
        'destination': _destinationController.text.trim(),
        'departureDate': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'departureTime': DateFormat('HH:mm').format(_selectedDate),
        'arrivalDate': DateFormat('yyyy-MM-dd').format(_arrivalDate),
        'arrivalTime': DateFormat('HH:mm').format(_arrivalDate),
        'seatsAvailable': seats,
        'pricePerSeat': price,
        if (_descriptionController.text.trim().isNotEmpty) 'description': _descriptionController.text.trim(),
        if (_rulesController.text.trim().isNotEmpty) 'rules': _rulesController.text.trim(),
        'transportMode': _transportMode.value,
        'genderPreference': _genderPreference.value,
        'visibility': _isPrivateCircle ? 'circle' : 'anyone',
        'duration': _calculatedDuration,
        'generateItinerary': _generateItinerary,
        if (_coverImageController.text.trim().isNotEmpty) 'coverImage': _coverImageController.text.trim(),
        if (_currentSelectedMembers.isNotEmpty)
          'passengerIds': _currentSelectedMembers.map((m) => m['id']).toList(),
      });

      if (mounted) {
        showSuccess(context, 'Ride created successfully!');
        Navigator.of(context).pop(true);
      }
    } on DioException catch (e) {
      if (mounted) {
        // Extract the real error message returned by the backend
        final responseData = e.response?.data;
        String message;
        if (responseData is Map) {
          final msg = responseData['message'];
          message = msg is List ? msg.join(', ') : msg?.toString() ?? e.message ?? 'Unknown error';
        } else {
          message = e.message ?? 'Unknown error';
        }
        showError(context, 'Error ${e.response?.statusCode ?? ''}: $message');
      }
    } catch (e) {
      if (mounted) {
        showError(context, 'Unexpected error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  // ─── Colors ───────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFFFF6B2C);
  static const Color _primaryEnd = Color(0xFFFF8C5A);
  static const Color _dark    = Color(0xFF1A1A1A);
  static const Color _bg      = Color(0xFFF8F8F8);

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF1A1A1A)),
          ),
        ),
        title: Text(
          'Create Ride',
          style: AppTypography.dmSans(fontWeight: FontWeight.w700, fontSize: 18, color: _dark, letterSpacing: -0.4),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            child: GestureDetector(
              onTap: _isLoading ? null : _submitRide,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Publish', style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Cover Photo ───────────────────────────────────────────
              _card([
                _label('Cover Photo', Icons.photo_camera_rounded),
                const SizedBox(height: 12),
                SizedBox(
                  height: 96,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      GestureDetector(
                        onTap: _isUploading ? null : _pickAndUploadImage,
                        child: Container(
                          width: 106,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: _primary.withOpacity(0.06),
                            border: Border.all(color: _primary.withOpacity(0.35), width: 1.5),
                          ),
                          child: _isUploading
                              ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _primary, strokeWidth: 2)))
                              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.add_photo_alternate_rounded, color: _primary, size: 24),
                                  const SizedBox(height: 5),
                                  Text('Upload', style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: _primary)),
                                ]),
                        ),
                      ),
                      ..._themes.entries.map((entry) {
                        final isSelected = _coverImageController.text == entry.value;
                        return GestureDetector(
                          onTap: () => setState(() => _coverImageController.text = entry.value),
                          child: Container(
                            width: 140,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: isSelected
                                  ? Border.all(color: _primary, width: 2.5)
                                  : Border.all(color: Colors.transparent),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(isSelected ? 12 : 14),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  SafeNetworkImage(url: entry.value, fit: BoxFit.cover),
                                  Container(
                                    color: Colors.black.withOpacity(isSelected ? 0.3 : 0.45),
                                    alignment: Alignment.center,
                                    child: Text(
                                      entry.key,
                                      style: AppTypography.dmSans(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: 6, right: 6,
                                      child: Container(
                                        width: 20, height: 20,
                                        decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle),
                                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                if (_coverImageController.text.isNotEmpty && !_themes.values.contains(_coverImageController.text)) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        SafeNetworkImage(url: _coverImageController.text, height: 140, width: double.infinity, fit: BoxFit.cover),
                        Positioned(
                          bottom: 8, right: 8,
                          child: GestureDetector(
                            onTap: _pickAndUploadImage,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text('Change', style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                              ]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ]),

              // ── Passengers (if pre-selected) ──────────────────────────
              if (_currentSelectedMembers.isNotEmpty) ...[
                const SizedBox(height: 12),
                _card([
                  _label('Passengers', Icons.people_alt_rounded),
                  const SizedBox(height: 10),
                  ..._currentSelectedMembers.map((member) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(10)),
                          child: Center(
                            child: Text(
                              (member['name'] as String).isNotEmpty ? member['name'][0].toUpperCase() : '?',
                              style: AppTypography.dmSans(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(member['name'] as String, style: AppTypography.dmSans(fontWeight: FontWeight.w600, color: _dark))),
                        GestureDetector(
                          onTap: () => setState(() => _currentSelectedMembers.remove(member)),
                          child: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 20),
                        ),
                      ],
                    ),
                  )),
                ]),
              ],

              // ── Route ─────────────────────────────────────────────────
              const SizedBox(height: 12),
              _card([
                _label('Route', Icons.route_rounded),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  style: AppTypography.dmSans(fontWeight: FontWeight.w500, fontSize: 14, color: _dark),
                  decoration: _fieldDecor('Ride name (optional)', Icons.drive_file_rename_outline_rounded),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildLocationAutocomplete(label: 'From', icon: Icons.my_location_rounded, controller: _originController)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildLocationAutocomplete(label: 'To', icon: Icons.location_on_rounded, controller: _destinationController)),
                  ],
                ),
              ]),

              // ── Schedule ──────────────────────────────────────────────
              const SizedBox(height: 12),
              _card([
                _label('Schedule', Icons.calendar_month_rounded),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _dateTile(
                      label: 'Departure',
                      icon: Icons.flight_takeoff_rounded,
                      date: _selectedDate,
                      onTap: () => _selectDateTime(context, false),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _dateTile(
                      label: 'Arrival',
                      icon: Icons.flight_land_rounded,
                      date: _arrivalDate,
                      onTap: () => _selectDateTime(context, true),
                    )),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_calculatedDuration day${_calculatedDuration != 1 ? 's' : ''} trip',
                      style: AppTypography.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: _primary),
                    ),
                  ),
                ),
              ]),

              // ── Details ───────────────────────────────────────────────
              const SizedBox(height: 12),
              _card([
                _label('Details', Icons.tune_rounded),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _seatsController,
                        keyboardType: TextInputType.number,
                        style: AppTypography.dmSans(fontWeight: FontWeight.w600, fontSize: 14, color: _dark),
                        decoration: _fieldDecor('Seats available', Icons.event_seat_rounded),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        style: AppTypography.dmSans(fontWeight: FontWeight.w600, fontSize: 14, color: _dark),
                        decoration: _fieldDecor('Price per seat (₹, 0 = free)', Icons.currency_rupee_rounded),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final n = double.tryParse(v.trim());
                          if (n == null || n < 0) return 'Enter a valid price';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Transport mode
                Text('Transport', style: AppTypography.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6B7280))),
                const SizedBox(height: 8),
                Row(
                  children: TransportMode.values.map((mode) {
                    final selected = _transportMode == mode;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _transportMode = mode),
                        child: Container(
                          margin: EdgeInsets.only(right: mode != TransportMode.values.last ? 8 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? _primary : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(mode.emoji, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Text(mode.label, style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : const Color(0xFF374151))),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // Gender preference
                Text('Traveler preference', style: AppTypography.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6B7280))),
                const SizedBox(height: 8),
                Row(
                  children: GenderPreference.values.map((pref) {
                    final selected = _genderPreference == pref;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _genderPreference = pref),
                        child: Container(
                          margin: EdgeInsets.only(right: pref != GenderPreference.values.last ? 6 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? _primary.withOpacity(0.12) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: selected ? Border.all(color: _primary, width: 1.5) : null,
                          ),
                          child: Text(
                            pref.label,
                            textAlign: TextAlign.center,
                            style: AppTypography.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? _primary : const Color(0xFF6B7280)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ]),

              // ── Preferences ───────────────────────────────────────────
              const SizedBox(height: 12),
              _card([
                _label('Preferences', Icons.settings_rounded),
                const SizedBox(height: 4),
                _toggleRow(
                  icon: _isPrivateCircle ? Icons.lock_outline_rounded : Icons.public_rounded,
                  title: _isPrivateCircle ? 'Buddies & Groups Only' : 'Open to Anyone',
                  subtitle: 'Who can see and join this ride',
                  value: _isPrivateCircle,
                  onChanged: (v) => setState(() => _isPrivateCircle = v),
                ),
                const Divider(height: 1),
                _toggleRow(
                  icon: Icons.auto_awesome_rounded,
                  title: 'AI Itinerary',
                  subtitle: 'Auto-generate a travel plan',
                  value: _generateItinerary,
                  onChanged: (v) => setState(() => _generateItinerary = v),
                  activeColor: const Color(0xFFF59E0B),
                ),
              ]),

              // ── Description ───────────────────────────────────────────
              const SizedBox(height: 12),
              _card([
                _label('About the Trip', Icons.description_rounded),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  style: AppTypography.dmSans(fontWeight: FontWeight.w500, fontSize: 14, color: _dark),
                  decoration: InputDecoration(
                    hintText: 'What\'s this trip about? Who should join?',
                    hintStyle: AppTypography.dmSans(fontSize: 13, color: const Color(0xFFAFB8C4)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please describe the trip' : null,
                ),
              ]),

              // ── Rules ─────────────────────────────────────────────────
              const SizedBox(height: 12),
              _card([
                _label('Rules & Guidelines', Icons.gavel_rounded),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rulesController,
                  maxLines: 2,
                  style: AppTypography.dmSans(fontWeight: FontWeight.w500, fontSize: 14, color: _dark),
                  decoration: InputDecoration(
                    hintText: 'Optional — safety rules, packing list, etc.',
                    hintStyle: AppTypography.dmSans(fontSize: 13, color: const Color(0xFFAFB8C4)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ]),

              // ── Submit ────────────────────────────────────────────────
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _isLoading ? null : _submitRide,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _isLoading
                        ? null
                        : const LinearGradient(colors: [Color(0xFFE8551A), Color(0xFFFF6B2C), Color(0xFFFF8C5A)]),
                    color: _isLoading ? const Color(0xFFE2E8F0) : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _isLoading ? null : [
                      BoxShadow(color: _primary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 10),
                              Text('Publish Ride', style: AppTypography.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.2)),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _label(String text, IconData icon) {
    return Row(
      children: [
        Container(
          width: 3, height: 16,
          decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 15, color: _primary),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: AppTypography.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: _dark, letterSpacing: -0.2))),
      ],
    );
  }

  InputDecoration _fieldDecor(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.dmSans(fontSize: 13, color: const Color(0xFFAFB8C4)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFFAFB8C4)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF6B2C), width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF43F5E), width: 1)),
    );
  }

  Widget _dateTile({required String label, required IconData icon, required DateTime date, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 12, color: _primary),
            const SizedBox(width: 4),
            Text(label.toUpperCase(), style: AppTypography.dmSans(fontSize: 9, fontWeight: FontWeight.w800, color: _primary, letterSpacing: 0.6)),
          ]),
          const SizedBox(height: 6),
          Text(DateFormat('dd MMM').format(date), style: AppTypography.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: _dark)),
          Text(DateFormat('HH:mm').format(date), style: AppTypography.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6B7280))),
        ]),
      ),
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? activeColor,
  }) {
    final color = activeColor ?? _primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: value ? color.withOpacity(0.1) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: value ? color : const Color(0xFF9CA3AF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppTypography.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: _dark)),
              Text(subtitle, style: AppTypography.dmSans(fontSize: 11, color: const Color(0xFF9CA3AF))),
            ]),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationAutocomplete({
    required String label,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return PlacesAutocompleteField(
      controller: controller,
      hint: label,
      icon: icon,
      textStyle: AppTypography.dmSans(fontWeight: FontWeight.w500, fontSize: 14, color: _dark),
      decorationBuilder: (hint, ico) => _fieldDecor(hint, ico),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      dropdownMaxWidth: (MediaQuery.of(context).size.width - 52) / 2,
    );
  }
}
