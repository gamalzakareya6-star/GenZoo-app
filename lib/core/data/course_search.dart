import '../utils/arabic_text.dart';
import 'bylaw_courses.dart';

class _CatalogEntry {
  final BylawCourse course;
  final String name;
  final String code;

  _CatalogEntry(this.course)
      : name = normalizeArabic(course.name),
        code = course.code.toLowerCase();
}

/// Searches the bylaw course catalog by name or code. Zoology courses come
/// first because the catalog is ordered that way.
class CourseSearch {
  static final List<_CatalogEntry> _entries =
      bylawCourses.map((c) => _CatalogEntry(c)).toList();

  static List<BylawCourse> search(String query, {int limit = 8}) {
    final q = normalizeArabic(query);
    if (q.isEmpty) return const [];
    final tokens = q.split(' ');

    final starts = <BylawCourse>[];
    final contains = <BylawCourse>[];
    for (final e in _entries) {
      final haystack = '${e.name} ${e.code}';
      if (!tokens.every((t) => haystack.contains(t))) continue;
      if (e.name.startsWith(q) || e.code.startsWith(q)) {
        starts.add(e.course);
      } else {
        contains.add(e.course);
      }
    }
    return [...starts, ...contains].take(limit).toList();
  }
}
