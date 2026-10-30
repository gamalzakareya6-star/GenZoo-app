import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/news_model.dart';
import '../../models/material_model.dart';
import '../../models/quick_link_model.dart';
import '../constants/app_constants.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // NEWS / ANNOUNCEMENTS
  // ---------------------------------------------------------------------------
  Stream<List<NewsItem>> streamNews() {
    return _firestore
        .collection(AppConstants.newsCollection)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map((doc) => NewsItem.fromFirestore(doc)).toList();
      // Sorted client-side (pinned first, then newest) to avoid needing a composite index
      items.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.publishedAt.compareTo(a.publishedAt);
      });
      return items;
    });
  }

  Future<void> addNews(NewsItem item) async {
    final data = item.toMap();
    // Server time (not the admin phone's clock) so ordering is reliable, and
    // `notified: false` marks this post as waiting for a push notification.
    data['publishedAt'] = FieldValue.serverTimestamp();
    data['notified'] = false;
    await _firestore.collection(AppConstants.newsCollection).add(data);
  }

  Future<void> updateNews(NewsItem item) async {
    await _firestore
        .collection(AppConstants.newsCollection)
        .doc(item.id)
        .update(item.toMap());
  }

  /// Admin edit: changes only the editable fields, keeps everything else
  /// (including the Telegram link) and never re-sends a notification.
  Future<void> editNews({
    required String id,
    required String title,
    required String content,
    required String category,
    required bool isPinned,
    String? externalUrl,
    required List<Map<String, dynamic>> attachments,
    List<Map<String, dynamic>> images = const [],
  }) async {
    await _firestore.collection(AppConstants.newsCollection).doc(id).update({
      'title': title,
      'content': content,
      'category': category,
      'isPinned': isPinned,
      'externalUrl': externalUrl,
      'attachments': attachments,
      'images': images,
      'manuallyEdited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNews(String id) async {
    await _firestore.collection(AppConstants.newsCollection).doc(id).delete();
  }

  // ---------------------------------------------------------------------------
  // STUDY MATERIALS
  // ---------------------------------------------------------------------------
  Stream<List<StudyMaterial>> streamMaterials() {
    // Filtering by department happens client-side in MaterialsProvider,
    // so a single-field order is enough (no composite index required).
    return _firestore
        .collection(AppConstants.materialsCollection)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => StudyMaterial.fromFirestore(doc)).toList());
  }

  Future<void> addMaterial(StudyMaterial material) async {
    await _firestore.collection(AppConstants.materialsCollection).add(material.toMap());
  }

  Future<void> deleteMaterial(String id) async {
    await _firestore.collection(AppConstants.materialsCollection).doc(id).delete();
  }

  Future<void> incrementDownloadCount(String id) async {
    await _firestore
        .collection(AppConstants.materialsCollection)
        .doc(id)
        .update({'downloadCount': FieldValue.increment(1)});
  }

  // ---------------------------------------------------------------------------
  // QUICK LINKS & PLATFORMS
  // ---------------------------------------------------------------------------
  Stream<List<QuickLink>> streamQuickLinks() {
    return _firestore
        .collection(AppConstants.quickLinksCollection)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        // Fallback default list if database is freshly initialized
        return QuickLink.getDefaultLinks();
      }
      final links = snapshot.docs.map((doc) => QuickLink.fromFirestore(doc)).toList();
      links.sort((a, b) => a.order.compareTo(b.order));
      return links;
    });
  }

  Future<void> addQuickLink(QuickLink link) async {
    await _firestore.collection(AppConstants.quickLinksCollection).add(link.toMap());
  }

  Future<void> deleteQuickLink(String id) async {
    await _firestore.collection(AppConstants.quickLinksCollection).doc(id).delete();
  }
}
