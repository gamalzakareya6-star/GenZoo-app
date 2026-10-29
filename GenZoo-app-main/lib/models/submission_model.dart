import 'package:cloud_firestore/cloud_firestore.dart';

/// A study file a student sent for the admin to approve.
class MaterialSubmission {
  final String id;
  final String title;
  final String description;
  final String department;
  final String subject;
  final String materialType;
  final String fileName;
  final String fileUrl;
  final int fileSize;
  final String submittedBy; // uid
  final String submitterName;
  final DateTime submittedAt;
  final String status; // pending | approved | rejected
  final String reviewNote;

  const MaterialSubmission({
    required this.id,
    required this.title,
    required this.description,
    required this.department,
    required this.subject,
    required this.materialType,
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
    required this.submittedBy,
    required this.submitterName,
    required this.submittedAt,
    required this.status,
    this.reviewNote = '',
  });

  bool get isPending => status == 'pending';

  String get extension {
    final i = fileName.lastIndexOf('.');
    return i < 0 ? 'other' : fileName.substring(i + 1).toLowerCase();
  }

  factory MaterialSubmission.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return MaterialSubmission(
      id: doc.id,
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      department: d['department'] as String? ?? '',
      subject: d['subject'] as String? ?? '',
      materialType: d['materialType'] as String? ?? '',
      fileName: d['fileName'] as String? ?? 'file',
      fileUrl: d['fileUrl'] as String? ?? '',
      fileSize: (d['fileSize'] as num?)?.toInt() ?? 0,
      submittedBy: d['submittedBy'] as String? ?? '',
      submitterName: d['submitterName'] as String? ?? 'طالب',
      submittedAt: (d['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: d['status'] as String? ?? 'pending',
      reviewNote: d['reviewNote'] as String? ?? '',
    );
  }
}
