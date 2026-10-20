import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      final doc = await _firestore.collection(AppConstants.usersCollection).doc(uid).get();
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Sign in with Email and Password
  Future<AppUser> signInWithEmailPassword(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final uid = userCredential.user!.uid;
    AppUser? profile = await getUserProfile(uid);

    // If document doesn't exist yet, create default student record
    if (profile == null) {
      profile = AppUser(
        uid: uid,
        email: email.trim(),
        displayName: userCredential.user!.displayName ?? email.split('@').first,
        role: UserRole.student,
        createdAt: DateTime.now(),
      );
      await _firestore.collection(AppConstants.usersCollection).doc(uid).set(profile.toMap());
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

    final uid = userCredential.user!.uid;
    await userCredential.user!.updateDisplayName(displayName);

    final newUser = AppUser(
      uid: uid,
      email: email.trim(),
      displayName: displayName.trim(),
      role: UserRole.student,
      academicYear: academicYear,
      createdAt: DateTime.now(),
    );

    await _firestore.collection(AppConstants.usersCollection).doc(uid).set(newUser.toMap());

    return newUser;
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Password Reset
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
}
