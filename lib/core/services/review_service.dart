import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/review_model.dart';

/// Reviews of study materials: material_reviews/{materialId}_{uid}.
/// One review per student per material; editing it sends it for approval again.
class ReviewService {
  static final _db = FirebaseFirestore.instance;
  static const String collection = 'material_reviews';
  static const int maxLength = 2000;
  static const int maxDetail = 1000;

  static String docId(String materialId, String uid) => '${materialId}_$uid';

  static List<MaterialReview> _sorted(QuerySnapshot s) {
    final list = s.docs.map(MaterialReview.fromFirestore).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Approved reviews of every material (used for the stars on the cards).
  static Stream<List<MaterialReview>> streamAllApproved() =>
      _db.collection(collection).where('status', isEqualTo: 'approved').limit(1000).snapshots().map(_sorted);

  static Stream<List<MaterialReview>> streamApprovedFor(String materialId) => _db
      .collection(collection)
      .where('materialId', isEqualTo: materialId)
      .where('status', isEqualTo: 'approved')
      .snapshots()
      .map(_sorted);

  /// The signed-in student's own review of a material (any status).
  static Stream<MaterialReview?> streamMine(String materialId, String uid) => _db
      .collection(collection)
      .doc(docId(materialId, uid))
      .snapshots()
      .map((d) => d.exists ? MaterialReview.fromFirestore(d) : null);

  static Stream<List<MaterialReview>> streamPending() =>
      _db.collection(collection).where('status', isEqualTo: 'pending').snapshots().map(_sorted);

  static Future<void> submit({
    required String materialId,
    required String materialTitle,
    required String uid,
    required String userName,
    required int rating,
    required String text,
    String exam = '',
    String tips = '',
    int difficulty = 0,
  }) {
    return _db.collection(collection).doc(docId(materialId, uid)).set({
      'materialId': materialId,
      'materialTitle': materialTitle,
      'uid': uid,
      'userName': userName,
      'rating': rating,
      'text': text.trim(),
      'exam': exam.trim(),
      'tips': tips.trim(),
      'difficulty': difficulty,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> setStatus(String id, String status) =>
      _db.collection(collection).doc(id).update({'status': status, 'reviewedAt': FieldValue.serverTimestamp()});

  static Future<void> delete(String id) => _db.collection(collection).doc(id).delete();
}
