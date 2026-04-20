import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _GlowBlob(
              size: 220,
              color: AppTheme.brand.withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -70,
            child: _GlowBlob(
              size: 260,
              color: AppTheme.accent.withValues(alpha: 0.16),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}