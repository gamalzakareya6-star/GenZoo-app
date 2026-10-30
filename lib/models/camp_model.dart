import 'package:cloud_firestore/cloud_firestore.dart';

class Camp {
  final String id;
  final String name;
  final String description;
  final bool isPublic;
  final String inviteCode;
  final String ownerId;
  final String ownerName;
  final List<String> adminIds;
  final List<String> memberIds;
  final DateTime startAt;
  final DateTime endAt;

  const Camp({
    required this.id,
    required this.name,
    required this.description,
    required this.isPublic,
    required this.inviteCode,
    required this.ownerId,
    required this.ownerName,
    required this.adminIds,
    required this.memberIds,
    required this.startAt,
    required this.endAt,
  });

  bool canManage(String uid) => uid == ownerId || adminIds.contains(uid);
  bool get hasEnded => DateTime.now().isAfter(endAt);

  factory Camp.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    List<String> strings(String k) => (d[k] as List<dynamic>? ?? []).whereType<String>().toList();
    return Camp(
      id: doc.id,
      name: d['name'] as String? ?? 'معسكر',
      description: d['description'] as String? ?? '',
      isPublic: d['isPublic'] as bool? ?? true,
      inviteCode: d['inviteCode'] as String? ?? '',
      ownerId: d['ownerId'] as String? ?? '',
      ownerName: d['ownerName'] as String? ?? '',
      adminIds: strings('adminIds'),
      memberIds: strings('memberIds'),
      startAt: (d['startAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endAt: (d['endAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 7)),
    );
  }
}

class CampTask {
  final String id;
  final String title;
  final String description;
  final DateTime? deadline;
  final List<String> doneBy;

  const CampTask({
    required this.id,
    required this.title,
    required this.description,
    required this.deadline,
    required this.doneBy,
  });

  bool isDone(String uid) => doneBy.contains(uid);
  bool get overdue => deadline != null && DateTime.now().isAfter(deadline!);

  factory CampTask.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return CampTask(
      id: doc.id,
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      deadline: (d['deadline'] as Timestamp?)?.toDate(),
      doneBy: (d['doneBy'] as List<dynamic>? ?? []).whereType<String>().toList(),
    );
  }
}

class CampFile {
  final String id;
  final String title;
  final String url;

  const CampFile({required this.id, required this.title, required this.url});

  factory CampFile.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return CampFile(id: doc.id, title: d['title'] as String? ?? 'ملف', url: d['url'] as String? ?? '');
  }
}

class CampMember {
  final String uid;
  final String name;
  const CampMember({required this.uid, required this.name});
}
