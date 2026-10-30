import 'package:cloud_firestore/cloud_firestore.dart';

/// A student's opinion about a study material. It becomes visible to everyone
/// only after an admin approves it.
class MaterialReview {
  final String id;
  final String materialId;
  final String materialTitle;
  final String uid;
  final String userName;
  final int rating; // 1..5
  final String text;
  final String status; // pending | approved | rejected
  final DateTime createdAt;

  const MaterialReview({
    required this.id,
    required this.materialId,
    required this.materialTitle,
    required this.uid,
    required this.userName,
    required this.rating,
    required this.text,
    required this.status,
    required this.createdAt,
  });

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';

  factory MaterialReview.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return MaterialReview(
      id: doc.id,
      materialId: d['materialId'] as String? ?? '',
      materialTitle: d['materialTitle'] as String? ?? '',
      uid: d['uid'] as String? ?? '',
      userName: d['userName'] as String? ?? 'طالب',
      rating: ((d['rating'] as num?)?.toInt() ?? 0).clamp(0, 5),
      text: d['text'] as String? ?? '',
      status: d['status'] as String? ?? 'pending',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
