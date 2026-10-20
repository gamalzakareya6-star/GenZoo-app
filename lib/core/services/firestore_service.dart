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
    await _firestore.collection(AppConstants.newsCollection).add(item.toMap());
  }

  Future<void> updateNews(NewsItem item) async {
    await _firestore
        .collection(AppConstants.newsCollection)
        .doc(item.id)
        .update(item.toMap());
  }

  Future<void> deleteNews(String id) async {
    await _firestore.collection(AppConstants.newsCollection).doc(id).delete();
  }

  // ---------------------------------------------------------------------------
  // STUDY MATERIALS
  // ---------------------------------------------------------------------------
  Stream<List<StudyMaterial>> streamMaterials({
    String? academicYear,
    String? semester,
    String? subject,
  }) {
    // Filtering by year/semester happens client-side in MaterialsProvider,
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
