import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/places_service.dart';

/// A TextFormField with Google Places city autocomplete dropdown.
///
/// Usage:
///   PlacesAutocompleteField(
///     controller: _locationController,
///     hint: 'Mumbai, India',
///     icon: Icons.location_on_outlined,
///     decoration: yourInputDecoration,  // pass the screen's existing decoration
///   )
class PlacesAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final InputDecoration Function(String hint, IconData icon) decorationBuilder;
  final String? Function(String?)? validator;
  final TextStyle? textStyle;
  final double dropdownMaxWidth; // constrain dropdown to half-width for side-by-side fields

  const PlacesAutocompleteField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.decorationBuilder,
    this.validator,
    this.textStyle,
    this.dropdownMaxWidth = double.infinity,
  });

  @override
  State<PlacesAutocompleteField> createState() => _PlacesAutocompleteFieldState();
}

class _PlacesAutocompleteFieldState extends State<PlacesAutocompleteField> {
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;

  List<PlacePrediction> _predictions = [];
  bool _loading = false;
  String _lastQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150), _removeOverlay);
    }
  }

  void _onTextChanged() {
    final query = widget.controller.text;
    if (query == _lastQuery) return;
    _lastQuery = query;

    if (query.trim().length < 2) {
      _debounce?.cancel();
      _removeOverlay();
      setState(() { _predictions = []; _loading = false; });
      return;
    }

    // Debounce: wait 400ms after user stops typing before firing API call
    _debounce?.cancel();
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await PlacesService.autocomplete(query);
      if (!mounted || widget.controller.text != query) return;
      setState(() {
        _predictions = results;
        _loading = false;
      });
      if (results.isNotEmpty && _focusNode.hasFocus) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    });
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);
    _overlay = OverlayEntry(builder: (ctx) => _buildDropdown());
    overlay.insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _select(PlacePrediction p) {
    _lastQuery = p.mainText;
    widget.controller.text = p.mainText;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: p.mainText.length),
    );
    _removeOverlay();
    setState(() => _predictions = []);
    _focusNode.unfocus();
  }

  Widget _buildDropdown() {
    return Positioned(
      width: widget.dropdownMaxWidth == double.infinity ? null : widget.dropdownMaxWidth,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 52),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          shadowColor: Colors.black.withOpacity(0.12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: widget.dropdownMaxWidth,
                maxHeight: 240,
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFF6B2C),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shrinkWrap: true,
                      itemCount: _predictions.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 48, endIndent: 12),
                      itemBuilder: (_, i) {
                        final p = _predictions[i];
                        return InkWell(
                          onTap: () => _select(p),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B2C).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    size: 14,
                                    color: Color(0xFFFF6B2C),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.mainText,
                                        style: GoogleFonts.dmSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1A0A08),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        p.description,
                                        style: GoogleFonts.dmSans(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                          fontWeight: FontWeight.w400,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        style: widget.textStyle,
        decoration: widget.decorationBuilder(widget.hint, widget.icon),
        validator: widget.validator,
        textInputAction: TextInputAction.next,
      ),
    );
  }
}
