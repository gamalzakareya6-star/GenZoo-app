import 'package:cloud_firestore/cloud_firestore.dart';

/// A student's opinion + advice about a subject (written by name, not tied to
/// a file). Visible to everyone only after an admin approves it.
class SubjectOpinion {
  final String id;
  final String subjectName;
  final String opinion;
  final String advice;
  final String uid;
  final String userName;
  final String status; // pending | approved | rejected
  final DateTime createdAt;

  const SubjectOpinion({
    required this.id,
    required this.subjectName,
    required this.opinion,
    required this.advice,
    required this.uid,
    required this.userName,
    required this.status,
    required this.createdAt,
  });

  factory SubjectOpinion.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return SubjectOpinion(
      id: doc.id,
      subjectName: d['subjectName'] as String? ?? '',
      opinion: d['opinion'] as String? ?? '',
      advice: d['advice'] as String? ?? '',
      uid: d['uid'] as String? ?? '',
      userName: d['userName'] as String? ?? 'طالب',
      status: d['status'] as String? ?? 'pending',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class OpinionService {
  static final _col = FirebaseFirestore.instance.collection('subject_opinions');
  static const int maxOpinion = 1500;
  static const int maxAdvice = 1000;

  static List<SubjectOpinion> _sorted(QuerySnapshot s) {
    final list = s.docs.map(SubjectOpinion.fromFirestore).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Stream<List<SubjectOpinion>> streamApproved() =>
      _col.where('status', isEqualTo: 'approved').limit(500).snapshots().map(_sorted);

  static Stream<List<SubjectOpinion>> streamMine(String uid) =>
      _col.where('uid', isEqualTo: uid).snapshots().map(_sorted);

  static Stream<List<SubjectOpinion>> streamPending() =>
      _col.where('status', isEqualTo: 'pending').snapshots().map(_sorted);

  static Future<void> submit({
    required String uid,
    required String userName,
    required String subjectName,
    required String opinion,
    required String advice,
  }) {
    return _col.add({
      'uid': uid,
      'userName': userName,
      'subjectName': subjectName.trim(),
      'opinion': opinion.trim(),
      'advice': advice.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> setStatus(String id, String status) =>
      _col.doc(id).update({'status': status, 'reviewedAt': FieldValue.serverTimestamp()});

  static Future<void> delete(String id) => _col.doc(id).delete();
}
