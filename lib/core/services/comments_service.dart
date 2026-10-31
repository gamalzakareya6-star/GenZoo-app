import 'package:cloud_firestore/cloud_firestore.dart';

class NewsComment {
  final String id;
  final String uid;
  final String name;
  final String text;
  final String photo;
  final DateTime createdAt;

  const NewsComment({
    required this.id,
    required this.uid,
    required this.name,
    required this.text,
    this.photo = '',
    required this.createdAt,
  });

  factory NewsComment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return NewsComment(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      name: d['name'] as String? ?? 'طالب',
      text: d['text'] as String? ?? '',
      photo: d['photo'] as String? ?? '',
      // A just-written comment has no server time yet.
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Comments under a news post: news/{newsId}/comments/{id}.
class CommentsService {
  static const int maxLength = 500;

  static CollectionReference<Map<String, dynamic>> _col(String newsId) =>
      FirebaseFirestore.instance.collection('news').doc(newsId).collection('comments');

  static Stream<List<NewsComment>> stream(String newsId) => _col(newsId)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(NewsComment.fromFirestore).toList());

  static Future<void> add({
    required String newsId,
    required String uid,
    required String name,
    required String text,
    String photo = '',
  }) {
    return _col(newsId).add({
      'uid': uid,
      'name': name,
      if (photo.isNotEmpty) 'photo': photo,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> delete(String newsId, String commentId) => _col(newsId).doc(commentId).delete();
}
