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
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B2C),
          primary: const Color(0xFFFF6B2C),
          secondary: const Color(0xFFFF8C5A),
          surface: Colors.white,
          error: const Color(0xFFF43F5E),
        ),
        textTheme: GoogleFonts.dmSansTextTheme(
          Theme.of(context).textTheme.apply(
            bodyColor: const Color(0xFF111111),
            displayColor: const Color(0xFF111111),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF111111),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111111),
            letterSpacing: -0.3,
            fontFamily: 'DM Sans',
          ),
          iconTheme: IconThemeData(color: Color(0xFF111111)),
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
            backgroundColor: const Color(0xFFFF6B2C),
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, fontFamily: 'DM Sans'),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF111111),
    contentTextStyle: const TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w500, color: Colors.white, fontSize: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 4,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  ),
  inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F5F7),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFFF6B2C), width: 1.5)),
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
             body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B2C))),
          );
        }
        if (snapshot.hasData && snapshot.data == true) {
          return FutureBuilder<Map<String, dynamic>>(
            future: _authService.getUser(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Colors.white,
                  body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B2C))),
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
