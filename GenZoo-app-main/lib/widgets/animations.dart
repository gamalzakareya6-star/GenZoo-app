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
