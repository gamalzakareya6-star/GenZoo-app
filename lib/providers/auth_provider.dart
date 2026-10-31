
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        // A guest has no Firebase account: do not drop the guest session.
        if (_user?.role == UserRole.guest) return;
        _user = null;
        notifyListeners();
        return;
      }

      final profile =
          await _authService.getUserProfile(firebaseUser.uid);

      if (profile != null) {
        _user = profile;
        notifyListeners();
        _rememberSignedIn(profile);
        return;
      }

      // The profile could not be loaded (offline / slow network). The user is
      // still signed in, so keep the session instead of showing the login
      // screen, and retry loading the profile in the background.
      _user = _fallbackUser(firebaseUser);
      notifyListeners();
      _retryProfileLoad(firebaseUser.uid);
    });
  }

  AppUser _fallbackUser(User u) {
    final c = _cachedProfile;
    if (c != null && c.uid == u.uid) return c; // keeps the admin role offline
    return AppUser(
      uid: u.uid,
      email: u.email ?? '',
      displayName: u.displayName ?? (u.email?.split('@').first ?? 'طالب'),
      role: UserRole.student,
    );
  }

  // ---- credentials kept in the Android Keystore so the student stays signed
  // in until they press "sign out", even if Firebase loses its own session ----
  static const _sec = FlutterSecureStorage();

  Future<void> _saveCreds(String email, String password) async {
    try {
      await _sec.write(key: 'cred_email', value: email.trim());
      await _sec.write(key: 'cred_pass', value: password);
      await _sec.delete(key: 'cred_google');
    } catch (_) {}
  }

  Future<void> _clearCreds() async {
    try {
      await _sec.delete(key: 'cred_email');
      await _sec.delete(key: 'cred_pass');
      await _sec.delete(key: 'cred_google');
    } catch (_) {}
  }

  /// Signs in again from the saved credentials. Returns true on success.
  Future<bool> trySilentSignIn() async {
    try {
      final e = await _sec.read(key: 'cred_email');
      final p = await _sec.read(key: 'cred_pass');
      if (e != null && p != null && e.isNotEmpty && p.isNotEmpty) {
        _user = await _authService.signInWithEmailPassword(e, p).timeout(const Duration(seconds: 12));
        notifyListeners();
        _rememberSignedIn(_user!);
        return true;
      }
      if (await _sec.read(key: 'cred_google') == '1') {
        final u = await _authService.signInGoogleSilently().timeout(const Duration(seconds: 12));
        if (u != null) {
          _user = u;
          notifyListeners();
          _rememberSignedIn(u);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  // ---- what is remembered on the device ----
  static const _kGuest = 'auth_guest_v1';
  static const _kProfile = 'auth_profile_v1';
  static const _kEmail = 'auth_last_email_v1';
  static const _kWasSignedIn = 'auth_was_signed_in_v1';

  AppUser? _cachedProfile;
  bool _sessionLost = false;

  /// True when the student was signed in before but Firebase no longer has a
  /// session (so the login screen can explain why it is shown).
  bool get sessionLost => _sessionLost;

  /// Reads what was saved on the device; call before deciding the first screen.
  Future<void> loadRemembered() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kProfile);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _cachedProfile = AppUser(
          uid: j['uid'] as String? ?? '',
          email: j['email'] as String? ?? '',
          displayName: j['name'] as String? ?? 'طالب',
          role: (j['role'] as String?) == 'admin' ? UserRole.admin : UserRole.student,
          academicYear: j['year'] as String?,
          studentId: j['sid'] as String?,
          phone: j['phone'] as String?,
          bio: j['bio'] as String?,
          department: j['dept'] as String?,
          photoUrl: j['photo'] as String?,
        );
      }
      if (_authService.currentUser == null && (p.getBool(_kWasSignedIn) ?? false)) {
        _sessionLost = true;
      }
    } catch (_) {}
  }

  Future<bool> wasGuest() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_kGuest) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String> lastEmail() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_kEmail) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _rememberSignedIn(AppUser u) async {
    _cachedProfile = u;
    _sessionLost = false;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kWasSignedIn, true);
      await p.setBool(_kGuest, false);
      if (u.email.isNotEmpty) await p.setString(_kEmail, u.email);
      await p.setString(
        _kProfile,
        jsonEncode({
          'uid': u.uid,
          'email': u.email,
          'name': u.displayName,
          'role': u.role == UserRole.admin ? 'admin' : 'student',
          'year': u.academicYear,
          'sid': u.studentId,
          'phone': u.phone,
          'bio': u.bio,
          'dept': u.department,
          'photo': u.photoUrl,
        }),
      );
    } catch (_) {}
  }

  Future<void> _retryProfileLoad(String uid) async {
    for (var i = 0; i < 6; i++) {
      await Future.delayed(const Duration(seconds: 5));
      final current = _authService.currentUser;
      if (current == null || current.uid != uid) return;
      final profile = await _authService.getUserProfile(uid);
      if (profile != null) {
        _user = profile;
        notifyListeners();
        return;
      }
    }
  }

  /// Used at startup: a saved Firebase session exists, so the user stays
  /// signed in even when the profile has not been loaded yet.
  void restoreFromFirebaseSession() {
    final u = _authService.currentUser;
    if (u != null && _user == null) {
      _user = _fallbackUser(u);
      notifyListeners();
      _retryProfileLoad(u.uid);
    }
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
      _rememberSignedIn(_user!);
      _saveCreds(email, password);
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
      _rememberSignedIn(profile);
      try {
        await _sec.delete(key: 'cred_email');
        await _sec.delete(key: 'cred_pass');
        await _sec.write(key: 'cred_google', value: '1');
      } catch (_) {}
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
    String? phone,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      _user = await _authService.registerWithEmailPassword(
        email: email,
        password: password,
        displayName: displayName,
        academicYear: academicYear,
        phone: phone,
      );

      notifyListeners();
      _rememberSignedIn(_user!);
      _saveCreds(email, password);
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
    SharedPreferences.getInstance().then((p) => p.setBool(_kGuest, true)).catchError((_) => false);
  }

  /// Saves the student's own profile data (name, phone, bio, photo...).
  /// Returns null on success or an error message.
  Future<String?> updateProfile({
    required String displayName,
    required String phone,
    required String bio,
    String? academicYear,
    String? department,
    String? photoUrl,
    bool removePhoto = false,
  }) async {
    final current = _user;
    final fb = _authService.currentUser;
    if (current == null || fb == null || current.role == UserRole.guest) {
      return 'سجّل الدخول أولاً.';
    }
    try {
      final data = <String, dynamic>{
        'displayName': displayName.trim(),
        'phone': phone.trim(),
        'bio': bio.trim(),
        if (academicYear != null) 'academicYear': academicYear,
        if (department != null) 'department': department,
        if (removePhoto) 'photoUrl': FieldValue.delete() else if (photoUrl != null) 'photoUrl': photoUrl,
      };
      await FirebaseFirestore.instance.collection('users').doc(current.uid).set(data, SetOptions(merge: true));
      try {
        await fb.updateDisplayName(displayName.trim());
      } catch (_) {}
      _user = current.copyWith(
        displayName: displayName.trim(),
        phone: phone.trim(),
        bio: bio.trim(),
        academicYear: academicYear,
        department: department,
        photoUrl: photoUrl,
        clearPhoto: removePhoto,
      );
      notifyListeners();
      _rememberSignedIn(_user!);
      return null;
    } catch (_) {
      return 'تعذّر حفظ البيانات. تأكد من الاتصال وحاول مرة أخرى.';
    }
  }

  // تسجيل الخروج
  Future<void> signOut() async {
    _setLoading(true);
    _setError(null);

    try {
      await _authService.signOut();
      await _clearCreds();
      _user = null;
      _cachedProfile = null;
      _sessionLost = false;
      try {
        final p = await SharedPreferences.getInstance();
        await p.setBool(_kGuest, false);
        await p.setBool(_kWasSignedIn, false);
        await p.remove(_kProfile);
      } catch (_) {}
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
