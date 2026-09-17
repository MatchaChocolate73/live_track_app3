class LiveLocation {
  final String uid;
  final double latitude;
  final double longitude;
  final double speedKmh;      // kecepatan real-time (0 kalau diam)
  final double heading;       // arah hadap (derajat) untuk arah panah di peta
  final DateTime timestamp;
  final bool isFromSmsFallback; // true kalau data ini dikirim lewat SMS (mode offline data)
  final double? batteryLevel;

  LiveLocation({
    required this.uid,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.heading,
    required this.timestamp,
    this.isFromSmsFallback = false,
    this.batteryLevel,
  });

  factory LiveLocation.fromMap(Map<dynamic, dynamic> map, String uid) {
    return LiveLocation(
      uid: uid,
      latitude: (map['lat'] as num).toDouble(),
      longitude: (map['lng'] as num).toDouble(),
      speedKmh: (map['speed'] as num?)?.toDouble() ?? 0.0,
      heading: (map['heading'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['ts'] as int),
      isFromSmsFallback: map['viaSms'] as bool? ?? false,
      batteryLevel: (map['battery'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lat': latitude,
      'lng': longitude,
      'speed': speedKmh,
      'heading': heading,
      'ts': timestamp.millisecondsSinceEpoch,
      'viaSms': isFromSmsFallback,
      'battery': batteryLevel,
    };
  }

  /// Berapa lama data ini sudah "basi" (untuk tampilkan "terakhir terlihat X menit lalu")
  Duration get age => DateTime.now().difference(timestamp);
}
