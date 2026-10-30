/// Turns a Google Drive "view" link into a direct download link. Other links
/// are returned unchanged.
String directDownloadUrl(String url) {
  final u = url.trim();
  final byPath = RegExp(r'drive\.google\.com/file/d/([\w-]+)').firstMatch(u);
  final byParam = RegExp(r'drive\.google\.com/.*[?&]id=([\w-]+)').firstMatch(u);
  final id = byPath?.group(1) ?? byParam?.group(1);
  if (id != null) return 'https://drive.google.com/uc?export=download&id=$id';
  return u;
}

/// Extracts the file id of a Google Drive link, or null.
String? driveFileId(String url) {
  final u = url.trim();
  final byPath = RegExp(r'drive\.google\.com/file/d/([\w-]+)').firstMatch(u);
  final byParam = RegExp(r'drive\.google\.com/.*[?&]id=([\w-]+)').firstMatch(u);
  return byPath?.group(1) ?? byParam?.group(1);
}

/// A URL that Image.network can display for a Drive image (a resized
/// thumbnail). Other URLs are returned unchanged.
String driveImageUrl(String url, {int width = 1000}) {
  final id = driveFileId(url);
  if (id == null) return url.trim();
  return 'https://drive.google.com/thumbnail?id=$id&sz=w$width';
}
