/// A file saved inside the app so it can be opened without internet.
class OfflineFile {
  final String id; // material id, or "export_<time>" for exported copies
  final String title;
  final String subject;
  final String department;
  final String ext;
  final String path;
  final int size;
  final DateTime savedAt;
  final bool isExport;
  int lastPage;

  OfflineFile({
    required this.id,
    required this.title,
    required this.subject,
    required this.department,
    required this.ext,
    required this.path,
    required this.size,
    required this.savedAt,
    this.isExport = false,
    this.lastPage = 1,
  });

  bool get isPdf => ext.toLowerCase() == 'pdf';

  String get sizeLabel {
    if (size < 1024) return '$size بايت';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} ك.ب';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} م.ب';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'department': department,
        'ext': ext,
        'path': path,
        'size': size,
        'savedAt': savedAt.millisecondsSinceEpoch,
        'isExport': isExport,
        'lastPage': lastPage,
      };

  factory OfflineFile.fromJson(Map<String, dynamic> j) => OfflineFile(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        subject: j['subject'] as String? ?? '',
        department: j['department'] as String? ?? '',
        ext: j['ext'] as String? ?? 'pdf',
        path: j['path'] as String? ?? '',
        size: (j['size'] as num?)?.toInt() ?? 0,
        savedAt: DateTime.fromMillisecondsSinceEpoch((j['savedAt'] as num?)?.toInt() ?? 0),
        isExport: j['isExport'] as bool? ?? false,
        lastPage: (j['lastPage'] as num?)?.toInt() ?? 1,
      );
}
