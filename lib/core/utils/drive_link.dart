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
