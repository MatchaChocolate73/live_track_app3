import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Memantau perubahan status koneksi. Begitu internet kembali setelah
/// sempat mati, semua data lokasi yang tersimpan di cache lokal (baik
/// dari GPS sendiri maupun dari SMS fallback yang diterima) langsung
/// didorong ke Firebase supaya semua anggota grup ter-update.
class ConnectivitySyncService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final String groupId;

  ConnectivitySyncService({required this.groupId});

  void startListening() {
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _syncCachedLocations();
      }
    });
  }

  Future<void> _syncCachedLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('last_known_location_'));

    for (final key in keys) {
      final uid = key.replaceFirst('last_known_location_', '');
      final raw = prefs.getString(key);
      if (raw == null) continue;

      final data = jsonDecode(raw) as Map<String, dynamic>;

      // Hanya sync kalau data ini cukup baru (< 30 menit), supaya tidak
      // mendorong data yang sudah sangat basi dan bikin bingung anggota lain.
      final ts = data['ts'] as int;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > const Duration(minutes: 30).inMilliseconds) continue;

      try {
        await _db.child('groups/$groupId/locations/$uid').update(data);
      } catch (_) {
        // Masih gagal, coba lagi di siklus berikutnya
      }
    }
  }
}
