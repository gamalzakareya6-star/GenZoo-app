import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the student's Ibn Al-Haytham (منصة ابن الهيثم) credentials
/// ON-DEVICE ONLY, encrypted via the Android Keystore / iOS Keychain
/// through flutter_secure_storage. These credentials are never sent to
/// GenZoo's own backend (Firebase) — they are used only to auto-fill the
/// login form inside the in-app WebView below.
///
/// Keys are intentionally distinct from GenZoo's own login keys
/// (cred_email / cred_pass / cred_google in auth_provider.dart) so the two
/// credential sets never collide or get cleared together.
class IbnHaythamService {
  IbnHaythamService._();

  static const _storage = FlutterSecureStorage();

  static const _kNationalId = 'ibn_haytham_national_id';
  static const _kPassword = 'ibn_haytham_password';

  /// Saves the National ID + password for auto-login next time.
  static Future<void> saveCredentials({
    required String nationalId,
    required String password,
  }) async {
    await _storage.write(key: _kNationalId, value: nationalId.trim());
    await _storage.write(key: _kPassword, value: password);
  }

  /// Returns the saved (nationalId, password) pair, or null if nothing is
  /// saved yet.
  static Future<({String nationalId, String password})?> readCredentials() async {
    final id = await _storage.read(key: _kNationalId);
    final pass = await _storage.read(key: _kPassword);
    if (id == null || pass == null || id.isEmpty || pass.isEmpty) return null;
    return (nationalId: id, password: pass);
  }

  static Future<bool> hasSavedCredentials() async {
    final creds = await readCredentials();
    return creds != null;
  }

  /// Removes the saved credentials (e.g. if the student asks to forget them
  /// or login repeatedly fails).
  static Future<void> clearCredentials() async {
    await _storage.delete(key: _kNationalId);
    await _storage.delete(key: _kPassword);
  }
}
