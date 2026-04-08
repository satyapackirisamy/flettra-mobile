import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../services/auth_service.dart';
import 'otp_verification_screen.dart';
import 'registration_screen.dart';
import 'main_screen.dart';
import 'admin/admin_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isPasswordLogin = true;
  bool _obscurePassword = true;
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
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      _showSnack('Please enter your email address');
      return;
    }

    if (_isPasswordLogin) {
      final password = _passwordController.text.trim();
      if (password.isEmpty) {
        _showSnack('Please enter your password');
        return;
      }

      setState(() => _isLoading = true);
      try {
        await _authService.login(identifier, password);
        final user = await _authService.getUser();
        if (mounted) {
          final role = user['role']?.toString().toLowerCase();
          if (role == 'admin') {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
              (route) => false,
            );
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainScreen()),
              (route) => false,
            );
          }
        }
      } catch (e) {
        if (mounted) {
          String msg = 'Login failed. Please check your credentials.';
          if (e is DioException && e.response?.statusCode == 401) {
            msg = 'Invalid email or password.';
          }
          _showSnack(msg);
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = true);
      try {
        await _authService.sendOtp(identifier);
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(identifier: identifier),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          _showSnack('Failed to send OTP. Please try again.');
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)),
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
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header ──────────────────────────────────────────
                    _buildHeader(),

                    // ── Form Card ────────────────────────────────────────
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Form Header Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sign In',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: textDark,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _isPasswordLogin
                                          ? 'Welcome back, adventurer.'
                                          : 'We\'ll send a code to your email.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: textGray,
                                      ),
                                    ),
                                  ],
                                ),
                                _buildToggleChip(),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Email Field
                            _buildInputLabel('Email Address'),
                            const SizedBox(height: 6),
                            _buildInputField(
                              controller: _identifierController,
                              hint: 'john@example.com',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                            ),

                            if (_isPasswordLogin) ...[
                              const SizedBox(height: 16),
                              _buildInputLabel('Password'),
                              const SizedBox(height: 6),
                              _buildInputField(
                                controller: _passwordController,
                                hint: 'Your password',
                                icon: Icons.lock_outline_rounded,
                                isPassword: true,
                                isObscure: _obscurePassword,
                                onToggleObscure: () =>
                                    setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {},
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Forgot password?',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: accentOrange,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Login Button
                            _buildPrimaryButton(),

                            const SizedBox(height: 20),

                            // Divider
                            Row(
                              children: [
                                const Expanded(child: Divider(color: Color(0xFFE4E4E7))),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                const Expanded(child: Divider(color: Color(0xFFE4E4E7))),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Register Link
                            Center(
                              child: GestureDetector(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const RegistrationScreen()),
                                ),
                                child: Text.rich(
                                  TextSpan(
                                    text: 'New to Flettra? ',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: textGray,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Create account',
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
        ),
      ),
    );
  }

  // ─── Header Section ─────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
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
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Subtle route/road motif
                    Positioned(
                      bottom: 8,
                      child: Container(
                        width: 20,
                        height: 2,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                    Text(
                      'F',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ],
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
              // Adventure icon accent
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentOrange.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.two_wheeler_rounded,
                  color: accentOrange,
                  size: 20,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Hero headline
          Text(
            'Welcome\nback.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 34,
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
                'Your next adventure awaits  ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textGray,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryIndigo.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '✦ Ride on',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: primaryIndigo,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── OTP / Password Toggle ───────────────────────────────────────────────────
  Widget _buildToggleChip() {
    return GestureDetector(
      onTap: () => setState(() => _isPasswordLogin = !_isPasswordLogin),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: primaryIndigo.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primaryIndigo.withOpacity(0.15)),
        ),
        child: Text(
          _isPasswordLogin ? 'Use OTP' : 'Use Password',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: primaryIndigo,
            letterSpacing: 0.3,
          ),
        ),
      ),
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

  // ─── Input Field ─────────────────────────────────────────────────────────────
  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isObscure = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
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
                  isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: const Color(0xFFA1A1AA),
                  size: 19,
                ),
                onPressed: onToggleObscure,
                splashRadius: 20,
              )
            : null,
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderColor, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryIndigo, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderColor),
        ),
      ),
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
          onPressed: _isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      _isPasswordLogin ? 'Sign In' : 'Send Code',
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
