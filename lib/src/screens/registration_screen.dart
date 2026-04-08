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

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _locationController = TextEditingController();
  final _authService = AuthService();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _agreedToTerms = false;

  // Design Colors
  static const Color primaryOrange = Color(0xFFFF530A);
  static const Color primaryGradientStart = Color(0xFFFF530A);
  static const Color primaryGradientEnd = Color(0xFFFF8A50);
  static const Color inputFill = Color(0xFFFAFAFA);
  static const Color textDark = Color(0xFF18181B); // Zinc 900
  static const Color textGray = Color(0xFF71717A); // Zinc 500

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please agree to the Terms & Privacy Policy')));
      return;
    }

    setState(() => _isLoading = true);
    
    final fullName = _nameController.text.trim();
    final nameParts = fullName.split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'Traveler';

    try {
      await _authService.register({
        'firstName': firstName,
        'lastName': lastName,
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'location': _locationController.text.trim(), // Added field
        // Default values for fields removed from UI but potentially needed by backend
        'age': 25, 
      });

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RideListScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                        Text('Your ultimate social travel companion.', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.9))),
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Create Account', style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, color: textDark)),
                      Text('Start your journey with us today.', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, color: textGray)),
                      const SizedBox(height: 32),
                      
                      _buildInputLabel('Full Name'),
                      _buildInputField(
                        controller: _nameController,
                        hint: 'John Doe',
                        icon: Icons.person_outline_rounded,
                        validator: (v) => v?.isEmpty ?? true ? 'Name required' : null,
                      ),
                      const SizedBox(height: 20),

                      _buildInputLabel('Email Address'),
                      _buildInputField(
                        controller: _emailController,
                        hint: 'john@example.com',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => !v!.contains('@') ? 'Invalid email' : null,
                      ),
                      const SizedBox(height: 20),

                      _buildInputLabel('Password'),
                      _buildInputField(
                        controller: _passwordController,
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        isObscure: _obscurePassword,
                        onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                        validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
                      ),
                      const SizedBox(height: 20),

                      _buildInputLabel('Location'),
                      _buildInputField(
                        controller: _locationController,
                        hint: 'New York, USA',
                        icon: Icons.location_on_outlined,
                      ),

                      const SizedBox(height: 24),

                      // Terms
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Checkbox(
                              value: _agreedToTerms,
                              onChanged: (v) => setState(() => _agreedToTerms = v!),
                              activeColor: primaryOrange,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                text: 'I agree to the ',
                                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: textGray),
                                children: [
                                  TextSpan(text: 'Terms', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: primaryOrange)),
                                  const TextSpan(text: ' and '),
                                  TextSpan(text: 'Privacy Policy', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: primaryOrange)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister,
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
                                  Text('Join the Adventure', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
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
                             Navigator.of(context).pushReplacement(
                               MaterialPageRoute(builder: (_) => const LoginScreen())
                             );
                          },
                          child: Text.rich(
                            TextSpan(
                              text: 'Already have an account? ',
                              style: GoogleFonts.plusJakartaSans(color: textGray, fontWeight: FontWeight.w500),
                              children: [
                                TextSpan(text: 'Sign In', style: GoogleFonts.plusJakartaSans(color: primaryOrange, fontWeight: FontWeight.bold)),
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
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF4F4F5)),
      ),
      child: TextFormField(
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.red),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
        validator: validator,
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
      child: Container(), // Backdrop filter removed to simplify for now, simple opacity circle
    );
  }
}
