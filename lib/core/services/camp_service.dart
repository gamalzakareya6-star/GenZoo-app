import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/camp_model.dart';

class CampException implements Exception {
  final String message;
  CampException(this.message);
  @override
  String toString() => message;
}

/// Study camps. Firestore layout: camps/{id} (+ members, tasks, files) and
/// camp_codes/{code} for joining a private camp by its invite code.
class CampService {
  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _camps => _db.collection('camps');
  static CollectionReference<Map<String, dynamic>> get _codes => _db.collection('camp_codes');

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no look-alike characters
  static String _newCode() {
    final r = Random.secure();
    return List.generate(6, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
  }

  static List<Camp> _sortedCamps(QuerySnapshot s) {
    final list = s.docs.map(Camp.fromFirestore).toList();
    list.sort((a, b) => b.startAt.compareTo(a.startAt));
    return list;
  }

  static Stream<List<Camp>> streamMine(String uid) =>
      _camps.where('memberIds', arrayContains: uid).snapshots().map(_sortedCamps);

  static Stream<List<Camp>> streamPublic() =>
      _camps.where('isPublic', isEqualTo: true).snapshots().map(_sortedCamps);

  static Stream<Camp?> streamCamp(String id) =>
      _camps.doc(id).snapshots().map((d) => d.exists ? Camp.fromFirestore(d) : null);

  static Stream<List<CampTask>> streamTasks(String campId) => _camps.doc(campId).collection('tasks').snapshots().map((s) {
        final list = s.docs.map(CampTask.fromFirestore).toList();
        list.sort((a, b) => (a.deadline ?? DateTime(2100)).compareTo(b.deadline ?? DateTime(2100)));
        return list;
      });

  static Stream<List<CampFile>> streamFiles(String campId) =>
      _camps.doc(campId).collection('files').snapshots().map((s) => s.docs.map(CampFile.fromFirestore).toList());

  static Stream<List<CampMember>> streamMembers(String campId) => _camps.doc(campId).collection('members').snapshots().map(
        (s) => s.docs.map((d) => CampMember(uid: d.id, name: d.data()['name'] as String? ?? 'عضو')).toList(),
      );

  static Future<String> create({
    required String uid,
    required String userName,
    required String name,
    required String description,
    required bool isPublic,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final code = _newCode();
    final ref = _camps.doc();
    final batch = _db.batch();
    batch.set(ref, {
      'name': name.trim(),
      'description': description.trim(),
      'isPublic': isPublic,
      'inviteCode': code,
      'ownerId': uid,
      'ownerName': userName,
      'adminIds': <String>[],
      'memberIds': [uid],
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      // Removed automatically 3 days after the camp ends (see scripts/cleanup_camps.py).
      'deleteAfter': Timestamp.fromDate(endAt.add(const Duration(days: 3))),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(ref.collection('members').doc(uid), {
      'name': userName,
      'code': code,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_codes.doc(code), {'campId': ref.id, 'ownerId': uid});
    await batch.commit();
    return ref.id;
  }

  /// Joins a camp with its invite code. Returns the camp id.
  static Future<String> joinByCode({required String uid, required String userName, required String code}) async {
    final clean = code.trim().toUpperCase();
    final codeDoc = await _codes.doc(clean).get();
    final campId = codeDoc.data()?['campId'] as String?;
    if (campId == null) throw CampException('الكود غير صحيح أو انتهى المعسكر.');
    await joinPublic(campId: campId, uid: uid, userName: userName, code: clean);
    return campId;
  }

  static Future<void> joinPublic({required String campId, required String uid, required String userName, String? code}) async {
    final ref = _camps.doc(campId);
    final batch = _db.batch();
    batch.set(ref.collection('members').doc(uid), {
      'name': userName,
      if (code != null) 'code': code,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    batch.update(ref, {'memberIds': FieldValue.arrayUnion([uid])});
    await batch.commit();
  }

  static Future<void> leave({required String campId, required String uid}) async {
    final ref = _camps.doc(campId);
    final batch = _db.batch();
    batch.delete(ref.collection('members').doc(uid));
    batch.update(ref, {'memberIds': FieldValue.arrayRemove([uid])});
    await batch.commit();
  }

  static Future<void> addTask(String campId,
      {required String title, required String description, DateTime? deadline}) {
    return _camps.doc(campId).collection('tasks').add({
      'title': title.trim(),
      'description': description.trim(),
      'deadline': deadline == null ? null : Timestamp.fromDate(deadline),
      'doneBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> setDone(String campId, String taskId, String uid, bool done) {
    return _camps.doc(campId).collection('tasks').doc(taskId).update({
      'doneBy': done ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
    });
  }

  static Future<void> deleteTask(String campId, String taskId) =>
      _camps.doc(campId).collection('tasks').doc(taskId).delete();

  static Future<void> addFile(String campId, {required String title, required String url}) {
    return _camps.doc(campId).collection('files').add({
      'title': title.trim(),
      'url': url.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteFile(String campId, String fileId) =>
      _camps.doc(campId).collection('files').doc(fileId).delete();

  /// Deletes the camp with everything inside it (owner only).
  static Future<void> deleteCamp(Camp camp) async {
    final ref = _camps.doc(camp.id);
    for (final sub in ['tasks', 'files', 'members']) {
      final docs = await ref.collection(sub).get();
      for (var i = 0; i < docs.docs.length; i += 400) {
        final batch = _db.batch();
        for (final d in docs.docs.skip(i).take(400)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }
    final batch = _db.batch();
    if (camp.inviteCode.isNotEmpty) batch.delete(_codes.doc(camp.inviteCode));
    batch.delete(ref);
    await batch.commit();
  }
}
