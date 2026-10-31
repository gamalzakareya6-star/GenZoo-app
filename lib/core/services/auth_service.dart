import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../models/user_model.dart';
import '../constants/app_constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Stream<User?> get authStateChanges =>
      _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<AppUser?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();

      if (!doc.exists) return null;

      return AppUser.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  Future<AppUser> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    final result =
        await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final firebaseUser = result.user!;

    AppUser? profile =
        await getUserProfile(firebaseUser.uid);

    if (profile == null) {
      profile = AppUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? email.trim(),
        displayName: firebaseUser.displayName ??
            email.trim().split('@').first,
        role: UserRole.student,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(firebaseUser.uid)
          .set(profile.toMap());
    }

    return profile;
  }

  Future<AppUser> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
    required String academicYear,
    String? phone,
  }) async {
    final result =
        await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final firebaseUser = result.user!;

    await firebaseUser.updateDisplayName(
      displayName.trim(),
    );

    final newUser = AppUser(
      uid: firebaseUser.uid,
      email: email.trim(),
      displayName: displayName.trim(),
      role: UserRole.student,
      academicYear: academicYear,
      phone: phone,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(firebaseUser.uid)
        .set(newUser.toMap());

    return newUser;
  }

  /// Re-signs a Google user without showing any UI (null if not possible).
  Future<AppUser?> signInGoogleSilently() async {
    final googleUser = await GoogleSignIn().signInSilently();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final result = await _auth.signInWithCredential(GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    ));
    final u = result.user;
    if (u == null) return null;
    return getUserProfile(u.uid);
  }

  Future<AppUser?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser =
        await GoogleSignIn().signIn();

    if (googleUser == null) {
      return null;
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result =
        await _auth.signInWithCredential(credential);

    final firebaseUser = result.user;

    if (firebaseUser == null) {
      throw FirebaseAuthException(
        code: 'google-sign-in-failed',
        message: 'Google sign-in failed.',
      );
    }

    AppUser? profile =
        await getUserProfile(firebaseUser.uid);

    if (profile == null) {
      profile = AppUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? googleUser.email,
        displayName: firebaseUser.displayName ??
            googleUser.displayName ??
            googleUser.email.split('@').first,
        role: UserRole.student,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(firebaseUser.uid)
          .set(profile.toMap());
    }

    return profile;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }

  Future<void> sendPasswordResetEmail(
    String email,
  ) async {
    await _auth.sendPasswordResetEmail(
      email: email.trim(),
    );
  }
}
