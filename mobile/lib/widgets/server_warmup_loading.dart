import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ServerWarmupBanner extends StatefulWidget {
  final bool showWarmupMessage;
  final String title;
  final String loadingSubtitle;
  final String warmupSubtitle;

  const ServerWarmupBanner({
    super.key,
    required this.showWarmupMessage,
    this.title = 'Loading data',
    this.loadingSubtitle = 'Fetching latest updates from the server.',
    this.warmupSubtitle =
        'Backend is waking up after inactivity. First response can take up to 40 seconds.',
  });

  @override
  State<ServerWarmupBanner> createState() => _ServerWarmupBannerState();
}

class _ServerWarmupBannerState extends State<ServerWarmupBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.showWarmupMessage
        ? widget.warmupSubtitle
        : widget.loadingSubtitle;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = 0.94 + (_pulseController.value * 0.12);
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0E6F67), Color(0xFF2A9087)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.brand.withValues(alpha: 0.26),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.cloud_sync_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.showWarmupMessage
                            ? 'Warming up server'
                            : widget.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(999)),
              child: SizedBox(
                height: 5,
                child: LinearProgressIndicator(
                  backgroundColor: Color(0xFFD5E4E1),
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brand),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceSkeletonCard extends StatelessWidget {
  final bool showActionButton;

  const ServiceSkeletonCard({
    super.key,
    this.showActionButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return _SkeletonShimmer(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const _SkeletonBox(
                width: 52,
                height: 52,
                radius: 14,
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonLine(widthFactor: 0.52, height: 16),
                    SizedBox(height: 10),
                    _SkeletonLine(widthFactor: 0.74, height: 12),
                    SizedBox(height: 8),
                    _SkeletonLine(widthFactor: 0.62, height: 12),
                  ],
                ),
              ),
              if (showActionButton) ...[
                const SizedBox(width: 12),
                const _SkeletonBox(width: 72, height: 40, radius: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class BookingHistorySkeletonTile extends StatelessWidget {
  const BookingHistorySkeletonTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SkeletonShimmer(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              _SkeletonBox(width: 40, height: 40, radius: 999),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonLine(widthFactor: 0.56, height: 14),
                    SizedBox(height: 8),
                    _SkeletonLine(widthFactor: 0.36, height: 11),
                  ],
                ),
              ),
              SizedBox(width: 10),
              _SkeletonBox(width: 18, height: 18, radius: 999),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double widthFactor;
  final double height;

  const _SkeletonLine({
    required this.widthFactor,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: _SkeletonBox(
        width: double.infinity,
        height: height,
        radius: 8,
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFDCE7E4),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _SkeletonShimmer extends StatefulWidget {
  final Widget child;

  const _SkeletonShimmer({required this.child});

  @override
  State<_SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<_SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
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
      child: widget.child,
      builder: (context, child) {
        final value = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.2 + (value * 2.4), -0.2),
              end: Alignment(-0.2 + (value * 2.4), 0.2),
              colors: const [
                Color(0xFFD3E1DE),
                Color(0xFFF1F7F5),
                Color(0xFFD3E1DE),
              ],
              stops: const [0.1, 0.45, 0.8],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}
