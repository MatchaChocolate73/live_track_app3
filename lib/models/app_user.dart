class AppUser {
  final String uid;
  final String name;
  final String? photoUrl;
  final String fcmToken; // dipakai untuk kirim notif "bunyikan HP"
  final String? phoneNumber; // dipakai untuk fallback SMS

  AppUser({
    required this.uid,
    required this.name,
    this.photoUrl,
    required this.fcmToken,
    this.phoneNumber,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      name: map['name'] ?? 'Tanpa Nama',
      photoUrl: map['photoUrl'],
      fcmToken: map['fcmToken'] ?? '',
      phoneNumber: map['phoneNumber'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'photoUrl': photoUrl,
      'fcmToken': fcmToken,
      'phoneNumber': phoneNumber,
    };
  }
}
