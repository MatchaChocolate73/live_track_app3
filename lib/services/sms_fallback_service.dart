import 'dart:io';
import 'package:another_telephony/telephony.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Fallback saat HP tidak punya koneksi internet (data/WiFi mati)
/// tapi masih ada sinyal seluler biasa -> kirim lokasi lewat SMS.
///
/// Format SMS sengaja singkat & terstruktur, contoh:
/// "LT|groupId|uid|lat|lng|speed|timestamp"
/// supaya bisa diparse otomatis oleh HP penerima (kalau appnya juga terpasang).
///
/// PENTING: kirim SMS otomatis hanya didukung di Android (batasan Apple
/// di iOS, bukan kekurangan kode). Di iOS, method ini otomatis tidak
/// melakukan apa-apa alih-alih crash.
class SmsFallbackService {
  final Telephony telephony = Telephony.instance;
  static const String _tag = 'LT'; // "Live Track" prefix, biar mudah difilter

  Future<void> sendLocationViaSms({
    required String groupId,
    required String senderUid,
    required double latitude,
    required double longitude,
    required double speedKmh,
  }) async {
    if (!Platform.isAndroid) return; // fitur SMS tidak berlaku di iOS

    final phoneNumbers = await _getGroupMemberPhoneNumbers(groupId, senderUid);
    if (phoneNumbers.isEmpty) return;

    final message =
        '$_tag|$groupId|$senderUid|$latitude|$longitude|${speedKmh.toStringAsFixed(1)}|${DateTime.now().millisecondsSinceEpoch}';

    final granted = await telephony.requestPhoneAndSmsPermissions;
    if (granted != true) return;

    for (final number in phoneNumbers) {
      await telephony.sendSms(to: number, message: message);
    }
  }

  Future<List<String>> _getGroupMemberPhoneNumbers(
      String groupId, String excludeUid) async {
    final groupDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .get();
    final memberUids = List<String>.from(groupDoc.data()?['memberUids'] ?? []);

    final numbers = <String>[];
    for (final uid in memberUids) {
      if (uid == excludeUid) continue;
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final phone = userDoc.data()?['phoneNumber'];
      if (phone != null && phone.toString().isNotEmpty) {
        numbers.add(phone.toString());
      }
    }
    return numbers;
  }

  /// Dipanggil saat ada SMS masuk (lihat sms_listener_service.dart) yang
  /// formatnya cocok dengan tag "LT|..." -> parse jadi data lokasi.
  static Map<String, dynamic>? parseIncomingSms(String body) {
    if (!body.startsWith('$_tag|')) return null;
    final parts = body.split('|');
    if (parts.length != 7) return null;

    try {
      return {
        'groupId': parts[1],
        'senderUid': parts[2],
        'lat': double.parse(parts[3]),
        'lng': double.parse(parts[4]),
        'speed': double.parse(parts[5]),
        'ts': int.parse(parts[6]),
      };
    } catch (_) {
      return null;
    }
  }
}
