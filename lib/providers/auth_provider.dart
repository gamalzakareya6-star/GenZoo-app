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

  // Email and password login
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _setError(null);

    try {
      _user = await _authService.signInWithEmailPassword(
        email,
        password,
      );
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

  // Google login
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _setError(null);

    try {
      final profile = await _authService.signInWithGoogle();

      if (profile == null) {
        // The user cancelled Google sign-in.
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

  // Register a new student
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

  // Password reset
  // Returns null on success, or an error message on failure.
  Future<String?> resetPassword(String email) async {
    _setLoading(true);
    _setError(null);

    try {
      await _authService.sendPasswordResetEmail(email);
      return null;
    } on FirebaseAuthException catch (e) {
      final message = e.message ??
          'تعذر إرسال رابط استعادة كلمة المرور';
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

  // Guest access
  void loginAsGuest() {
    _user = null;
    _setError(null);
    notifyListeners();
  }

  // Sign out
  Future<void> signOut() async {
    _setLoading(true);
    _setError(null);

    try {
      await _authService.signOut();
      _user = null;
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
