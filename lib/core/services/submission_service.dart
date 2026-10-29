import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/submission_model.dart';

/// Student file submissions and the admin review of them.
class SubmissionService {
  static final _db = FirebaseFirestore.instance;
  static const String collection = 'material_submissions';

  static List<MaterialSubmission> _sorted(QuerySnapshot s) {
    final list = s.docs.map(MaterialSubmission.fromFirestore).toList();
    list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return list;
  }

  /// Pending requests (admin).
  static Stream<List<MaterialSubmission>> streamPending() => _db
      .collection(collection)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map(_sorted);

  /// The signed-in student's own requests.
  static Stream<List<MaterialSubmission>> streamMine(String uid) => _db
      .collection(collection)
      .where('submittedBy', isEqualTo: uid)
      .snapshots()
      .map(_sorted);

  static Future<void> submit({
    required String uid,
    required String submitterName,
    required String title,
    required String description,
    required String department,
    required String subject,
    required String materialType,
    required String fileName,
    required String fileUrl,
    required int fileSize,
  }) {
    return _db.collection(collection).add({
      'title': title,
      'description': description,
      'department': department,
      'subject': subject,
      'materialType': materialType,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileSize': fileSize,
      'submittedBy': uid,
      'submitterName': submitterName,
      'submittedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  /// Approves a request: publishes it in the materials and marks it approved
  /// in one atomic batch.
  static Future<void> approve(MaterialSubmission s, String reviewerName) {
    final batch = _db.batch();
    final material = _db.collection('materials').doc();
    batch.set(material, {
      'title': s.title,
      'description': s.description,
      'department': s.department,
      'subject': s.subject,
      'materialType': s.materialType,
      'fileUrl': s.fileUrl,
      'fileName': s.fileName,
      'fileExtension': s.extension,
      'fileSizeBytes': s.fileSize,
      'uploadedBy': s.submitterName,
      'uploadedAt': FieldValue.serverTimestamp(),
      'downloadCount': 0,
    });
    batch.update(_db.collection(collection).doc(s.id), {
      'status': 'approved',
      'reviewedBy': reviewerName,
      'reviewedAt': FieldValue.serverTimestamp(),
      'materialId': material.id,
    });
    return batch.commit();
  }

  static Future<void> reject(MaterialSubmission s, String reviewerName, String note) {
    return _db.collection(collection).doc(s.id).update({
      'status': 'rejected',
      'reviewNote': note,
      'reviewedBy': reviewerName,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> delete(String id) => _db.collection(collection).doc(id).delete();
}
