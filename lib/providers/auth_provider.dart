import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../core/services/auth_service.dart';

class UserAuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AppUser? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null && _user!.role != UserRole.guest;
  bool get isAdmin => _user?.isAdmin ?? false;

  UserAuthProvider() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        _user = await _authService.getUserProfile(firebaseUser.uid);
      } else {
        if (_user?.role != UserRole.guest) {
          _user = null;
        }
      }
      notifyListeners();
    });
  }

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      _user = await _authService.signInWithEmailPassword(email, password);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'حدث خطأ غير متوقع. حاول مرة أخرى.';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    required String academicYear,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      _user = await _authService.registerWithEmailPassword(
        email: email,
        password: password,
        displayName: displayName,
        academicYear: academicYear,
      );
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'فشل إنشاء الحساب. راجع بياناتك وحاول مرة أخرى.';
      _setLoading(false);
      return false;
    }
  }

  /// Sends a reset link to [email]. Returns null on success, otherwise an Arabic error message.
  Future<String?> resetPassword(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e.code);
    } catch (_) {
      return 'تعذّر إرسال الرابط. حاول مرة أخرى.';
    }
  }

  void loginAsGuest() {
    _user = AppUser.guestUser();
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    _setLoading(true);
    await _authService.signOut();
    _user = null;
    _setLoading(false);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'لا يوجد حساب بهذا البريد الإلكتروني.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'كلمة المرور أو البيانات غير صحيحة.';
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مسجّل بالفعل.';
      case 'weak-password':
        return 'كلمة المرور يجب ألا تقل عن 6 أحرف.';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      default:
        return 'فشلت العملية: $code';
    }
  }
}
