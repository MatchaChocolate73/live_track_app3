import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'sms_fallback_service.dart';
import 'route_history_service.dart';
import 'geofence_service.dart';
import 'persistent_tracking_notification_service.dart';

/// Service utama: ambil posisi GPS real-time, hitung kecepatan,
/// kirim ke Firebase Realtime DB, dan fallback ke SMS kalau tidak ada internet.
class LocationService {
  final String currentUid;
  final String groupId;
  StreamSubscription<Position>? _positionStream;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final SmsFallbackService _smsFallback = SmsFallbackService();
  final RouteHistoryService _historyService = RouteHistoryService();
  final GeofenceService _geofenceService = GeofenceService();

  LocationService({required this.currentUid, required this.groupId});

  /// Panggil ini saat app start / user aktifkan sharing.
  /// Setting kecepatan tinggi update (distanceFilter kecil) untuk hasil
  /// yang terasa "real-time".
  ///
  /// [groupName] dipakai untuk teks notifikasi persisten, supaya jelas
  /// lokasi sedang dibagikan ke grup mana.
  Future<void> startTracking({required String groupName}) async {
    final permission = await _ensurePermission();
    if (!permission) {
      throw Exception('Izin lokasi ditolak. Tracking tidak bisa berjalan.');
    }

    // Notifikasi persisten WAJIB muncul sebelum tracking benar-benar mulai
    // mengirim data - tidak ada jalur di mana lokasi terkirim tanpa
    // notifikasi ini aktif duluan.
    await PersistentTrackingNotificationService.startSharingNotification(
      groupName: groupName,
    );

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 3, // update tiap pergerakan >= 3 meter
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen(_onNewPosition, onError: (e) {
      print('Location stream error: $e');
    });
  }

  Future<void> stopTracking() async {
    _positionStream?.cancel();
    _positionStream = null;
    // Notifikasi hilang di sini - ini satu-satunya jalur untuk
    // menghilangkannya, sejalan dengan berhentinya pengiriman lokasi.
    await PersistentTrackingNotificationService.stopSharingNotification();
  }

  Future<void> _onNewPosition(Position position) async {
    final speedKmh = (position.speed * 3.6).clamp(0, 300); // m/s -> km/h
    final data = {
      'lat': position.latitude,
      'lng': position.longitude,
      'speed': speedKmh,
      'heading': position.heading,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'viaSms': false,
    };

    // Simpan cache lokal dulu (untuk "last known location" kalau nanti offline)
    await _cacheLocally(data);

    // Cek geofence setiap update posisi - ringan karena cuma hitung jarak
    // matematis, tidak perlu network call kecuali memang ada event baru.
    _geofenceService
        .checkGeofences(
          groupId: groupId,
          currentUid: currentUid,
          currentLat: position.latitude,
          currentLng: position.longitude,
        )
        .catchError((_) {});

    final hasInternet = await _hasInternet();
    if (hasInternet) {
      await _sendViaFirebase(data);
      // Simpan juga sebagai titik riwayat, supaya nanti bisa ditampilkan
      // sebagai jalur perjalanan (polyline) di layar riwayat rute.
      // Tidak diblok kalau gagal, supaya tidak mengganggu tracking utama.
      _historyService
          .savePoint(
            groupId: groupId,
            uid: currentUid,
            lat: position.latitude,
            lng: position.longitude,
            speedKmh: speedKmh.toDouble(),
          )
          .catchError((_) {});
    } else {
      // Fallback: kirim posisi lewat SMS ke semua anggota grup
      await _smsFallback.sendLocationViaSms(
        groupId: groupId,
        senderUid: currentUid,
        latitude: position.latitude,
        longitude: position.longitude,
        speedKmh: speedKmh.toDouble(),
      );
    }
  }

  Future<void> _sendViaFirebase(Map<String, dynamic> data) async {
    try {
      await _db
          .child('groups/$groupId/locations/$currentUid')
          .set(data)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      // Kalau ternyata gagal kirim (misal internet lambat), fallback ke SMS juga
      await _smsFallback.sendLocationViaSms(
        groupId: groupId,
        senderUid: currentUid,
        latitude: data['lat'],
        longitude: data['lng'],
        speedKmh: (data['speed'] as num).toDouble(),
      );
    }
  }

  Future<bool> _hasInternet() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<void> _cacheLocally(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_known_location_$currentUid', jsonEncode(data));
  }

  /// Ambil posisi terakhir yang tersimpan lokal (dipakai saat mau tampilkan
  /// "posisi terakhir" walau user itu sedang offline sekarang)
  static Future<Map<String, dynamic>?> getLastKnownLocation(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('last_known_location_$uid');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<bool> _ensurePermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    // Untuk tracking background di Android, sebaiknya minta
    // LocationPermission.always juga.
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
