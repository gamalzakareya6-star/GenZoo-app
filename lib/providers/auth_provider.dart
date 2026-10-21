import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../core/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AppUser? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _authService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser == null) {
        _user = null;
        notifyListeners();
        return;
      }

      _user = await _authService.getUserProfile(
        firebaseUser.uid,
      );

      notifyListeners();
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  Future<bool> signIn(
    String email,
    String password,
  ) async {
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
    } catch (e) {
      _setError('حدث خطأ أثناء تسجيل الدخول');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _setError(null);

    try {
      final result = await _authService.signInWithGoogle();

      if (result == null) {
        return false;
      }

      _user = result;
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'فشل تسجيل الدخول باستخدام Google');
      return false;
    } catch (e) {
      _setError('تعذر تسجيل الدخول باستخدام Google');
      return false;
    } finally {
      _setLoading(false);
    }
  }

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
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'فشل إنشاء الحساب');
      return false;
    } catch (e) {
      _setError('حدث خطأ أثناء إنشاء الحساب');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _setError(null);

    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'تعذر إرسال رابط استعادة كلمة المرور');
      return false;
    } catch (e) {
      _setError('حدث خطأ أثناء استعادة كلمة المرور');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void loginAsGuest() {
    _user = null;
    _setError(null);
    notifyListeners();
  }

  Future<void> signOut() async {
    _setLoading(true);

    try {
      await _authService.signOut();
      _user = null;
      _setError(null);
    } catch (e) {
      _setError('تعذر تسجيل الخروج');
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
