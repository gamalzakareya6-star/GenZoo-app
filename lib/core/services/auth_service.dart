import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../models/user_model.dart';
import '../constants/app_constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // Fetch full user profile with role from Firestore
  Future<AppUser?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();

      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Sign in with Email and Password
  Future<AppUser> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final firebaseUser = userCredential.user!;
    final uid = firebaseUser.uid;

    AppUser? profile = await getUserProfile(uid);

    if (profile == null) {
      profile = AppUser(
        uid: uid,
        email: firebaseUser.email ?? email.trim(),
        displayName:
            firebaseUser.displayName ?? email.trim().split('@').first,
        role: UserRole.student,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .set(profile.toMap());
    }

    return profile;
  }

  // Register with Email and Password
  Future<AppUser> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
    required String academicYear,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final firebaseUser = userCredential.user!;
    final uid = firebaseUser.uid;

    await firebaseUser.updateDisplayName(displayName.trim());

    final newUser = AppUser(
      uid: uid,
      email: email.trim(),
      displayName: displayName.trim(),
      role: UserRole.student,
      academicYear: academicYear,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .set(newUser.toMap());

    return newUser;
  }

  // Sign in with Google
  Future<AppUser?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser =
        await GoogleSignIn().signIn();

    // The user cancelled the Google account picker
    if (googleUser == null) {
      return null;
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential =
        await _auth.signInWithCredential(credential);

    final firebaseUser = userCredential.user;

    if (firebaseUser == null) {
      throw FirebaseAuthException(
        code: 'google-sign-in-failed',
        message: 'Google sign-in did not return a Firebase user.',
      );
    }

    AppUser? profile = await getUserProfile(firebaseUser.uid);

    // Create a default student profile on first Google sign-in
    if (profile == null) {
      profile = AppUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? googleUser.email,
        displayName:
            firebaseUser.displayName ?? googleUser.displayName,
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

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }

  // Password Reset
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
}
