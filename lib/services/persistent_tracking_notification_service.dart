import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

/// Menampilkan notifikasi persisten yang SELALU terlihat selama lokasi
/// sedang dibagikan - ini bukan opsional, ini bagian inti dari desain
/// privasi app: orang yang HP-nya melacak dirinya sendiri untuk dibagikan
/// harus selalu tahu itu sedang terjadi, tanpa cara untuk menyembunyikannya
/// selain benar-benar mematikan sharing.
///
/// Android: notifikasi ini terikat ke foreground service, sehingga:
/// - Tidak bisa di-swipe/dismiss oleh user selama service berjalan
/// - Selalu terlihat di status bar & notification shade
/// - Kalau tracking dimatikan, notifikasi otomatis hilang
///
/// iOS: Apple sendiri SUDAH menampilkan indikator sistem (panah/dot biru
/// di status bar, dan banner "App Name is using your location") secara
/// otomatis dan tidak bisa dimatikan oleh developer pihak ketiga - ini
/// justru perlindungan bawaan dari Apple. Kita tambahkan juga local
/// notification saat mulai/berhenti sharing supaya lebih jelas & eksplisit.
class PersistentTrackingNotificationService {
  static const int _notificationId = 888;
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Dipanggil sekali saat app start, daftarkan channel notifikasi DAN
  /// konfigurasi foreground service (tapi belum menyalakannya - autoStart
  /// sengaja false, supaya notifikasi/service baru benar-benar berjalan
  /// saat user menyalakan toggle sharing, bukan otomatis begitu app dibuka).
  static Future<void> init() async {
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'location_sharing_channel',
        'Status Berbagi Lokasi',
        description: 'Menunjukkan kapan lokasimu sedang dibagikan ke grup',
        importance: Importance.high,
        playSound: false,
        showBadge: true,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      final service = FlutterBackgroundService();
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: _onForegroundServiceStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: 'location_sharing_channel',
          initialNotificationTitle: 'Lokasimu sedang dibagikan',
          initialNotificationContent: 'Menyiapkan...',
          foregroundServiceNotificationId: _notificationId,
          foregroundServiceTypes: [AndroidForegroundType.location],
        ),
        iosConfiguration: IosConfiguration(autoStart: false),
      );
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _notifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
  }

  /// Panggil begitu tracking dimulai. Di Android ini menyalakan foreground
  /// service (yang sudah dikonfigurasi di init()) supaya notifikasi tidak
  /// bisa di-dismiss manual.
  static Future<void> startSharingNotification({required String groupName}) async {
    if (Platform.isAndroid) {
      final service = FlutterBackgroundService();
      await service.startService();
      service.invoke('updateNotification', {
        'title': 'Lokasimu sedang dibagikan',
        'content': 'Sedang aktif membagikan lokasi ke grup "$groupName"',
      });
    } else {
      // iOS: local notification biasa (tidak bisa dibuat "ongoing" seperti
      // Android, tapi sistem iOS sendiri sudah menampilkan indikator lokasi
      // yang tidak bisa disembunyikan aplikasi manapun).
      await _notifications.show(
        _notificationId,
        'Lokasimu sedang dibagikan',
        'Sedang aktif membagikan lokasi ke grup "$groupName"',
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
      );
    }
  }

  /// Panggil begitu user MATIKAN sharing lokasi. Ini satu-satunya cara
  /// notifikasi ini hilang - tidak ada cara menyembunyikannya selain ini.
  static Future<void> stopSharingNotification() async {
    if (Platform.isAndroid) {
      final service = FlutterBackgroundService();
      service.invoke('stopService');
    } else {
      await _notifications.cancel(_notificationId);
    }
  }
}

/// WAJIB top-level function (bukan method di dalam class) dengan pragma
/// entry-point, karena dipanggil dari isolate terpisah oleh sistem Android
/// saat menjalankan foreground service - kalau cuma method biasa/tanpa
/// pragma ini, bisa hilang saat di-compile ke mode release (tree-shaking).
@pragma('vm:entry-point')
void _onForegroundServiceStart(ServiceInstance service) {
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  if (service is AndroidServiceInstance) {
    service.on('updateNotification').listen((event) {
      final title = event?['title'] as String?;
      final content = event?['content'] as String?;
      if (title != null && content != null) {
        service.setForegroundNotificationInfo(title: title, content: content);
      }
    });
  }
  // Foreground service ini sengaja tidak melakukan pekerjaan lain -
  // fungsinya semata-mata membuat notifikasi tidak bisa di-dismiss
  // selama tracking (LocationService) berjalan terpisah.
}
