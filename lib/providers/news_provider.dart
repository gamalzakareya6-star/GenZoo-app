import 'package:flutter/foundation.dart';
import '../models/news_model.dart';
import '../core/services/drive_upload_service.dart';
import '../core/services/firestore_service.dart';

class NewsProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<NewsItem> _newsList = [];
  String _selectedCategory = 'الكل';
  bool _isLoading = true;

  List<NewsItem> get allNews => _newsList;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;

  List<NewsItem> get filteredNews {
    if (_selectedCategory == 'الكل') return _newsList;
    return _newsList.where((n) => n.category == _selectedCategory).toList();
  }

  NewsProvider() {
    _subscribeToNews();
  }

  void _subscribeToNews() {
    _firestoreService.streamNews().listen((items) {
      _newsList = items;
      _isLoading = false;
      notifyListeners();
    }, onError: (err) {
      debugPrint('News stream error: $err');
      _isLoading = false;
      notifyListeners();
    });
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  Future<void> addNews({
    required String title,
    required String content,
    required String category,
    required bool isPinned,
    required String authorName,
    String? imageUrl,
    String? externalUrl,
    List<UploadedFile> attachments = const [],
    List<UploadedFile> images = const [],
  }) async {
    final item = NewsItem(
      id: '',
      title: title,
      content: content,
      category: category,
      isPinned: isPinned,
      authorName: authorName,
      imageUrl: imageUrl,
      externalUrl: externalUrl,
      attachments: attachments,
      images: images,
      publishedAt: DateTime.now(),
    );
    await _firestoreService.addNews(item);
  }

  Future<void> updateNews({
    required String id,
    required String title,
    required String content,
    required String category,
    required bool isPinned,
    String? externalUrl,
    List<UploadedFile> attachments = const [],
    List<UploadedFile> images = const [],
  }) async {
    await _firestoreService.editNews(
      id: id,
      title: title,
      content: content,
      category: category,
      isPinned: isPinned,
      externalUrl: externalUrl,
      attachments: attachments.map((f) => f.toMap()).toList(),
      images: images.map((f) => f.toMap()).toList(),
    );
  }

  Future<void> deleteNews(String id) async {
    await _firestoreService.deleteNews(id);
  }
}
