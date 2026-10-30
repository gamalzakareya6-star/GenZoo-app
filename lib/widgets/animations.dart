import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Shared logo widget (circular GenZoo emblem). Use [heroTag] to fly between screens.
class AppLogo extends StatelessWidget {
  final double size;
  final bool hero;
  final bool glow;

  const AppLogo({super.key, this.size = 48, this.hero = false, this.glow = false});

  @override
  Widget build(BuildContext context) {
    Widget logo = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: glow
            ? [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withOpacity(0.35),
                  blurRadius: size * 0.25,
                  spreadRadius: size * 0.02,
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: Image.asset(
          size > 120 ? 'assets/images/logo.png' : 'assets/images/logo_small.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
    if (hero) logo = Hero(tag: 'app_logo', child: logo);
    return logo;
  }
}

/// Fades + slides a child up when first built. [index] staggers list items.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final double offsetY;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 450),
    this.offsetY = 24,
  });

  @override
  Widget build(BuildContext context) {
    // Cap the stagger so long lists don't feel slow
    final delay = Duration(milliseconds: math.min(index, 8) * 60);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Interval(
        delay.inMilliseconds / (duration + delay).inMilliseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * offsetY), child: child),
      ),
      child: child,
    );
  }
}

/// Gently floats a child up and down (used for the logo on the login screen).
class Floating extends StatefulWidget {
  final Widget child;
  final double distance;
  const Floating({super.key, required this.child, this.distance = 6});

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, (Curves.easeInOut.transform(_c.value) - 0.5) * widget.distance * 2),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Keeps a PageView page alive so tab state (scroll, counters) isn't lost.
class KeepAlivePage extends StatefulWidget {
  final Widget child;
  const KeepAlivePage({super.key, required this.child});

  @override
  State<KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Page transitions used across the app.
class AppRoute {
  /// Fade + slight upward slide (default for pushing screens).
  static Route<T> fadeSlide<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, secondary, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// Soft cross-fade with scale (splash -> login/main).
  static Route<T> fadeScale<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 700),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: 1.04, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }
}

/// Shrinks its child slightly while pressed and springs back on release.
/// It only reacts visually; taps are handled by the child (InkWell, buttons).
class PressableScale extends StatefulWidget {
  final Widget child;
  final double pressedScale;
  const PressableScale({super.key, required this.child, this.pressedScale = 0.97});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A grey block with a moving highlight, used as a loading placeholder.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 10});

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF273449) : const Color(0xFFE2E8F0);
    final shine = dark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value * 3 - 1; // sweeps from -1 to 2
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t, 0),
              colors: [base, shine, base],
            ),
          ),
        );
      },
    );
  }
}

/// Placeholder cards shown while a feed is loading.
class FeedSkeleton extends StatelessWidget {
  final int count;
  const FeedSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: count,
      itemBuilder: (_, i) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                SkeletonBox(width: 60, height: 18, radius: 6),
                SizedBox(width: 8),
                SkeletonBox(width: 80, height: 18, radius: 6),
              ]),
              SizedBox(height: 14),
              SkeletonBox(height: 16),
              SizedBox(height: 8),
              SkeletonBox(width: 220, height: 12),
              SizedBox(height: 6),
              SkeletonBox(width: 160, height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
