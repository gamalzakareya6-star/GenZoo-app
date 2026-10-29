import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_colors.dart';

/// Qibla direction from the device GPS position and compass.
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  static const double _kaabaLat = 21.422487;
  static const double _kaabaLng = 39.826206;

  Position? _position;
  String? _problem;
  bool _canOpenSettings = false;
  bool _loading = true;
  bool _wasAligned = false;
  double? _heading; // degrees from north, null while unknown
  StreamSubscription<CompassEvent>? _compassSub;

  @override
  void initState() {
    super.initState();
    _compassSub = FlutterCompass.events?.listen((e) {
      if (!mounted) return;
      setState(() => _heading = e.heading);
    });
    _locate();
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _loading = true;
      _problem = null;
      _canOpenSettings = false;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _fail('خدمة الموقع (GPS) مغلقة. فعّلها ثم أعد المحاولة.', settings: true);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        _fail('نحتاج إذن الموقع لحساب اتجاه القبلة.');
        return;
      }
      if (perm == LocationPermission.deniedForever) {
        _fail('إذن الموقع مرفوض. فعّله من إعدادات التطبيق.', settings: true);
        return;
      }
      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 15),
      );
      if (!mounted) return;
      setState(() {
        _position = pos;
        _loading = false;
      });
    } catch (e) {
      _fail('تعذّر تحديد موقعك. تأكد من تفعيل الموقع وحاول مرة أخرى.');
    }
  }

  void _fail(String message, {bool settings = false}) {
    if (!mounted) return;
    setState(() {
      _problem = message;
      _canOpenSettings = settings;
      _loading = false;
    });
  }

  double _qiblaBearing(Position p) {
    final lat1 = p.latitude * math.pi / 180;
    final lat2 = _kaabaLat * math.pi / 180;
    final dLng = (_kaabaLng - p.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double _distanceKm(Position p) =>
      Geolocator.distanceBetween(
          p.latitude, p.longitude, _kaabaLat, _kaabaLng) /
      1000;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('اتجاه القبلة')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _buildBody(theme),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('جارٍ تحديد موقعك...'),
        ],
      );
    }
    final pos = _position;
    if (_problem != null || pos == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_off_rounded, size: 52, color: Colors.grey),
          const SizedBox(height: 12),
          Text(_problem ?? 'تعذّر تحديد الموقع.', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _locate,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
          if (_canOpenSettings)
            TextButton(
              onPressed: () async {
                await Geolocator.openAppSettings();
                await Geolocator.openLocationSettings();
              },
              child: const Text('فتح الإعدادات'),
            ),
        ],
      );
    }

    final bearing = _qiblaBearing(pos);
    final heading = _heading;
    final km = _distanceKm(pos);
    // Angle (degrees) the Qibla arrow must point to, relative to the phone top.
    final relative = heading == null ? bearing : (bearing - heading + 360) % 360;
    final diff = heading == null ? 180.0 : math.min(relative, 360 - relative);
    final aligned = heading != null && diff <= 3;
    if (aligned && !_wasAligned) HapticFeedback.mediumImpact();
    _wasAligned = aligned;

    final color = aligned ? AppColors.success : AppColors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          aligned ? 'أنت تواجه القبلة ✓' : 'أدِر هاتفك حتى يشير السهم لأعلى',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 280,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.5), width: 3),
                  color: color.withOpacity(0.06),
                ),
              ),
              Transform.rotate(
                angle: relative * math.pi / 180,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    Icon(Icons.navigation_rounded, size: 96, color: color),
                    const Spacer(),
                  ],
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🕋', style: TextStyle(fontSize: 28)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'زاوية القبلة من الشمال: ${bearing.toStringAsFixed(0)}°',
          style: const TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 4),
        Text(
          'المسافة إلى الكعبة: ${km.toStringAsFixed(0)} كم',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (heading == null)
          const Text(
            'لا يوجد حساس بوصلة في هذا الجهاز، فيُعرض الاتجاه كزاوية من الشمال فقط.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.orange),
          )
        else
          Text(
            'لدقة أفضل: ابتعد عن المعادن والمغناطيس، وحرّك الهاتف على شكل ٨ لمعايرة البوصلة.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
      ],
    );
  }
}
