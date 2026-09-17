import 'dart:math' as math;

class RouteHistoryPoint {
  final double latitude;
  final double longitude;
  final double speedKmh;
  final DateTime timestamp;

  RouteHistoryPoint({
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.timestamp,
  });

  factory RouteHistoryPoint.fromMap(Map<dynamic, dynamic> map) {
    return RouteHistoryPoint(
      latitude: (map['lat'] as num).toDouble(),
      longitude: (map['lng'] as num).toDouble(),
      speedKmh: (map['speed'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['ts'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lat': latitude,
      'lng': longitude,
      'speed': speedKmh,
      'ts': timestamp.millisecondsSinceEpoch,
    };
  }
}

/// Kumpulan titik lokasi dalam satu hari untuk satu user, dipakai untuk
/// menampilkan jalur perjalanan (polyline) di peta + statistik ringkas.
class DailyRoute {
  final String uid;
  final DateTime date;
  final List<RouteHistoryPoint> points;

  DailyRoute({required this.uid, required this.date, required this.points});

  /// Total jarak tempuh dalam km, dihitung dari jumlah jarak antar titik
  /// berurutan menggunakan formula Haversine (memperhitungkan kelengkungan bumi).
  double get totalDistanceKm {
    double total = 0;
    for (int i = 1; i < points.length; i++) {
      total += _haversineDistanceKm(points[i - 1], points[i]);
    }
    return total;
  }

  double get maxSpeedKmh {
    if (points.isEmpty) return 0;
    return points.map((p) => p.speedKmh).reduce((a, b) => a > b ? a : b);
  }

  double get avgSpeedKmh {
    final movingPoints = points.where((p) => p.speedKmh > 1).toList();
    if (movingPoints.isEmpty) return 0;
    final total = movingPoints.map((p) => p.speedKmh).reduce((a, b) => a + b);
    return total / movingPoints.length;
  }

  static double _haversineDistanceKm(RouteHistoryPoint a, RouteHistoryPoint b) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final lat1 = _toRad(a.latitude);
    final lat2 = _toRad(b.latitude);

    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadiusKm * math.asin(math.sqrt(h));
  }

  static double _toRad(double deg) => deg * (math.pi / 180);
}
