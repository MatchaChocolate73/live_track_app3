class GeofenceArea {
  final String id;
  final String name;       // misal "Rumah", "Kantor", "Sekolah"
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String createdBy;
  final String watchedUid; // notifikasi dikirim ke pembuat saat UID ini masuk/keluar

  GeofenceArea({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.createdBy,
    required this.watchedUid,
  });

  factory GeofenceArea.fromMap(Map<String, dynamic> map, String id) {
    return GeofenceArea(
      id: id,
      name: map['name'] ?? '',
      latitude: (map['lat'] as num).toDouble(),
      longitude: (map['lng'] as num).toDouble(),
      radiusMeters: (map['radius'] as num?)?.toDouble() ?? 100.0,
      createdBy: map['createdBy'] ?? '',
      watchedUid: map['watchedUid'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'lat': latitude,
      'lng': longitude,
      'radius': radiusMeters,
      'createdBy': createdBy,
      'watchedUid': watchedUid,
    };
  }
}
