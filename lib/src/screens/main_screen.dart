import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'ride_list_screen.dart';
import 'timeline_screen.dart';
import 'all_rides_screen.dart';
import 'groups_screen.dart';
import 'profile_screen.dart';
import '../widgets/common_fab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final GlobalKey<RideListScreenState> _rideListKey = GlobalKey<RideListScreenState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      RideListScreen(key: _rideListKey),
      const TimelineScreen(),
      const AllRidesScreen(),
      const GroupsScreen(),
      const ProfileScreen(),
    ];
  }

  void setTab(int index) {
    if (mounted) setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Hide FAB only on Profile tab
    final bool showFab = _currentIndex != 4;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true, 
      body: Stack(
        children: [
          // 1. The Main Content
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
          
          // 2. The Global CREATION Action
          if (showFab) Positioned(
            right: 16,
            bottom: 100, 
            child: CommonFab(
              onPostCreated: () {},
              onRideCreated: () => _rideListKey.currentState?.refresh(),
            ),
          ),
          
          // 3. The Premium Bottom Navigation Shell
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2), width: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavBtn(0, Icons.home_rounded, 'Home'),
                      _buildNavBtn(1, Icons.rss_feed_rounded, 'Feed'),
                      _buildNavBtn(2, Icons.directions_car_rounded, 'Rides'),
                      _buildNavBtn(3, Icons.groups_rounded, 'Groups'),
                      _buildNavBtn(4, Icons.person_rounded, 'Profile'),
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

  Widget _buildNavBtn(int index, IconData icon, String label) {
    bool isSelected = _currentIndex == index;
    Color activeColor = const Color(0xFFFF5500); 
    
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: isSelected ? 1.1 : 1.0,
              child: Icon(
                icon,
                color: isSelected ? activeColor : Colors.grey[400],
                size: 26,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: isSelected ? activeColor : Colors.grey[400],
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension MainScreenExtension on BuildContext {
  void switchToTab(int index) {
    final state = findAncestorStateOfType<_MainScreenState>();
    state?.setTab(index);
  }
}
