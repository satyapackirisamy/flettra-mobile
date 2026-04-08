import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'services/auth_service.dart';

class FlettraApp extends StatelessWidget {
  const FlettraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flettra',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFBFBFE),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          primary: const Color(0xFF4F46E5),
          secondary: const Color(0xFF7C3AED),
          surface: Colors.white,
          background: const Color(0xFFFBFBFE),
          error: const Color(0xFFF43F5E),
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          Theme.of(context).textTheme.apply(
            bodyColor: const Color(0xFF0F172A),
            displayColor: const Color(0xFF0F172A),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
          iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: const Color(0x0D4F46E5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            elevation: 8,
            shadowColor: const Color(0x4D4F46E5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.0),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.white,
    contentTextStyle: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700, color: Color(0xFF1E293B), fontSize: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 4,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  ),
  inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
          contentPadding: const EdgeInsets.all(20),
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      home: const AuthCheck(),
    );
  }
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  final AuthService _authService = AuthService();
  Future<bool>? _authFuture;

  @override
  void initState() {
    super.initState();
    _authFuture = _authService.isAuthenticated();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _authFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
             backgroundColor: Colors.white,
             body: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
          );
        }
        if (snapshot.hasData && snapshot.data == true) {
          return FutureBuilder<Map<String, dynamic>>(
            future: _authService.getUser(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Colors.white,
                  body: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
                );
              }
              if (userSnapshot.hasData) {
                final role = userSnapshot.data!['role']?.toString().toLowerCase();
                if (role == 'admin') {
                  return const AdminDashboardScreen();
                }
                final onboardingCompleted = userSnapshot.data!['onboardingCompleted'] == true;
                if (!onboardingCompleted) {
                  return const OnboardingScreen(isPostAuth: true);
                }
              }
              return const MainScreen();
            },
          );
        }
        return const OnboardingScreen();
      },
    );
  }
}
