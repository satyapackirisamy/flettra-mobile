import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'ride_list_screen.dart';
import 'login_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _locationController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _agreedToTerms = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Brand Colors
  static const Color primaryIndigo = Color(0xFF4F46E5);
  static const Color primaryIndigoDark = Color(0xFF3730A3);
  static const Color accentOrange = Color(0xFFFF530A);
  static const Color surfaceLight = Color(0xFFF8F7FF);
  static const Color inputFill = Color(0xFFF5F5F7);
  static const Color textDark = Color(0xFF18181B);
  static const Color textGray = Color(0xFF71717A);
  static const Color borderColor = Color(0xFFE4E4E7);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      _showSnack('Please agree to the Terms & Privacy Policy');
      return;
    }

    setState(() => _isLoading = true);

    final fullName = _nameController.text.trim();
    final nameParts = fullName.split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName =
        nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'Traveler';

    try {
      await _authService.register({
        'firstName': firstName,
        'lastName': lastName,
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'location': _locationController.text.trim(),
        'age': 25,
      });

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RideListScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Registration failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, fontWeight: FontWeight.w600),
        ),
        backgroundColor: textDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceLight,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ───────────────────────────────────────────
                _buildHeader(),

                // ── Form Card ────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withOpacity(0.06),
                        blurRadius: 32,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Form Header
                        Text(
                          'Create Account',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: textDark,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Join the adventure — it\'s free to start.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textGray,
                          ),
                        ),

                        const SizedBox(height: 22),

                        // Full Name
                        _buildInputLabel('Full Name'),
                        const SizedBox(height: 6),
                        _buildFormField(
                          controller: _nameController,
                          hint: 'John Doe',
                          icon: Icons.person_outline_rounded,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Name is required' : null,
                        ),

                        const SizedBox(height: 14),

                        // Email
                        _buildInputLabel('Email Address'),
                        const SizedBox(height: 6),
                        _buildFormField(
                          controller: _emailController,
                          hint: 'john@example.com',
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) =>
                              v == null || !v.contains('@') ? 'Enter a valid email' : null,
                        ),

                        const SizedBox(height: 14),

                        // Password
                        _buildInputLabel('Password'),
                        const SizedBox(height: 6),
                        _buildFormField(
                          controller: _passwordController,
                          hint: 'Min. 6 characters',
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                          isObscure: _obscurePassword,
                          onToggleObscure: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                          validator: (v) =>
                              v == null || v.length < 6 ? 'Minimum 6 characters' : null,
                        ),

                        const SizedBox(height: 14),

                        // Location
                        _buildInputLabel('Location'),
                        const SizedBox(height: 6),
                        _buildFormField(
                          controller: _locationController,
                          hint: 'Mumbai, India',
                          icon: Icons.location_on_outlined,
                        ),

                        const SizedBox(height: 18),

                        // Terms Row
                        _buildTermsRow(),

                        const SizedBox(height: 22),

                        // Register Button
                        _buildPrimaryButton(),

                        const SizedBox(height: 20),

                        // Divider
                        Row(
                          children: [
                            const Expanded(
                                child: Divider(color: Color(0xFFE4E4E7))),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'OR',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFA1A1AA),
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            const Expanded(
                                child: Divider(color: Color(0xFFE4E4E7))),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Sign In Link
                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                            ),
                            child: Text.rich(
                              TextSpan(
                                text: 'Already have an account? ',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: textGray,
                                  fontWeight: FontWeight.w500,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Sign in',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: primaryIndigo,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header Section ─────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand mark row
          Row(
            children: [
              // Logo badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryIndigo, Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: primaryIndigo.withOpacity(0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'F',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FLETTRA',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: textDark,
                      letterSpacing: 2.0,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'Social Travel',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textGray,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Back to login
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: textDark,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Hero headline
          Text(
            'Start your\njourney.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: textDark,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Connect with riders worldwide  ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textGray,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentOrange.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '✦ Free',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accentOrange,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Terms Row ───────────────────────────────────────────────────────────────
  Widget _buildTermsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: _agreedToTerms,
            onChanged: (v) => setState(() => _agreedToTerms = v!),
            activeColor: primaryIndigo,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5)),
            side: const BorderSide(color: borderColor, width: 1.5),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: 'I agree to the ',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: textGray, fontWeight: FontWeight.w500),
              children: [
                TextSpan(
                  text: 'Terms of Service',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primaryIndigo),
                ),
                TextSpan(
                  text: ' and ',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: textGray),
                ),
                TextSpan(
                  text: 'Privacy Policy',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primaryIndigo),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Input Label ─────────────────────────────────────────────────────────────
  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: textDark,
        letterSpacing: 0.2,
      ),
    );
  }

  // ─── Form Field (with validator) ─────────────────────────────────────────────
  Widget _buildFormField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isObscure = false,
    VoidCallback? onToggleObscure,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textDark,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: const Color(0xFFA1A1AA),
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, color: const Color(0xFFA1A1AA), size: 19),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isObscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFFA1A1AA),
                  size: 19,
                ),
                onPressed: onToggleObscure,
                splashRadius: 20,
              )
            : null,
        filled: true,
        fillColor: inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderColor, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryIndigo, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        errorStyle: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          color: const Color(0xFFEF4444),
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderColor),
        ),
      ),
      validator: validator,
    );
  }

  // ─── Primary Button ───────────────────────────────────────────────────────────
  Widget _buildPrimaryButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _isLoading
              ? null
              : const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [primaryIndigo, Color(0xFF7C3AED)],
                ),
          color: _isLoading ? const Color(0xFFE0E0E0) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isLoading
              ? []
              : [
                  BoxShadow(
                    color: primaryIndigo.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleRegister,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Join Flettra',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
