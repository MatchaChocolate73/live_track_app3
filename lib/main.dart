import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/ring_phone_service.dart';
import 'services/sms_listener_service.dart';
import 'services/persistent_tracking_notification_service.dart';
import 'theme/app_theme.dart';
import 'screens/group_setup_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool firebaseReady = true;

  // Konfigurasi Firebase ditulis langsung di kode (bukan lewat file
  // google-services.json/GoogleService-Info.plist) supaya app ini bisa
  // di-build di platform manapun (termasuk GitHub Actions) tanpa perlu
  // setup file konfigurasi native yang rumit per-platform.
  //
  // NILAI DI BAWAH INI PLACEHOLDER/CONTOH - app akan tetap bisa dibuka
  // dan semua tampilan/UI berfungsi normal, tapi fitur yang benar-benar
  // butuh server (login, kirim lokasi, dst) akan gagal dengan pesan error
  // yang wajar (bukan crash) sampai kamu ganti nilai ini dengan punya
  // project Firebase kamu sendiri.
  //
  // Cara ganti dengan yang asli: buka Firebase Console > project kamu >
  // ikon gerigi > Project settings > scroll ke "Your apps" > pilih app
  // Android/iOS kamu > salin nilai-nilai di bawah "SDK setup and
  // configuration" ke sini.
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyDUMMY00000000000000000000000000000',
        appId: '1:000000000000:android:0000000000000000000000',
        messagingSenderId: '000000000000',
        projectId: 'live-track-app-demo',
        storageBucket: 'live-track-app-demo.appspot.com',
      ),
    );
  } catch (e) {
    // Kalau inisialisasi gagal total (misal konfigurasi belum diganti),
    // app tetap dibuka supaya tampilan/UI tetap bisa dilihat & dicoba,
    // bukan langsung crash ke layar hitam.
    debugPrint('Firebase init gagal (pakai config asli untuk fitur penuh): $e');
    firebaseReady = false;
  }

  // Aktifkan pendengar sinyal "bunyikan HP" sejak awal app dibuka,
  // supaya bisa merespons walau user sedang di screen manapun.
  await RingPhoneService().init();

  // Aktifkan listener SMS sejak awal, supaya lokasi fallback dari anggota
  // grup yang offline tetap tertangkap walau app baru dibuka lagi nanti.
  await SmsListenerService().init();

  await PersistentTrackingNotificationService.init();

  runApp(LiveTrackApp(firebaseReady: firebaseReady));
}

class LiveTrackApp extends StatelessWidget {
  final bool firebaseReady;
  const LiveTrackApp({super.key, required this.firebaseReady});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Track',
      theme: AppTheme.theme,
      // Kalau Firebase gagal total diinisialisasi (kasus langka, biasanya
      // cuma kalau konfigurasi di atas rusak), langsung tampilkan Login
      // Screen tanpa mendengarkan status login - supaya tampilan/UI tetap
      // bisa dilihat & dicoba, bukan layar error/hitam.
      home: firebaseReady
          ? StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasData) {
                  return const GroupSetupScreen();
                }
                return const LoginScreen();
              },
            )
          : const LoginScreen(),
    );
  }
}
