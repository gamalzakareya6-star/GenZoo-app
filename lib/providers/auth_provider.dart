
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../core/services/auth_service.dart';

class UserAuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AppUser? _user;
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<User?>? _authSubscription;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  // تحديد ما إذا كان المستخدم أدمن
  bool get isAdmin => _user?.role == UserRole.admin;

  UserAuthProvider() {
    _authSubscription =
        _authService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser == null) {
        _user = null;
        notifyListeners();
        return;
      }

      final profile =
          await _authService.getUserProfile(firebaseUser.uid);

      _user = profile;
      notifyListeners();
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // تسجيل الدخول بالبريد الإلكتروني وكلمة المرور
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _setError(null);

    try {
      _user = await _authService.signInWithEmailPassword(
        email,
        password,
      );
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'فشل تسجيل الدخول');
      return false;
    } catch (_) {
      _setError('حدث خطأ أثناء تسجيل الدخول');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // تسجيل الدخول بحساب Google
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _setError(null);

    try {
      final profile = await _authService.signInWithGoogle();

      if (profile == null) {
        return false;
      }

      _user = profile;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(
        e.message ?? 'فشل تسجيل الدخول باستخدام Google',
      );
      return false;
    } catch (_) {
      _setError(
        'تعذر تسجيل الدخول باستخدام Google. حاول مرة أخرى.',
      );
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // إنشاء حساب طالب جديد
  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    required String academicYear,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      _user = await _authService.registerWithEmailPassword(
        email: email,
        password: password,
        displayName: displayName,
        academicYear: academicYear,
      );

      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'فشل إنشاء الحساب');
      return false;
    } catch (_) {
      _setError('حدث خطأ أثناء إنشاء الحساب');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // استعادة كلمة المرور
  // ترجع null عند النجاح ورسالة خطأ عند الفشل
  Future<String?> resetPassword(String email) async {
    _setLoading(true);
    _setError(null);

    try {
      await _authService.sendPasswordResetEmail(email);
      return null;
    } on FirebaseAuthException catch (e) {
      final message =
          e.message ?? 'تعذر إرسال رابط استعادة كلمة المرور';
      _setError(message);
      return message;
    } catch (_) {
      const message = 'حدث خطأ أثناء استعادة كلمة المرور';
      _setError(message);
      return message;
    } finally {
      _setLoading(false);
    }
  }

  // الدخول كضيف
  void loginAsGuest() {
    _user = AppUser.guestUser();
    _setError(null);
    notifyListeners();
  }

  // تسجيل الخروج
  Future<void> signOut() async {
    _setLoading(true);
    _setError(null);

    try {
      await _authService.signOut();
      _user = null;
      notifyListeners();
    } catch (_) {
      _setError('تعذر تسجيل الخروج');
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
