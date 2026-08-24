import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_spacing.dart';

/// Shared motion primitives.
///
/// Before this file, animation in the app was ad-hoc: `_PressableCard` lived
/// privately inside `ride_list_screen`, two screens hand-rolled a fade with
/// their own `AnimationController`, and everything else had no feedback at all —
/// which is what "the animation is not good, not responsive" describes. A tap
/// that produces no visual change reads as a tap that did not register.
///
/// Durations come from [AppDuration] so motion stays consistent, and every
/// widget here degrades to a plain child when the platform asks for reduced
/// motion.

/// True when the OS accessibility setting asks for less animation.
bool prefersReducedMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

// ─────────────────────────────────────────────────────────────────────────────
// Press feedback
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps any tappable thing so it scales and dims slightly while held.
///
/// Use this instead of a bare [GestureDetector] on cards, chips and custom
/// buttons. `InkWell`'s ripple is fine on a flat list row but invisible on a
/// dark card with its own background, which is most of this app.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.haptic = true,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How far down to scale while held. Cards can take 0.965; a small icon
  /// button needs less travel to read, so it defaults gentler.
  final double scale;

  /// Light impact on tap. Turn it off for anything that fires repeatedly.
  final bool haptic;

  /// Only needed when the child is transparent and needs a highlight shape.
  final BorderRadius? borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _held = false;

  void _set(bool v) {
    if (_held != v && mounted) setState(() => _held = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    if (!enabled) return widget.child;

    final reduced = prefersReducedMotion(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (widget.haptic) HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!.call();
            },
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _held && !reduced ? widget.scale : 1.0,
        duration: AppDuration.fast,
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _held ? 0.86 : 1.0,
          duration: AppDuration.fast,
          child: widget.child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Entrance
// ─────────────────────────────────────────────────────────────────────────────

/// Fades and lifts a widget in once, on first build.
///
/// [index] staggers a list: item n starts `n * stagger` after the first. Cap the
/// index (`index.clamp(0, 8)`) on long lists so the tail is not left waiting.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 12,
    this.duration = AppDuration.slow,
    this.stagger = const Duration(milliseconds: 45),
  });

  final Widget child;
  final int index;
  final double offset;
  final Duration duration;
  final Duration stagger;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _anim =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    final delay = widget.stagger * widget.index;
    if (delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future<void>.delayed(delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (prefersReducedMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Opacity(
        opacity: _anim.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _anim.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Value transitions
// ─────────────────────────────────────────────────────────────────────────────

/// Counts from the previous value to the new one whenever [value] changes.
///
/// Used for money and totals — an expense total that snaps from ₹200 to ₹450
/// gives no sense that something was added.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.builder,
    this.duration = const Duration(milliseconds: 550),
  });

  final double value;
  final Widget Function(BuildContext context, double value) builder;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (prefersReducedMotion(context)) return builder(context, value);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => builder(context, v),
    );
  }
}

/// Cross-fades between loading, empty and loaded states of the same region.
///
/// A `ListView` that is replaced outright by a spinner (and back) makes the
/// whole screen blink. Fading between them is what makes a refresh feel quick
/// even when it is not.
class StateSwitcher extends StatelessWidget {
  const StateSwitcher({super.key, required this.child, this.duration});

  final Widget child;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration ?? AppDuration.base,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, if (current != null) current],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Route transitions
// ─────────────────────────────────────────────────────────────────────────────

/// A page route that slides up from the bottom — for anything modal-feeling
/// (the live map, a full-screen sheet).
Route<T> slideUpRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: AppDuration.base,
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: anim, child: child),
      ),
    );

/// A page route that fades and scales in gently — for drilling into detail
/// where a horizontal push would fight a Hero image.
Route<T> fadeThroughRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: AppDuration.fast,
      transitionsBuilder: (_, anim, __, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
