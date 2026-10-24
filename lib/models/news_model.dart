import 'package:cloud_firestore/cloud_firestore.dart';

class NewsItem {
  final String id;
  final String title;
  final String content;
  final String category;
  final bool isPinned;
  final String authorName;
  final String? imageUrl;
  final String? externalUrl;
  final DateTime publishedAt;
  final String source; // 'app' or 'telegram'
  final bool edited;

  NewsItem({
    required this.id,
    required this.title,
    required this.content,
    this.category = 'عام',
    this.isPinned = false,
    required this.authorName,
    this.imageUrl,
    this.externalUrl,
    required this.publishedAt,
    this.source = 'app',
    this.edited = false,
  });

  factory NewsItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NewsItem(
      id: doc.id,
      title: data['title'] as String? ?? 'إعلان بدون عنوان',
      content: data['content'] as String? ?? '',
      category: data['category'] as String? ?? 'عام',
      isPinned: data['isPinned'] as bool? ?? false,
      authorName: data['authorName'] as String? ?? 'الإدارة',
      imageUrl: data['imageUrl'] as String?,
      externalUrl: data['externalUrl'] as String?,
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      source: data['source'] as String? ?? 'app',
      edited: (data['edited'] as bool? ?? false) || (data['manuallyEdited'] as bool? ?? false),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'category': category,
      'isPinned': isPinned,
      'authorName': authorName,
      'imageUrl': imageUrl,
      'externalUrl': externalUrl,
      'publishedAt': Timestamp.fromDate(publishedAt),
    };
  }
}
