/// Plan 02-06: BookCardShimmer — optimistic-insert placeholder.
///
/// Hand-rolled ShaderMask-based shimmer (no external `shimmer` package,
/// per 02-CONTEXT Claude's Discretion). Plan 07 renders one of these
/// in the library grid for every book that is mid-import (per D-11).
///
/// Colors come from `ClayColors` only — the dark stops are
/// `ClayColors.borderSubtle` and the highlight sweep is
/// `ClayColors.background`. No new palette introduced.
///
/// [filename] is carried so that Plan 07 can show it below the shimmer
/// as a tooltip or helper text if desired — the widget itself does not
/// render it yet.
library;

import 'package:flutter/material.dart';

import '../../core/theme/clay_colors.dart';

class BookCardShimmer extends StatefulWidget {
  final String filename;
  const BookCardShimmer({super.key, required this.filename});

  @override
  State<BookCardShimmer> createState() => _BookCardShimmerState();
}

class _BookCardShimmerState extends State<BookCardShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
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
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            // Sweep a highlight band from -1..1 across the card. The
            // controller value is 0..1 so `-1 - 2 * value` runs from
            // -1 to -3 and `1 - 2 * value` runs from 1 to -1, which
            // animates the gradient off-screen to the right.
            final t = _controller.value;
            return LinearGradient(
              begin: Alignment(-1.0 - 2 * t, 0),
              end: Alignment(1.0 - 2 * t, 0),
              colors: const [
                ClayColors.borderSubtle,
                ClayColors.background,
                ClayColors.borderSubtle,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Placeholder cover — same 2:3 aspect ratio as BookCard.
              AspectRatio(
                aspectRatio: 2 / 3,
                child: Container(color: ClayColors.borderSubtle),
              ),
              const SizedBox(height: 8),
              // Placeholder for title line.
              Container(
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: ClayColors.borderSubtle,
              ),
              const SizedBox(height: 4),
              // Placeholder for author line (shorter).
              Container(
                height: 10,
                width: 80,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: ClayColors.borderSubtle,
              ),
            ],
          ),
        );
      },
    );
  }
}
