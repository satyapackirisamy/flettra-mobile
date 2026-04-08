import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../constants/locations.dart';
import '../services/api_service.dart';
import '../widgets/network_image_widget.dart';
import 'create_ride_screen.dart' show TransportMode, GenderPreference;

class EditRideScreen extends StatefulWidget {
  final Map<String, dynamic> ride;

  const EditRideScreen({super.key, required this.ride});

  @override
  State<EditRideScreen> createState() => _EditRideScreenState();
}

class _EditRideScreenState extends State<EditRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late TextEditingController _originController;
  late TextEditingController _destinationController;
  late TextEditingController _nameController;
  late TextEditingController _seatsController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late TextEditingController _rulesController;
  late TextEditingController _durationController;
  late TextEditingController _coverImageController;

  late DateTime _selectedDate;
  late DateTime _arrivalDate;
  late TransportMode _transportMode;
  late GenderPreference _genderPreference;
  bool _isPrivateCircle = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _originController = TextEditingController(text: widget.ride['origin'] as String? ?? '');
    _destinationController = TextEditingController(text: widget.ride['destination'] as String? ?? '');
    _nameController = TextEditingController(text: widget.ride['name'] as String? ?? '');
    _seatsController = TextEditingController(text: (widget.ride['seatsAvailable'] ?? 1).toString());
    _priceController = TextEditingController(text: (widget.ride['pricePerSeat'] ?? 0).toString());
    _descriptionController = TextEditingController(text: widget.ride['description'] as String? ?? '');
    _rulesController = TextEditingController(text: widget.ride['rules'] as String? ?? '');
    _durationController = TextEditingController(text: (widget.ride['duration'] ?? 3).toString());
    _coverImageController = TextEditingController(text: widget.ride['coverImage'] as String? ?? '');

    // Parse separated date + time fields (new schema)
    final dateStr = widget.ride['departureDate'] as String? ?? '';
    final timeStr = widget.ride['departureTime'] as String? ?? '00:00';
    if (dateStr.isNotEmpty) {
      try {
        final date = DateTime.parse(dateStr);
        final timeParts = timeStr.split(':');
        final hour = timeParts.isNotEmpty ? int.tryParse(timeParts[0]) ?? 0 : 0;
        final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
        _selectedDate = DateTime(date.year, date.month, date.day, hour, minute);
      } catch (_) {
        _selectedDate = DateTime.now().add(const Duration(hours: 1));
      }
    } else {
      _selectedDate = DateTime.now().add(const Duration(hours: 1));
    }

    // Arrival Date/Time
    final aDateStr = widget.ride['arrivalDate'] as String? ?? '';
    final aTimeStr = widget.ride['arrivalTime'] as String? ?? '00:00';
    if (aDateStr.isNotEmpty) {
      try {
        final date = DateTime.parse(aDateStr);
        final timeParts = aTimeStr.split(':');
        final hour = timeParts.isNotEmpty ? int.tryParse(timeParts[0]) ?? 0 : 0;
        final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
        _arrivalDate = DateTime(date.year, date.month, date.day, hour, minute);
      } catch (_) {
        _arrivalDate = _selectedDate.add(const Duration(days: 1));
      }
    } else {
      _arrivalDate = _selectedDate.add(const Duration(days: 1));
    }

    // Transport mode — default to car if unrecognized
    final modeStr = widget.ride['transportMode'] as String? ?? 'car';
    _transportMode = TransportMode.values.firstWhere(
      (m) => m.value == modeStr,
      orElse: () => TransportMode.car,
    );

    // Gender preference — default to any if unrecognized
    final prefStr = widget.ride['genderPreference'] as String? ?? 'any';
    _genderPreference = GenderPreference.values.firstWhere(
      (p) => p.value == prefStr,
      orElse: () => GenderPreference.any,
    );

    _isPrivateCircle = widget.ride['visibility'] == 'circle';
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
    _durationController.dispose();
    _coverImageController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(bool isArrival) async {
    final initial = isArrival ? _arrivalDate : _selectedDate;
    final date = await showDatePicker(
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
      if (time != null) {
        setState(() {
          if (isArrival) {
            _arrivalDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          } else {
            _selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
        const SnackBar(content: Text('Please enter valid numbers for seats and price')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _apiService.client.patch('/rides/${widget.ride['id']}', data: {
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
        if (_coverImageController.text.trim().isNotEmpty) 'coverImage': _coverImageController.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on DioException catch (e) {
      if (mounted) {
        final responseData = e.response?.data;
        String message;
        if (responseData is Map) {
          final msg = responseData['message'];
          message = msg is List ? msg.join(', ') : msg?.toString() ?? e.message ?? 'Unknown error';
        } else {
          message = e.message ?? 'Unknown error';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ${e.response?.statusCode ?? ''}: $message')),
        );
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
      builder: (context) => AlertDialog(
        title: const Text('Delete Ride? 🛑'),
        content: const Text('This action is permanent and cannot be undone. All passenger bookings will be cancelled.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _apiService.deleteRide(widget.ride['id'] as String);
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ride deleted successfully')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Refine Journey', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            onPressed: _deleteRide,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Cover Image Preview ──────────────────────────────
                    Container(
                      height: 180,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Colors.grey[100],
                        image: _coverImageController.text.isNotEmpty
                            ? DecorationImage(image: networkImageProvider(_coverImageController.text), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _coverImageController.text.isEmpty
                          ? const Center(child: Icon(Icons.image_outlined, size: 48, color: Colors.grey))
                          : null,
                    ),
                    TextFormField(
                      controller: _coverImageController,
                      decoration: const InputDecoration(
                        labelText: 'Cover Image URL',
                        prefixIcon: Icon(Icons.link_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                        hintText: 'https://images.unsplash.com/...',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 24),

                    // ── Ride Name ───────────────────────────────────────
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Ride Name (optional)',
                        hintText: 'e.g. Winter Spiti Ride',
                        prefixIcon: Icon(Icons.drive_file_rename_outline_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLocationAutocomplete(
                      label: 'Starting Point',
                      controller: _originController,
                    ),
                    const SizedBox(height: 16),
                    _buildLocationAutocomplete(
                      label: 'Destination',
                      controller: _destinationController,
                    ),
                    const SizedBox(height: 32),

                    const Text('Timeline', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildDateTimeCard('START', _selectedDate, Colors.blue, () => _selectDateTime(false))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDateTimeCard('FINISH', _arrivalDate, Colors.indigo, () => _selectDateTime(true))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(child: Text('Duration: $_calculatedDuration days', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                    const SizedBox(height: 32),

                    const Text('Logistics', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _seatsController,
                            decoration: const InputDecoration(labelText: 'Seats', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                            keyboardType: TextInputType.number,
                            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            decoration: const InputDecoration(labelText: 'Rate (₹)', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                            keyboardType: TextInputType.number,
                            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          Icon(_isPrivateCircle ? Icons.lock_outline : Icons.public, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Policy', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                                Text(_isPrivateCircle ? 'Buddies & Groups Only' : 'Open to Anyone', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Switch(value: _isPrivateCircle, onChanged: (v) => setState(() => _isPrivateCircle = v), activeColor: Colors.blue),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    DropdownButtonFormField<TransportMode>(
                      value: _transportMode,
                      decoration: const InputDecoration(labelText: 'Transport Mode', prefixIcon: Icon(Icons.directions_car_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)))),
                      items: TransportMode.values.map((mode) => DropdownMenuItem(value: mode, child: Text('${mode.emoji} ${mode.label}'))).toList(),
                      onChanged: (v) => setState(() => _transportMode = v!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<GenderPreference>(
                      value: _genderPreference,
                      decoration: const InputDecoration(labelText: 'Gender Preference', prefixIcon: Icon(Icons.people_alt_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)))),
                      items: GenderPreference.values.map((pref) => DropdownMenuItem(value: pref, child: Text(pref.label))).toList(),
                      onChanged: (v) => setState(() => _genderPreference = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Journey Description', alignLabelWithHint: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)))),
                      maxLines: 4,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _rulesController,
                      decoration: const InputDecoration(labelText: 'Rules & Guidelines (optional)', alignLabelWithHint: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)))),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _updateRide,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('Apply Changes', style: TextStyle(fontWeight: FontWeight.w900)),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.all(20), backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDateTimeCard(String label, DateTime date, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 4),
            Text(DateFormat('MMM dd, HH:mm').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationAutocomplete({required String label, required TextEditingController controller}) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.length < 2) return const Iterable<String>.empty();
        
        final local = indianCities.where((c) => c.toLowerCase().contains(textEditingValue.text.toLowerCase())).toList();
        
        try {
          final res = await Dio().get(
            'https://nominatim.openstreetmap.org/search',
            queryParameters: {
              'q': textEditingValue.text,
              'format': 'json',
              'addressdetails': 1,
              'limit': 10,
              'countrycodes': 'in',
            },
          );
          if (res.statusCode == 200) {
            final List results = res.data;
            final networkCities = results.map((item) {
              final addr = item['address'];
              return addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['state'] ?? item['display_name'];
            }).whereType<String>().toSet();
            return {...local, ...networkCities}.toList();
          }
        } catch (e) {
          debugPrint('Search error: $e');
        }
        return local;
      },
      onSelected: (String selection) => controller.text = selection,
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        if (textController.text != controller.text) textController.text = controller.text;
        textController.addListener(() => controller.text = textController.text);
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)))),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 48,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(dense: true, title: Text(option, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), onTap: () => onSelected(option));
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
