import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/live_location.dart';
import '../services/location_service.dart';
import 'home_widget_service.dart';

/// Menyediakan stream posisi semua anggota grup ke UI (peta & daftar).
/// Dipakai lewat Provider supaya semua screen bisa dengar update yang sama
/// tanpa duplikasi listener ke Firebase.
class GroupLocationsProvider extends ChangeNotifier {
  final String groupId;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  StreamSubscription<DatabaseEvent>? _subscription;

  /// UID anggota yang mau ditampilkan di home screen widget (misal
  /// pasangan). Null berarti tidak ada widget yang perlu di-update.
  final String? widgetTrackedUid;

  final Map<String, LiveLocation> _liveLocations = {};
  Map<String, LiveLocation> get liveLocations => _liveLocations;

  GroupLocationsProvider({required this.groupId, this.widgetTrackedUid}) {
    _listen();
  }

  void _listen() {
    _subscription =
        _db.child('groups/$groupId/locations').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;

      data.forEach((uid, locMap) {
        _liveLocations[uid.toString()] =
            LiveLocation.fromMap(locMap as Map<dynamic, dynamic>, uid.toString());
      });

      // Kalau anggota yang di-widget-kan baru saja update posisinya,
      // dorong data terbaru ke home screen widget.
      if (widgetTrackedUid != null &&
          _liveLocations.containsKey(widgetTrackedUid)) {
        final loc = _liveLocations[widgetTrackedUid]!;
        HomeWidgetService.updateWidgetData(
          memberName: widgetTrackedUid!, // idealnya dipetakan ke nama asli oleh caller
          speedKmh: loc.speedKmh,
          statusLabel: statusLabelFor(widgetTrackedUid!),
          lastUpdate: loc.timestamp,
        );
      }

      notifyListeners();
    });
  }

  @override
  void dispose() {
    // WAJIB cancel listener Firebase di sini - kalau tidak, listener tetap
    // aktif "mendengar" data walau screen sudah ditutup (memory leak), dan
    // bisa memicu error kalau notifyListeners() terpanggil setelah provider
    // ini sudah tidak dipakai lagi.
    _subscription?.cancel();
    super.dispose();
  }

  /// Kalau salah satu anggota belum ada datanya di Realtime DB (misal dia
  /// sedang offline total & fallback SMS juga belum sampai), coba ambil
  /// last-known-location yang tersimpan lokal di HP kita sendiri (kalau
  /// pernah diterima sebelumnya lewat SMS).
  Future<LiveLocation?> getFallbackLocation(String uid) async {
    final cached = await LocationService.getLastKnownLocation(uid);
    if (cached == null) return null;
    return LiveLocation.fromMap(cached, uid);
  }

  /// Status untuk ditampilkan di UI: "Live" (data < 1 menit), atau
  /// "Terakhir terlihat X lalu" (data lebih lama / dari SMS fallback).
  String statusLabelFor(String uid) {
    final loc = _liveLocations[uid];
    if (loc == null) return 'Belum ada data';

    if (loc.isFromSmsFallback) {
      return 'Via SMS • ${_formatAge(loc.age)} lalu';
    }
    if (loc.age.inSeconds < 60) {
      return 'Live sekarang';
    }
    return 'Terakhir terlihat ${_formatAge(loc.age)} lalu';
  }

  String _formatAge(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds} detik';
    if (d.inMinutes < 60) return '${d.inMinutes} menit';
    if (d.inHours < 24) return '${d.inHours} jam';
    return '${d.inDays} hari';
  }
}
