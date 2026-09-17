import 'package:firebase_database/firebase_database.dart';
import '../models/route_history.dart';

/// Menyimpan setiap titik lokasi ke node history (terpisah dari node
/// "locations" yang cuma nyimpen posisi TERKINI), supaya bisa direkonstruksi
/// jadi rute perjalanan per hari.
///
/// Struktur: groups/{groupId}/history/{uid}/{yyyy-MM-dd}/{timestamp} -> point
class RouteHistoryService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<void> savePoint({
    required String groupId,
    required String uid,
    required double lat,
    required double lng,
    required double speedKmh,
  }) async {
    final now = DateTime.now();
    final dateKey = _dateKey(now);

    await _db
        .child('groups/$groupId/history/$uid/$dateKey/${now.millisecondsSinceEpoch}')
        .set({
      'lat': lat,
      'lng': lng,
      'speed': speedKmh,
      'ts': now.millisecondsSinceEpoch,
    });
  }

  Future<DailyRoute> getRouteForDate({
    required String groupId,
    required String uid,
    required DateTime date,
  }) async {
    final dateKey = _dateKey(date);
    final snapshot =
        await _db.child('groups/$groupId/history/$uid/$dateKey').get();

    if (!snapshot.exists) {
      return DailyRoute(uid: uid, date: date, points: []);
    }

    final data = snapshot.value as Map<dynamic, dynamic>;
    final points = data.values
        .map((v) => RouteHistoryPoint.fromMap(v as Map<dynamic, dynamic>))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return DailyRoute(uid: uid, date: date, points: points);
  }

  /// Hapus riwayat yang lebih lama dari [maxAgeDays] hari, supaya database
  /// tidak membengkak terus. Sebaiknya dipanggil dari Cloud Function
  /// terjadwal, bukan dari client.
  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
