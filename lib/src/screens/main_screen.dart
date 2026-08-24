import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/flettra_colors.dart';
import '../widgets/common_fab.dart';
import 'buddies_screen.dart';
import 'groups_screen.dart';
import 'profile_screen.dart';
import 'ride_list_screen.dart';
import 'timeline_screen.dart';

/// Tab order is Rides → Feed → Circles → Chats → You.
///
/// This replaces Home → Feed → Rides → Groups → Profile. "Home" and "Rides"
/// were two entries into the same content, which cost a slot and made neither
/// obvious; the full ride list is now reached from "See all" on the Rides tab.
/// "Groups" and "Profile" are renamed to the words the product actually uses.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final GlobalKey<RideListScreenState> _rideListKey =
      GlobalKey<RideListScreenState>();
  final GlobalKey<TimelineScreenState> _timelineKey =
      GlobalKey<TimelineScreenState>();

  late final List<Widget> _pages;

  static const _tabs = <_Tab>[
    _Tab(Icons.directions_car_outlined, Icons.directions_car_rounded, 'Rides'),
    _Tab(Icons.article_outlined, Icons.article_rounded, 'Feed'),
    _Tab(Icons.groups_outlined, Icons.groups_rounded, 'Circles'),
    _Tab(Icons.forum_outlined, Icons.forum_rounded, 'Chats'),
    _Tab(Icons.person_outline_rounded, Icons.person_rounded, 'You'),
  ];

  @override
  void initState() {
    super.initState();
    _pages = [
      RideListScreen(key: _rideListKey),
      TimelineScreen(key: _timelineKey),
      const GroupsScreen(),
      // Placeholder: the backend has no conversations endpoint yet — chat can
      // only be fetched per ride/buddy/group — so this lands on the buddy list,
      // which is where a conversation is started today. Swap for a real
      // conversation list once GET /chat/conversations exists.
      const BuddiesScreen(),
      const ProfileScreen(),
    ];
  }

  void setTab(int index) {
    if (mounted) setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final showFab = _currentIndex != 4;

    return Scaffold(
      backgroundColor: c.surface,
      // Deliberately a plain IndexedStack. Wrapping it in an AnimatedSwitcher
      // to cross-fade tab changes requires giving the subtree a new key per
      // index, which throws away every tab's State — scroll position and
      // already-loaded data included — so each tab switch would re-fetch. The
      // motion lives in the tab bar and in each screen's own entrance instead.
      body: IndexedStack(index: _currentIndex, children: _pages),
      floatingActionButton: showFab
          ? CommonFab(
              onPostCreated: () {
                setState(() => _currentIndex = 1);
                _timelineKey.currentState?.refresh();
              },
              onRideCreated: () => _rideListKey.currentState?.refresh(),
            )
          : null,
      bottomNavigationBar: _buildNavBar(c),
    );
  }

  /// A hairline above the bar, not a blurred shadow, and the height comes from
  /// the safe area rather than a hardcoded 72.
  Widget _buildNavBar(FlettraColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.rule, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(child: _buildNavBtn(i, _tabs[i], c)),
            ],
          ),
        ),
      ),
    );
  }

  /// A tab button.
  ///
  /// The icon lifts and scales as it becomes active and the colour animates
  /// rather than cutting, so a tab change reads as a movement between two
  /// places instead of an instant repaint. The whole bar previously changed
  /// with no transition at all.
  Widget _buildNavBtn(int index, _Tab tab, FlettraColors c) {
    final selected = _currentIndex == index;
    final color = selected ? c.brand : c.ink3;

    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      child: InkResponse(
        onTap: () {
          if (_currentIndex == index) return;
          HapticFeedback.selectionClick();
          setState(() => _currentIndex = index);
        },
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1.0,
              duration: AppDuration.base,
              curve: Curves.easeOutBack,
              child: AnimatedSlide(
                offset: Offset(0, selected ? -0.06 : 0),
                duration: AppDuration.base,
                curve: Curves.easeOut,
                child: Icon(selected ? tab.activeIcon : tab.icon,
                    color: color, size: 23),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs - 1),
            AnimatedDefaultTextStyle(
              duration: AppDuration.base,
              curve: Curves.easeOut,
              style: AppTypography.caption.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
              child: Text(tab.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

extension MainScreenExtension on BuildContext {
  void switchToTab(int index) {
    findAncestorStateOfType<_MainScreenState>()?.setTab(index);
  }
}
