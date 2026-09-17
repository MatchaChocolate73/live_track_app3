class TrackGroup {
  final String groupId;
  final String name;             // misal "Aku & Dia" atau "Keluarga"
  final String ownerUid;
  final List<String> memberUids; // hanya UID yang sudah accept invite masuk sini
  final String inviteCode;       // kode 6 digit, sekali pakai, expired 10 menit
  final DateTime createdAt;

  TrackGroup({
    required this.groupId,
    required this.name,
    required this.ownerUid,
    required this.memberUids,
    required this.inviteCode,
    required this.createdAt,
  });

  factory TrackGroup.fromMap(Map<String, dynamic> map, String id) {
    return TrackGroup(
      groupId: id,
      name: map['name'] ?? '',
      ownerUid: map['ownerUid'] ?? '',
      memberUids: List<String>.from(map['memberUids'] ?? []),
      inviteCode: map['inviteCode'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerUid': ownerUid,
      'memberUids': memberUids,
      'inviteCode': inviteCode,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
