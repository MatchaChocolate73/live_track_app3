import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/geofence_area.dart';

/// Mengatur area geofence (misal "Rumah", "Kantor") dan mendeteksi kapan
/// seseorang masuk/keluar area itu, dipakai untuk notifikasi otomatis
/// seperti "Ani sudah sampai di Kantor".
///
/// Deteksi dilakukan di sisi client masing-masing device (device yang
/// dipantau yang mengecek posisinya sendiri terhadap geofence, lalu kirim
/// event ke Firestore) - BUKAN device lain yang menghitung jarak orang lain.
/// Ini penting: device sendiri tidak pernah tahu geofence siapa yang
/// memantau dirinya secara detail, cukup tahu "trigger event ini kalau
/// posisiku masuk radius X dari titik Y".
class GeofenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, bool> _lastInsideState = {}; // geofenceId -> status terakhir

  Future<String> createGeofence({
    required String groupId,
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required String createdBy,
    required String watchedUid,
  }) async {
    final docRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('geofences')
        .doc();

    final area = GeofenceArea(
      id: docRef.id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      createdBy: createdBy,
      watchedUid: watchedUid,
    );

    await docRef.set(area.toMap());
    return docRef.id;
  }

  Future<List<GeofenceArea>> getGeofencesForUid({
    required String groupId,
    required String watchedUid,
  }) async {
    final snapshot = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('geofences')
        .where('watchedUid', isEqualTo: watchedUid)
        .get();

    return snapshot.docs
        .map((doc) => GeofenceArea.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Panggil setiap ada update posisi baru (biasanya dari LocationService),
  /// untuk mengecek apakah device ini baru saja masuk/keluar salah satu
  /// geofence yang memantau dirinya.
  Future<void> checkGeofences({
    required String groupId,
    required String currentUid,
    required double currentLat,
    required double currentLng,
  }) async {
    final geofences = await getGeofencesForUid(
      groupId: groupId,
      watchedUid: currentUid,
    );

    for (final fence in geofences) {
      final distanceMeters = Geolocator.distanceBetween(
        currentLat,
        currentLng,
        fence.latitude,
        fence.longitude,
      );

      final isInside = distanceMeters <= fence.radiusMeters;
      final wasInside = _lastInsideState[fence.id] ?? false;

      if (isInside && !wasInside) {
        await _recordGeofenceEvent(groupId, fence, currentUid, entered: true);
      } else if (!isInside && wasInside) {
        await _recordGeofenceEvent(groupId, fence, currentUid, entered: false);
      }

      _lastInsideState[fence.id] = isInside;
    }
  }

  /// Catat event ke Firestore. Cloud Function terpisah akan membaca ini
  /// dan mengirim push notification ke [fence.createdBy] (lihat
  /// functions/index.js -> onGeofenceEvent).
  Future<void> _recordGeofenceEvent(
    String groupId,
    GeofenceArea fence,
    String uid, {
    required bool entered,
  }) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('geofence_events')
        .add({
      'geofenceId': fence.id,
      'geofenceName': fence.name,
      'uid': uid,
      'entered': entered,
      'notifyUid': fence.createdBy,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteGeofence(String groupId, String geofenceId) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('geofences')
        .doc(geofenceId)
        .delete();
  }
}
