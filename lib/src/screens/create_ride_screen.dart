import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../constants/locations.dart';
import '../utils/snackbar_helper.dart';

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
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rulesController = TextEditingController();
  final _coverImageController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  DateTime _arrivalDate = DateTime.now().add(const Duration(days: 1, hours: 1));
  TransportMode _transportMode = TransportMode.bike;
  GenderPreference _genderPreference = GenderPreference.any;
  bool _isPrivateCircle = false; // Visibility: false = ANYONE, true = CIRCLE
  bool _generateItinerary = false;
  bool _isLoading = false;
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

  Future<void> _submitRide() async {
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


  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('New Ride', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1.0)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Form(
          key: _formKey,
    // Add _buildAutocompleteField inside _CreateRideScreenState if needed or use standalone
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Cover Theme ────────────────────────────────────────────
              const Text('Trip Theme', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 16),
              SizedBox(
                height: 110,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _themes.entries.map((entry) {
                    final isSelected = _coverImageController.text == entry.value;
                    return GestureDetector(
                      onTap: () => setState(() => _coverImageController.text = entry.value),
                      child: Container(
                        width: 160,
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: isSelected
                              ? Border.all(color: primary, width: 3)
                              : Border.all(color: Colors.transparent),
                          image: DecorationImage(image: NetworkImage(entry.value), fit: BoxFit.cover),
                          boxShadow: isSelected
                              ? [BoxShadow(color: primary.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]
                              : null,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.black.withOpacity(0.4),
                          ),
                          alignment: Alignment.center,
                          child: Text(entry.key,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ── Pre-selected Passengers ────────────────────────────────
              if (_currentSelectedMembers.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Text('Journey Passengers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Column(
                    children: _currentSelectedMembers.map((member) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            height: 36,
                            width: 36,
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                            child: Center(
                              child: Text(
                                (member['name'] as String).isNotEmpty ? member['name'][0].toUpperCase() : '?',
                                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF475569)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(member['name'] as String,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _currentSelectedMembers.remove(member)),
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 20),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ],

              // ── Route ─────────────────────────────────────────────────
              const SizedBox(height: 32),
              const Text('Route', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 16),
              // ── Ride Name ─────────────────────────────────────────────
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Ride Name (optional)',
                  hintText: 'e.g. Winter Spiti Ride',
                  prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded),
                  fillColor: Colors.grey[100],
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildLocationAutocomplete(
                      label: 'From',
                      icon: Icons.my_location,
                      controller: _originController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLocationAutocomplete(
                      label: 'To',
                      icon: Icons.location_on,
                      controller: _destinationController,
                    ),
                  ),
                ],
              ),

              // ── Expedition Timeline (Start & Finish) ─────────────────────────
              const SizedBox(height: 32),
              const Text('Timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDateTime(context, false),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(DateFormat('MMM dd, HH:mm').format(_selectedDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDateTime(context, true),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Finish', style: TextStyle(fontSize: 10, color: Colors.indigo, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(DateFormat('MMM dd, HH:mm').format(_arrivalDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                  child: Text('Total Days: $_calculatedDuration', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
              ),

              // ── Seats & Price ──────────────────────────────────────────
              const SizedBox(height: 24),
              const Text('Logistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _seatsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Seats',
                        prefixIcon: const Icon(Icons.event_seat),
                        fillColor: Colors.grey[100],
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Price (₹)',
                        prefixIcon: const Icon(Icons.currency_rupee),
                        fillColor: Colors.grey[100],
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),

              // ── Join Policy ──────────────────────────────────────────
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
                          const Text('Policy', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                          Text(_isPrivateCircle ? 'Buddies & Groups Only' : 'Open to Anyone', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isPrivateCircle, 
                      onChanged: (v) => setState(() => _isPrivateCircle = v),
                      activeColor: Colors.blue,
                    ),
                  ],
                ),
              ),

              // ── Transport Mode ─────────────────────────────────────────
              const SizedBox(height: 16),
              DropdownButtonFormField<TransportMode>(
                value: _transportMode,
                decoration: InputDecoration(
                  labelText: 'Transport Mode',
                  prefixIcon: const Icon(Icons.directions_car),
                  fillColor: Colors.grey[100],
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                items: TransportMode.values.map((mode) =>
                  DropdownMenuItem(value: mode, child: Text('${mode.emoji} ${mode.label}'))).toList(),
                onChanged: (v) => setState(() => _transportMode = v!),
              ),

              // ── Gender Preference ──────────────────────────────────────
              const SizedBox(height: 16),
              DropdownButtonFormField<GenderPreference>(
                initialValue: _genderPreference,
                decoration: InputDecoration(
                  labelText: 'Gender Preference',
                  prefixIcon: const Icon(Icons.people_alt_rounded),
                  fillColor: Colors.grey[100],
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                items: GenderPreference.values.map((pref) =>
                  DropdownMenuItem(value: pref, child: Text(pref.label))).toList(),
                onChanged: (v) => setState(() => _genderPreference = v!),
              ),

              // ── Description ────────────────────────────────────────────
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Tell us about the trip',
                  alignLabelWithHint: true,
                  fillColor: Colors.grey[100],
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),

              // ── Rules ──────────────────────────────────────────────────
              const SizedBox(height: 16),
              TextFormField(
                controller: _rulesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Rules & Guidelines (optional)',
                  alignLabelWithHint: true,
                  fillColor: Colors.grey[100],
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),

              // ── AI Itinerary Toggle ────────────────────────────────────
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: SwitchListTile(
                  title: const Text('AI Itinerary', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Auto-draft a full travel plan ✨', style: TextStyle(fontSize: 11)),
                  value: _generateItinerary,
                  onChanged: (v) => setState(() => _generateItinerary = v),
                  secondary: const Icon(Icons.auto_awesome, color: Colors.amber),
                ),
              ),

              // ── Submit ─────────────────────────────────────────────────
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitRide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Publish Adventure 🌍', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildLocationAutocomplete({
    required String label,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.length < 2) {
          return const Iterable<String>.empty();
        }

        // 1. Search local favorites first for speed
        final localMatches = indianCities.where((String city) {
          return city.toLowerCase().contains(textEditingValue.text.toLowerCase());
        }).toList();

        // 2. Fetch from Network (Nominatim) for exact/obscure places
        try {
          final res = await Dio().get(
            'https://nominatim.openstreetmap.org/search',
            queryParameters: {
              'q': textEditingValue.text,
              'format': 'json',
              'addressdetails': 1,
              'limit': 10,
              'countrycodes': 'in', // Limit to India as requested
            },
          );
          if (res.statusCode == 200) {
            final List results = res.data;
            final networkCities = results.map((item) {
              final addr = item['address'];
              return addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['state'] ?? item['display_name'];
            }).whereType<String>().toSet();
            
            return {...localMatches, ...networkCities}.toList();
          }
        } catch (e) {
          debugPrint('Place search error: $e');
        }

        return localMatches;
      },
      onSelected: (String selection) {
        controller.text = selection;
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        // Sync initial value
        if (textController.text != controller.text) {
          textController.text = controller.text;
        }
        textController.addListener(() {
          controller.text = textController.text;
        });

        return TextFormField(
          controller: textController,
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
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: (MediaQuery.of(context).size.width - 64) / 2, 
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
