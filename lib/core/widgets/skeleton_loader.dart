import 'package:flutter/material.dart';

class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsets? margin;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1A1D24) : const Color(0xFFE8E8E8);
    final highlightColor = isDark ? const Color(0xFF2A2E38) : const Color(0xFFF5F5F5);

    return Container(
      margin: margin,
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [baseColor, highlightColor, baseColor],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: const _ShimmerEffect(),
    );
  }
}

class _ShimmerEffect extends StatefulWidget {
  const _ShimmerEffect();

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.0 + _controller.value * 2, 0),
              end: Alignment(0 + _controller.value * 2, 0),
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.08),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

class RoomCardSkeleton extends StatelessWidget {
  const RoomCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171A1F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF262A32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonLoader(width: 28, height: 28, borderRadius: 10),
              const Spacer(),
              const SkeletonLoader(width: 42, height: 24, borderRadius: 20),
            ],
          ),
          const Spacer(),
          const SkeletonLoader(width: 80, height: 18, borderRadius: 8),
          const SizedBox(height: 8),
          const SkeletonLoader(width: 50, height: 14, borderRadius: 6),
          const SizedBox(height: 12),
          Row(
            children: [
              const SkeletonLoader(width: 70, height: 24, borderRadius: 12),
              const SizedBox(width: 6),
              const SkeletonLoader(width: 60, height: 24, borderRadius: 12),
            ],
          ),
        ],
      ),
    );
  }
}

class StatsCardSkeleton extends StatelessWidget {
  const StatsCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171A1F),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF262A32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLoader(width: 100, height: 20, borderRadius: 8),
          const SizedBox(height: 14),
          ...List.generate(3, (index) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SkeletonLoader(width: 24, height: 24, borderRadius: 6),
                SizedBox(width: 12),
                Expanded(child: SkeletonLoader(width: double.infinity, height: 16, borderRadius: 6)),
                SizedBox(width: 8),
                SkeletonLoader(width: 60, height: 16, borderRadius: 6),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class MasterSwitchSkeleton extends StatelessWidget {
  const MasterSwitchSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171A1F),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF262A32)),
      ),
      child: Row(
        children: [
          const SkeletonLoader(width: 38, height: 38, borderRadius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLoader(width: 120, height: 16, borderRadius: 6),
                const SizedBox(height: 6),
                const SkeletonLoader(width: 100, height: 13, borderRadius: 5),
              ],
            ),
          ),
          const SkeletonLoader(width: 70, height: 34, borderRadius: 14),
        ],
      ),
    );
  }
}
