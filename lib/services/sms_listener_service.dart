import 'dart:io';
import 'package:another_telephony/telephony.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'sms_fallback_service.dart';

/// Mendengarkan SMS masuk dari nomor anggota grup dan otomatis parse
/// jadi data lokasi kalau formatnya cocok (prefix "LT|").
///
/// PENTING soal privasi: service ini HANYA memproses SMS yang formatnya
/// pas dengan format internal kita (LT|groupId|uid|...). SMS lain (chat
/// biasa, OTP, dll) tidak disentuh/dibaca isinya untuk tujuan apapun.
///
/// PENTING soal platform: SMS otomatis (baca/kirim) HANYA didukung di
/// Android. Apple TIDAK mengizinkan aplikasi pihak ketiga membaca/mengirim
/// SMS secara programatik di iOS sama sekali - ini batasan sistem, bukan
/// kekurangan kode kita. Semua method di sini otomatis no-op (tidak
/// melakukan apa-apa) kalau dijalankan di iOS, supaya tidak crash.
class SmsListenerService {
  final Telephony telephony = Telephony.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<void> init() async {
    if (!Platform.isAndroid) return; // fitur SMS tidak berlaku di iOS

    final granted = await telephony.requestPhoneAndSmsPermissions;
    if (granted != true) return;

    telephony.listenIncomingSms(
      onNewMessage: _onSmsReceived,
      onBackgroundMessage: _backgroundSmsHandler,
      listenInBackground: true,
    );
  }

  Future<void> _onSmsReceived(SmsMessage message) async {
    final body = message.body;
    if (body == null) return;

    final parsed = SmsFallbackService.parseIncomingSms(body);
    if (parsed == null) return; // bukan format lokasi kita, abaikan total

    await _saveIncomingLocation(parsed);
  }

  Future<void> _saveIncomingLocation(Map<String, dynamic> parsed) async {
    final groupId = parsed['groupId'] as String;
    final senderUid = parsed['senderUid'] as String;

    final data = {
      'lat': parsed['lat'],
      'lng': parsed['lng'],
      'speed': parsed['speed'],
      'heading': 0.0, // heading tidak dikirim lewat SMS (hemat karakter)
      'ts': parsed['ts'],
      'viaSms': true,
    };

    // Cache lokal dulu, supaya langsung bisa ditampilkan walau kita
    // sendiri juga sedang tidak ada internet untuk push ke Firebase.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_known_location_$senderUid', jsonEncode(data));

    // Kalau kita (penerima SMS) punya internet, langsung teruskan ke
    // Firebase supaya anggota grup lain yang online juga bisa lihat update
    // ini tanpa perlu masing-masing terima SMS yang sama.
    try {
      await _db
          .child('groups/$groupId/locations/$senderUid')
          .set(data)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Kita sendiri juga offline, ya sudah - data tersimpan di cache lokal
      // saja dulu, nanti disinkronkan saat online lagi (lihat sync_service.dart)
    }
  }
}

/// Handler top-level wajib untuk background SMS listener di Android.
@pragma('vm:entry-point')
Future<void> _backgroundSmsHandler(SmsMessage message) async {
  final body = message.body;
  if (body == null) return;

  final parsed = SmsFallbackService.parseIncomingSms(body);
  if (parsed == null) return;

  final service = SmsListenerService();
  await service._saveIncomingLocation(parsed);
}
