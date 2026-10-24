import 'package:cloud_firestore/cloud_firestore.dart';

class StudyMaterial {
  final String id;
  final String title;
  final String description;
  final String department;
  final String subject;
  final String materialType;
  final String fileUrl;
  final String fileName;
  final String fileExtension;
  final int fileSizeBytes;
  final String uploadedBy;
  final DateTime uploadedAt;
  final int downloadCount;

  StudyMaterial({
    required this.id,
    required this.title,
    required this.description,
    required this.department,
    required this.subject,
    required this.materialType,
    required this.fileUrl,
    required this.fileName,
    required this.fileExtension,
    required this.fileSizeBytes,
    required this.uploadedBy,
    required this.uploadedAt,
    this.downloadCount = 0,
  });

  String get formattedFileSize {
    if (fileSizeBytes <= 0) return 'رابط';
    if (fileSizeBytes < 1024) return '$fileSizeBytes بايت';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} ك.ب';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} م.ب';
  }

  factory StudyMaterial.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return StudyMaterial(
      id: doc.id,
      title: data['title'] as String? ?? 'مادة بدون عنوان',
      description: data['description'] as String? ?? '',
      department: data['department'] as String? ?? 'مقررات عامة (كل الأقسام)',
      subject: data['subject'] as String? ?? 'عام',
      materialType: data['materialType'] as String? ?? 'مستند',
      fileUrl: data['fileUrl'] as String? ?? '',
      fileName: data['fileName'] as String? ?? 'file',
      fileExtension: data['fileExtension'] as String? ?? 'pdf',
      fileSizeBytes: (data['fileSizeBytes'] as num?)?.toInt() ?? 0,
      uploadedBy: data['uploadedBy'] as String? ?? 'الإدارة',
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      downloadCount: (data['downloadCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'department': department,
      'subject': subject,
      'materialType': materialType,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileExtension': fileExtension,
      'fileSizeBytes': fileSizeBytes,
      'uploadedBy': uploadedBy,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'downloadCount': downloadCount,
    };
  }
}
