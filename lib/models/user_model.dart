import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, student, guest }

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? academicYear;
  final String? studentId;
  final DateTime? createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.role = UserRole.student,
    this.academicYear,
    this.studentId,
    this.createdAt,
  });

  bool get isAdmin => role == UserRole.admin;

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final roleStr = data['role'] as String? ?? 'student';

    return AppUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'طالب',
      role: roleStr.toLowerCase() == 'admin' ? UserRole.admin : UserRole.student,
      academicYear: data['academicYear'] as String?,
      studentId: data['studentId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role == UserRole.admin ? 'admin' : 'student',
      'academicYear': academicYear,
      'studentId': studentId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  static AppUser guestUser() {
    return AppUser(
      uid: 'guest',
      email: '',
      displayName: 'طالب زائر',
      role: UserRole.guest,
    );
  }
}
