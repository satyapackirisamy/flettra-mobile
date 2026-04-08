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

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isPasswordLogin = true;
  bool _obscurePassword = true;

  // Design Colors
  static const Color primaryOrange = Color(0xFFFF530A);
  static const Color primaryGradientStart = Color(0xFFFF530A);
  static const Color primaryGradientEnd = Color(0xFFFF8A50);
  static const Color inputFill = Color(0xFFFAFAFA);
  static const Color textDark = Color(0xFF18181B);
  static const Color textGray = Color(0xFF71717A);

  Future<void> _handleLogin() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Email')));
      return;
    }

    if (_isPasswordLogin) {
      // Password Login
      final password = _passwordController.text.trim();
      if (password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Password')));
        return;
      }

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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      // OTP Login
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send OTP: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Screen height for layout calculations
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Gradient Header
          Container(
            height: size.height * 0.40,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryGradientStart, primaryGradientEnd],
              ),
            ),
            child: Stack(
              children: [
                // Decorative circles
                Positioned(top: -50, right: -50, child: _buildBlurCircle(200, Colors.white.withOpacity(0.1))),
                Positioned(bottom: 50, left: -30, child: _buildBlurCircle(150, Colors.black.withOpacity(0.05))),
                
                // Logo & Title Content
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        // Logo Box
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 10))
                            ],
                          ),
                          child: const Icon(Icons.explore_rounded, color: primaryOrange, size: 48),
                        ),
                        const SizedBox(height: 24),
                        Text('Flettra', style: GoogleFonts.plusJakartaSans(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white, height: 1.0)),
                        const SizedBox(height: 8),
                        Text('Welcome back, adventurer.', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.9))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. White Body Content
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: size.height * 0.65,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 40, 28, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Sign In', style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, color: textDark)),
                        TextButton(
                           onPressed: () => setState(() => _isPasswordLogin = !_isPasswordLogin),
                           child: Text(
                             _isPasswordLogin ? 'Use OTP' : 'Use Password', 
                             style: GoogleFonts.plusJakartaSans(color: primaryOrange, fontWeight: FontWeight.bold)
                           ),
                        ),
                      ],
                    ),
                    Text(_isPasswordLogin ? 'Enter your credentials to continue.' : 'We will send you a code.', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: textGray)),
                    const SizedBox(height: 32),
                    
                    _buildInputLabel('Email Address'),
                    _buildInputField(
                      controller: _identifierController,
                      hint: 'john@example.com',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),

                    if (_isPasswordLogin) ...[
                      _buildInputLabel('Password'),
                      _buildInputField(
                        controller: _passwordController,
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        isObscure: _obscurePassword,
                        onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {}, // Forgot password logic placeholder
                          child: Text('Forgot Password?', style: GoogleFonts.plusJakartaSans(color: primaryOrange, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 8,
                          shadowColor: primaryOrange.withOpacity(0.4),
                        ),
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_isPasswordLogin ? 'Sign In' : 'Send Code', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, size: 22)
                              ],
                            ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                           Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegistrationScreen()));
                        },
                        child: Text.rich(
                          TextSpan(
                            text: 'New here? ',
                            style: GoogleFonts.plusJakartaSans(color: textGray, fontWeight: FontWeight.w500),
                            children: [
                              TextSpan(text: 'Create Account', style: GoogleFonts.plusJakartaSans(color: primaryOrange, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF18181B))),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isObscure = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF4F4F5)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        keyboardType: keyboardType,
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: const Color(0xFF18181B)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFFA1A1AA)),
          prefixIcon: Icon(icon, color: const Color(0xFFA1A1AA), size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFFA1A1AA)),
                  onPressed: onToggleObscure,
                )
              : null,
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFFF530A), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
      ),
    );
  }

  Widget _buildBlurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Container(), 
    );
  }
}
