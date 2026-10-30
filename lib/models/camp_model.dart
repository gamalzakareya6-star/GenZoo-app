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
  final String kind; // link | upload | app

  const CampFile({required this.id, required this.title, required this.url, this.kind = 'link'});

  factory CampFile.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return CampFile(
      id: doc.id,
      title: d['title'] as String? ?? 'ملف',
      url: d['url'] as String? ?? '',
      kind: d['kind'] as String? ?? 'link',
    );
  }
}

class CampMember {
  final String uid;
  final String name;
  const CampMember({required this.uid, required this.name});
}

class CampMessage {
  final String id;
  final String uid;
  final String name;
  final String text;
  final String imageUrl;
  final String fileName;
  final String fileUrl;
  final String audioUrl;
  final int audioSecs;
  final Map<String, String> reactions; // uid -> emoji
  final List<String> seenBy;
  final Map<String, dynamic>? replyTo; // {id, name, text}
  final bool edited;
  final bool deleted;
  final DateTime createdAt;

  const CampMessage({
    required this.id,
    required this.uid,
    required this.name,
    required this.text,
    required this.imageUrl,
    required this.fileName,
    required this.fileUrl,
    required this.audioUrl,
    required this.audioSecs,
    required this.reactions,
    required this.seenBy,
    required this.replyTo,
    required this.edited,
    required this.deleted,
    required this.createdAt,
  });

  factory CampMessage.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final r = d['reactions'];
    return CampMessage(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      name: d['name'] as String? ?? 'عضو',
      text: d['text'] as String? ?? '',
      imageUrl: d['imageUrl'] as String? ?? '',
      fileName: d['fileName'] as String? ?? '',
      fileUrl: d['fileUrl'] as String? ?? '',
      audioUrl: d['audioUrl'] as String? ?? '',
      audioSecs: (d['audioSecs'] as num?)?.toInt() ?? 0,
      reactions: r is Map ? {for (final e in r.entries) '${e.key}': '${e.value}'} : const {},
      seenBy: (d['seenBy'] as List<dynamic>? ?? []).whereType<String>().toList(),
      replyTo: d['replyTo'] is Map ? Map<String, dynamic>.from(d['replyTo'] as Map) : null,
      edited: d['edited'] as bool? ?? false,
      deleted: d['deleted'] as bool? ?? false,
      // A message just sent has no server time yet: show it as "now".
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class CampTyping {
  final String uid;
  final String name;
  final DateTime at;
  const CampTyping({required this.uid, required this.name, required this.at});
}
