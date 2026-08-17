import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_typography.dart';
import 'theme/flettra_colors.dart';
import 'theme/theme_controller.dart';

class FlettraApp extends StatelessWidget {
  const FlettraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) => MaterialApp(
        title: 'Flettra',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        // Honour the phone's font-size setting, but bound it. Unbounded Dynamic
        // Type overflows every fixed-height row; ignoring it entirely — which is
        // what the app did before — fails anyone who has turned it up.
        builder: (context, child) {
          // On a near-black canvas, dark status-bar glyphs are invisible. The
          // app shipped with no overlay style at all, which was survivable on
          // white and is not now that dark is the default.
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: context.c.surfaceSunken,
              systemNavigationBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
            ),
            child: MediaQuery.withClampedTextScaling(
              minScaleFactor: AppTypography.minScale,
              maxScaleFactor: AppTypography.maxScale,
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        home: const AuthCheck(),
      ),
    );
  }
}

/// Shown while the session is being resolved. Takes its colours from the theme
/// so it does not flash white on a device in dark mode.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.c.surface,
      body: Center(
        child: CircularProgressIndicator(color: context.c.brand),
      ),
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
          return const _Splash();
        }
        if (snapshot.hasData && snapshot.data == true) {
          return FutureBuilder<Map<String, dynamic>>(
            future: _authService.getUser(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const _Splash();
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
