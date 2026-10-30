import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/services/drive_upload_service.dart';

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
  final List<UploadedFile> attachments;
  final List<UploadedFile> images;

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
    this.attachments = const [],
    this.images = const [],
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
      attachments: (data['attachments'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((m) => UploadedFile.fromMap(Map<String, dynamic>.from(m)))
          .where((f) => f.url.isNotEmpty)
          .toList(),
      images: (data['images'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((m) => UploadedFile.fromMap(Map<String, dynamic>.from(m)))
          .where((f) => f.url.isNotEmpty)
          .toList(),
    );
  }

  /// Every picture of the post (uploaded images, plus the legacy single one).
  List<String> get imageUrls => [
        if (imageUrl != null && imageUrl!.isNotEmpty) imageUrl!,
        ...images.map((i) => i.url),
      ];

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
      'attachments': attachments.map((f) => f.toMap()).toList(),
      'images': images.map((f) => f.toMap()).toList(),
    };
  }
}
