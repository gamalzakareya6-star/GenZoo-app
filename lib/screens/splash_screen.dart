
import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/animations.dart';
import 'main_navigation_screen.dart';
import 'auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _navy = Color(0xFF0A1B3D);
  static const _gold = Color(0xFFD4AF37);

  late final AnimationController _intro =
      AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();

  late final AnimationController _spin =
      AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  late final Animation<double> _logoScale =
      CurvedAnimation(
    parent: _intro,
    curve: const Interval(
      0.0,
      0.45,
      curve: Curves.elasticOut,
    ),
  );

  late final Animation<double> _logoFade =
      CurvedAnimation(
    parent: _intro,
    curve: const Interval(
      0.0,
      0.25,
      curve: Curves.easeIn,
    ),
  );

  late final Animation<double> _ringFade =
      CurvedAnimation(
    parent: _intro,
    curve: const Interval(
      0.2,
      0.5,
      curve: Curves.easeOut,
    ),
  );

  late final Animation<double> _titleAnim =
      CurvedAnimation(
    parent: _intro,
    curve: const Interval(
      0.4,
      0.7,
      curve: Curves.easeOutCubic,
    ),
  );

  late final Animation<double> _taglineAnim =
      CurvedAnimation(
    parent: _intro,
    curve: const Interval(
      0.6,
      0.9,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void initState() {
    super.initState();
    _checkNavigation();
  }

  Future<void> _checkNavigation() async {
    // Keep the original splash animation visible.
    await Future.delayed(
      const Duration(milliseconds: 3000),
    );

    if (!mounted) return;

    final authProvider = Provider.of<UserAuthProvider>(
      context,
      listen: false,
    );

    try {
      // Wait for Firebase to restore the saved session.
      final firebaseUser = await FirebaseAuth.instance
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;

      if (firebaseUser != null) {
        // The Firebase session exists. Give the provider time
        // to load the user's Firestore profile.
        final deadline = DateTime.now().add(
          const Duration(seconds: 5),
        );

        while (authProvider.user == null &&
            DateTime.now().isBefore(deadline)) {
          await Future.delayed(
            const Duration(milliseconds: 100),
          );

          if (!mounted) return;
        }
      }
    } on TimeoutException {
      debugPrint(
        'Firebase session restoration timed out.',
      );
    } catch (e) {
      debugPrint(
        'Could not restore Firebase session: $e',
      );
    }

    if (!mounted) return;

    // A saved session means the user stays signed in (only an explicit
    // sign-out returns to the login screen).
    if (authProvider.user == null) {
      authProvider.restoreFromFirebaseSession();
    }

    final Widget next = authProvider.user != null
        ? const MainNavigationScreen()
        : const LoginScreen();

    Navigator.pushReplacement(
      context,
      AppRoute.fadeScale(next),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final logoSize = math.min(width * 0.58, 260.0);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Color(0xFF16336B),
              _navy,
            ],
            center: Alignment(0, -0.2),
            radius: 1.1,
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _intro,
              _spin,
            ]),
            builder: (context, _) {
              return Column(
                children: [
                  const Spacer(flex: 3),

                  // Logo with rotating golden ring.
                  SizedBox(
                    width: logoSize * 1.25,
                    height: logoSize * 1.25,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: _ringFade.value,
                          child: Transform.rotate(
                            angle:
                                _spin.value * 2 * math.pi,
                            child: CustomPaint(
                              size: Size.square(
                                logoSize * 1.25,
                              ),
                              painter: _RingPainter(_gold),
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: _logoFade.value,
                          child: Transform.scale(
                            scale: 0.3 +
                                0.7 * _logoScale.value,
                            child: AppLogo(
                              size: logoSize,
                              hero: true,
                              glow: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  Opacity(
                    opacity: _titleAnim.value,
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        20 * (1 - _titleAnim.value),
                      ),
                      child: const Text(
                        'GenZoo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Opacity(
                    opacity: _taglineAnim.value,
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        14 * (1 - _taglineAnim.value),
                      ),
                      child: Text(
                        'أسرة الطلاب  •  خطوات صغيرة .. أثر كبير',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _gold.withOpacity(0.95),
                          fontSize: 13,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 64,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _intro.value,
                        minHeight: 3,
                        backgroundColor: Colors.white12,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(
                          _gold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    'قسم علم الحيوان • كلية العلوم • جامعة المنوفية',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color color;

  _RingPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          color.withOpacity(0.0),
          color,
          color.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

    canvas.drawArc(
      rect.deflate(2),
      0,
      2 * math.pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _RingPainter old,
  ) {
    return old.color != color;
  }
}
