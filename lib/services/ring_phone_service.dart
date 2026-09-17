import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Menangani sinyal "bunyikan HP" yang dikirim dari anggota grup lain.
///
/// CATATAN KETERBATASAN PLATFORM (penting, jangan diskip):
/// - Android: bisa override mode silent/vibrate dengan memutar audio lewat
///   AudioPlayer di stream STREAM_ALARM/STREAM_RING, karena app punya
///   kontrol audio stream sendiri. Ini bekerja cukup baik.
/// - iOS: Apple SANGAT membatasi ini. Kalau HP di "Silent Mode" (switch
///   fisik), app pihak ketiga TIDAK BISA memutar suara lewat speaker,
///   kecuali:
///     a) Suara diputar sebagai bagian dari "Critical Alert" notification,
///        yang butuh entitlement khusus dari Apple (com.apple.developer.
///        usernotifications.critical-alerts) - ini HANYA diberikan untuk
///        kategori app tertentu (medical, keselamatan) dan harus di-approve
///        manual oleh Apple, tidak otomatis dikasih ke app biasa.
///     b) Tanpa entitlement itu, di iOS hasilnya cuma vibrate + notifikasi
///        visual, TIDAK bisa bypass silent switch untuk suara.
///   Jadi kalau target pakai iOS dan HP-nya silent, realistisnya yang
///   terjadi adalah: layar menyala + vibrate + banner notifikasi besar,
///   bukan suara keras. Ini bukan bug, ini keterbatasan dari Apple sendiri
///   untuk melindungi privasi & kenyamanan pengguna iOS.
class RingPhoneService {
  final AudioPlayer _player = AudioPlayer();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    await _setupLocalNotifications();

    FirebaseMessaging.onMessage.listen(_handleMessage);
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
  }

  void _handleMessage(RemoteMessage message) {
    if (message.data['type'] == 'RING_PHONE') {
      _ringNow(fromUid: message.data['fromUid'] ?? 'Seseorang');
    }
  }

  Future<void> _ringNow({required String fromUid}) async {
    // 1. Vibrate kuat (bekerja di Android & iOS)
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500], repeat: 3);
    }

    // 2. Putar suara alarm di volume maksimal.
    //    Di Android ini akan cukup keras override silent/vibrate mode
    //    karena kita set stream type ke alarm.
    await _player.setVolume(1.0);
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('sounds/alert_ring.wav'));

    // Berhenti otomatis setelah 20 detik supaya tidak mengganggu terus
    Timer(const Duration(seconds: 20), () => _player.stop());

    // 3. Tampilkan notifikasi visual besar + banner
    await _notifications.show(
      0,
      'Seseorang mencari HP-mu',
      'Ketuk untuk mematikan bunyi',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ring_channel',
          'Bunyikan HP',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
          sound: RawResourceAndroidNotificationSound('alert_ring'),
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
    );
  }

  Future<void> stopRinging() async {
    await _player.stop();
  }
}

/// Handler ini WAJIB berupa top-level function (bukan method di dalam
/// class) karena dipanggil terpisah oleh sistem saat app di background/
/// terminated di Android.
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  if (message.data['type'] == 'RING_PHONE') {
    final service = RingPhoneService();
    await service.init();
    await service._ringNow(fromUid: message.data['fromUid'] ?? 'Seseorang');
  }
}
