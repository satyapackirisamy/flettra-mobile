import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import '../services/auth_service.dart';
import 'ride_list_screen.dart';
import 'admin/admin_dashboard_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String identifier;
  final Map<String, dynamic>? registrationData;

  const OtpVerificationScreen({
    super.key,
    required this.identifier,
    this.registrationData,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _authService = AuthService();
  bool _isLoading = false;
  final _pinController = TextEditingController();

  Future<void> _handleVerify() async {
    if (_pinController.text.length != 6) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid 6-digit code')));
       return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.verifyOtp(
        widget.identifier, 
        _pinController.text,
        registrationData: widget.registrationData,
      );
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
            MaterialPageRoute(builder: (_) => const RideListScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const BackButton(),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              'Verify Identity',
              style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
            ),
             const SizedBox(height: 8),
            Text(
              'Enter the 6-digit code sent to ${widget.identifier}',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 48),

            Center(
              child: Pinput(
                length: 6,
                controller: _pinController,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: defaultPinTheme.copyDecorationWith(
                   border: Border.all(color: const Color(0xFF4F46E5), width: 2),
                   color: Colors.white,
                ),
                onCompleted: (pin) => _handleVerify(),
              ),
            ),

            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleVerify,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('VERIFY & ENTER'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
