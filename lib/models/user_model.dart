import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { superAdmin, admin, student, guest }

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? academicYear;
  final String? program;
  final String? studentId;
  final String? phone;
  final String? bio;
  final String? department;
  final String? photoUrl;
  final DateTime? createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.role = UserRole.student,
    this.academicYear,
    this.program,
    this.studentId,
    this.phone,
    this.bio,
    this.department,
    this.photoUrl,
    this.createdAt,
  });

  AppUser copyWith({
    String? displayName,
    String? academicYear,
    String? program,
    String? phone,
    String? bio,
    String? department,
    String? photoUrl,
    bool clearPhoto = false,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        role: role,
        academicYear: academicYear ?? this.academicYear,
        program: program ?? this.program,
        studentId: studentId,
        phone: phone ?? this.phone,
        bio: bio ?? this.bio,
        department: department ?? this.department,
        photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
        createdAt: createdAt,
      );

  bool get isAdmin => role == UserRole.admin || role == UserRole.superAdmin;
  bool get isSuperAdmin => role == UserRole.superAdmin;

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final roleStr = (data['role'] as String? ?? 'student').toLowerCase();

    return AppUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'طالب',
      role: roleStr == 'superadmin'
          ? UserRole.superAdmin
          : roleStr == 'admin'
              ? UserRole.admin
              : UserRole.student,
      academicYear: data['academicYear'] as String?,
      program: data['program'] as String?,
      studentId: data['studentId'] as String?,
      phone: data['phone'] as String?,
      bio: data['bio'] as String?,
      department: data['department'] as String?,
      photoUrl: data['photoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role == UserRole.superAdmin ? 'superAdmin' : (role == UserRole.admin ? 'admin' : 'student'),
      'academicYear': academicYear,
      if (program != null) 'program': program,
      'studentId': studentId,
      if (phone != null) 'phone': phone,
      if (bio != null) 'bio': bio,
      if (department != null) 'department': department,
      if (photoUrl != null) 'photoUrl': photoUrl,
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
