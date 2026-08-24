import 'package:flutter/material.dart';
import '../theme/flettra_colors.dart';
import '../theme/app_typography.dart';
import 'dart:async';
import 'login_screen.dart';
import 'main_screen.dart';
import '../services/api_service.dart';
import '../widgets/network_image_widget.dart';

class OnboardingScreen extends StatefulWidget {
  final bool isPostAuth;

  const OnboardingScreen({super.key, this.isPostAuth = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;
  bool _completing = false;

  static const List<Map<String, dynamic>> _tutorialSlides = [
    {
      'icon': Icons.directions_car_rounded,
      'title': 'Create & Join Rides',
      'description': 'Share your commute or find travel buddies heading the same way. Save money and make friends!',
    },
    {
      'icon': Icons.groups_rounded,
      'title': 'Join Travel Circles',
      'description': 'Connect with groups based on your route, workplace, or interests. Plan trips together!',
    },
    {
      'icon': Icons.analytics_rounded,
      'title': 'Track Your Impact',
      'description': 'See your travel stats, earn compass points, and climb the leaderboard. Every ride counts!',
    },
    {
      'icon': Icons.star_rounded,
      'title': 'Rate & Review',
      'description': 'Build trust in the community by rating your travel companions after each ride.',
    },
  ];

  final List<Map<String, dynamic>> _slides = [
    {
      'image': 'https://images.unsplash.com/photo-1519681393784-d120267933ba?q=80&w=2070&auto=format&fit=crop',
      'smallText': "It's a Big World",
      'bigText': "Out There,\nGo Explore",
    },
    {
      'image': 'https://images.unsplash.com/photo-1539635278303-d4002c07eae3?q=80&w=2070&auto=format&fit=crop',
      'smallText': "Find Your Tribe",
      'bigText': "Journey With\nNew Friends",
    },
    {
      'image': 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?q=80&w=2021&auto=format&fit=crop',
      'smallText': "Share Moments",
      'bigText': "Plan Trips,\nCreate Stories",
    },
  ];

  @override
  void initState() {
    super.initState();
    if (!widget.isPostAuth) {
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_currentPage < _slides.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutQuint,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    setState(() => _completing = true);
    try {
      await ApiService().completeOnboarding();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete onboarding: $e')),
        );
        setState(() => _completing = false);
      }
    }
  }

  Widget _buildPostAuthOnboarding() {
    final slide = _tutorialSlides[_currentPage];
    // One accent across every slide. The per-slide colours were leftovers
    // from the retired indigo palette and made the intro look like four
    // different products.
    final color = context.c.brand;
    final isLast = _currentPage == _tutorialSlides.length - 1;

    return Scaffold(
      backgroundColor: context.c.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicators
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Row(
                children: List.generate(_tutorialSlides.length, (i) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i <= _currentPage ? color : context.c.rule,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Skip button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _completing ? null : _completeOnboarding,
                child: Text('Skip', style: AppTypography.dmSans(color: context.c.ink3, fontWeight: FontWeight.w700)),
              ),
            ),
            // Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _tutorialSlides.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final s = _tutorialSlides[index];
                  final c = s['color'] as Color;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120, height: 120,
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(s['icon'] as IconData, size: 56, color: c),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          s['title'] as String,
                          textAlign: TextAlign.center,
                          style: AppTypography.dmSans(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -1),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s['description'] as String,
                          textAlign: TextAlign.center,
                          style: AppTypography.dmSans(fontSize: 15, color: context.c.ink2, fontWeight: FontWeight.w600, height: 1.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Bottom button
            Padding(
              padding: const EdgeInsets.all(32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _completing
                      ? null
                      : () {
                          if (isLast) {
                            _completeOnboarding();
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: context.c.onBrand,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Text(
                    _completing ? 'Getting ready...' : isLast ? 'Get Started' : 'Next',
                    style: AppTypography.dmSans(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPostAuth) return _buildPostAuthOnboarding();

    // Current active color
    final activeColor = (_slides[_currentPage]['color'] as Color?) ?? context.c.brand;

    return Scaffold(
      backgroundColor: context.c.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Slides
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final slide = _slides[index];
              final slideColor = (slide['color'] as Color?) ?? context.c.brand;
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Background Image
                  SafeNetworkImage(
                    url: slide['image'] as String,
                    fit: BoxFit.cover,
                    errorWidget: Container(color: context.c.ink),
                  ),
                  
                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.1),
                          slideColor.withOpacity(0.4), // Tint with active color
                          Colors.black.withOpacity(0.9),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  
                  // Text Content
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(),
                          Text(
                            slide['smallText'] as String,
                            style: AppTypography.dmSans(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.9),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            slide['bigText'] as String,
                            style: AppTypography.dmSans(
                              fontSize: 56,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                              // Fixed white, not a token. This sits on a
                              // photograph, so its contrast comes from the
                              // image scrim rather than the theme — a surface
                              // token here turns the headline near-black in
                              // Nightshift.
                              color: Colors.white,
                              letterSpacing: -2.0,
                            ),
                          ),
                          const SizedBox(height: 160), 
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          
          // Fixed Bottom Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
              child: Column(
                children: [
                   // Top Indicators (Dynamic Color)
                  Row(
                    children: List.generate(
                      _slides.length,
                      (index) => Row(
                        children: [
                          _buildIndicator(index == _currentPage, (_slides[index]['color'] as Color?) ?? context.c.brand),
                          const SizedBox(width: 6),
                        ],
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Get Started Button with Animated Color
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeColor, // Dynamic Background
                        foregroundColor: context.c.onBrand,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        elevation: 8,
                        shadowColor: activeColor.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Get Started",
                            style: AppTypography.dmSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Privacy Policy
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      "Privacy Policy",
                      style: AppTypography.dmSans(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          // Floating Camera Icon
          Positioned(
            top: 200,
            right: 40,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(bool isActive, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 6,
      width: isActive ? 32 : 12,
      decoration: BoxDecoration(
        color: isActive ? color : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isActive ? [
          BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))
        ] : [],
      ),
    );
  }
}
