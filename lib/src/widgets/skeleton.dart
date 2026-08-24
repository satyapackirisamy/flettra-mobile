import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_spacing.dart';
import '../theme/flettra_colors.dart';

/// Skeleton placeholders.
///
/// `shimmer` has been in pubspec since the first release and was never used:
/// every loading state in the app was a centred spinner, which replaces the
/// whole screen and gives no hint of what is arriving. A skeleton in the shape
/// of the content makes the same wait read as fast, because the layout is
/// already there when the data lands.

/// Wraps skeleton shapes in the shimmer sweep. One [Shimmer] around a whole
/// group is much cheaper than one per box.
class SkeletonGroup extends StatelessWidget {
  const SkeletonGroup({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // Respect the reduced-motion setting: static blocks, no sweep.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return Shimmer.fromColors(
      baseColor: c.surfaceSunken,
      highlightColor:
          Color.alphaBlend(c.ink3.withValues(alpha: 0.14), c.surfaceSunken),
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// A single rounded block. Colour is opaque so the shimmer gradient shows.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppRadius.chip,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.c.surfaceSunken,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Circular block, for avatar placeholders.
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.c.surfaceSunken,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// The shape of a ride card in the home list: cover image, title, two meta
/// lines, a price pill.
class RideCardSkeleton extends StatelessWidget {
  const RideCardSkeleton({super.key, this.width = 280});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.c.surfaceRaised,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: context.c.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(height: 120, radius: AppRadius.card),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: width * 0.6, height: 15),
                const SizedBox(height: AppSpacing.xs),
                SkeletonBox(width: width * 0.45, height: 11),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const SkeletonCircle(size: 24),
                    const SizedBox(width: AppSpacing.xs),
                    SkeletonBox(width: width * 0.3, height: 11),
                    const Spacer(),
                    const SkeletonBox(
                        width: 48, height: 18, radius: AppRadius.pill),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A horizontal strip of ride-card skeletons, for the home carousels.
class RideCarouselSkeleton extends StatelessWidget {
  const RideCarouselSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SkeletonGroup(
      child: SizedBox(
        height: 232,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: AppSpacing.screenH,
          itemCount: count,
          itemBuilder: (_, __) => const RideCardSkeleton(),
        ),
      ),
    );
  }
}

/// Avatar + two text lines. Covers buddy lists, member lists, request lists.
class ListRowSkeleton extends StatelessWidget {
  const ListRowSkeleton({super.key, this.avatarSize = 44});

  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          SkeletonCircle(size: avatarSize),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 140, height: 14),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(width: 90, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `count` list rows under one shimmer.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 6, this.avatarSize = 44});

  final int count;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    return SkeletonGroup(
      child: Column(
        children: List<Widget>.generate(
          count,
          (_) => ListRowSkeleton(avatarSize: avatarSize),
        ),
      ),
    );
  }
}

/// A feed post: author row, two text lines, a wide image block.
class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.c.surfaceRaised,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: context.c.rule),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonCircle(size: 36),
              SizedBox(width: AppSpacing.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 110, height: 12),
                  SizedBox(height: 6),
                  SkeletonBox(width: 70, height: 10),
                ],
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(width: double.infinity, height: 12),
          SizedBox(height: 6),
          SkeletonBox(width: 220, height: 12),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(
              width: double.infinity, height: 150, radius: AppRadius.card),
        ],
      ),
    );
  }
}

/// `count` feed posts under one shimmer.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SkeletonGroup(
      child: Column(
        children: List<Widget>.generate(count, (_) => const PostSkeleton()),
      ),
    );
  }
}
