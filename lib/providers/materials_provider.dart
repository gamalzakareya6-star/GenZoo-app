import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/material_model.dart';
import '../core/services/firestore_service.dart';

class MaterialsProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<StudyMaterial> _materials = [];
  bool _isLoading = true;
  String _selectedYear = 'الكل';
  String _selectedSemester = 'الكل';
  String _searchQuery = '';
  double _uploadProgress = 0.0;
  bool _isUploading = false;
  String? _uploadError;

  StreamSubscription? _subscription;

  List<StudyMaterial> get materials => _materials;
  bool get isLoading => _isLoading;
  String get selectedYear => _selectedYear;
  String get selectedSemester => _selectedSemester;
  double get uploadProgress => _uploadProgress;
  bool get isUploading => _isUploading;
  String? get uploadError => _uploadError;

  List<StudyMaterial> get filteredMaterials {
    return _materials.where((m) {
      final matchesYear = _selectedYear == 'الكل' || m.academicYear == _selectedYear;
      final matchesSem = _selectedSemester == 'الكل' || m.semester == _selectedSemester;
      final matchesQuery = _searchQuery.isEmpty ||
          m.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.subject.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesYear && matchesSem && matchesQuery;
    }).toList();
  }

  MaterialsProvider() {
    _fetchMaterials();
  }

  void _fetchMaterials() {
    _isLoading = true;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _firestoreService
        .streamMaterials(
          academicYear: _selectedYear == 'الكل' ? null : _selectedYear,
          semester: _selectedSemester == 'الكل' ? null : _selectedSemester,
        )
        .listen((list) {
      _materials = list;
      _isLoading = false;
      notifyListeners();
    }, onError: (err) {
      debugPrint('Error streaming materials: $err');
      _isLoading = false;
      notifyListeners();
    });
  }

  void setYearFilter(String year) {
    _selectedYear = year;
    _fetchMaterials();
  }

  void setSemesterFilter(String semester) {
    _selectedSemester = semester;
    _fetchMaterials();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Publishes a material whose file lives elsewhere (Google Drive, etc.) - saves only the link.
  Future<bool> addMaterialLink({
    required String fileUrl,
    required String fileExtension,
    required String title,
    required String description,
    required String academicYear,
    required String semester,
    required String subject,
    required String materialType,
    required String uploaderName,
  }) async {
    _isUploading = true;
    _uploadError = null;
    notifyListeners();

    try {
      await _firestoreService.addMaterial(StudyMaterial(
        id: '',
        title: title.trim(),
        description: description.trim(),
        academicYear: academicYear,
        semester: semester,
        subject: subject.trim(),
        materialType: materialType,
        fileUrl: fileUrl.trim(),
        fileName: title.trim(),
        fileExtension: fileExtension,
        fileSizeBytes: 0,
        uploadedBy: uploaderName,
        uploadedAt: DateTime.now(),
        downloadCount: 0,
      ));
      _isUploading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _uploadError = 'فشل النشر: $e';
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteMaterial(StudyMaterial material) async {
    try {
      await _firestoreService.deleteMaterial(material.id);
    } catch (e) {
      debugPrint('Delete material error: $e');
    }
  }

  Future<void> recordDownload(String materialId) async {
    await _firestoreService.incrementDownloadCount(materialId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
