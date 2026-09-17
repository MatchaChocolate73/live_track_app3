import 'package:cloud_functions/cloud_functions.dart';

/// Wrapper pemanggilan Cloud Function untuk emergency share.
///
/// Catatan desain: fungsi ini TIDAK menerima parameter "targetUid" untuk
/// dibagikan atas nama orang lain. createShare() SELALU membuat share
/// untuk user yang sedang login (ditentukan server dari context.auth.uid),
/// sehingga secara struktural mustahil dipakai untuk membocorkan lokasi
/// orang lain dari sisi client.
class EmergencyShareService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static Future<EmergencyShareResult> createShare({int durationHours = 4}) async {
    final callable = _functions.httpsCallable('createEmergencyShare');
    final result = await callable.call({'durationHours': durationHours});
    return EmergencyShareResult(
      token: result.data['token'],
      expiresAt: DateTime.fromMillisecondsSinceEpoch(result.data['expiresAt']),
    );
  }

  static Future<void> revokeShare(String token) async {
    final callable = _functions.httpsCallable('revokeEmergencyShare');
    await callable.call({'token': token});
  }

  /// URL yang dibuka orang di luar grup untuk melihat lokasi (read-only,
  /// hanya lokasi terkini, otomatis mati saat expired/dicabut).
  static String buildShareUrl(String token, String projectId, String region) {
    return 'https://$region-$projectId.cloudfunctions.net/getEmergencySharedLocation?token=$token';
  }
}

class EmergencyShareResult {
  final String token;
  final DateTime expiresAt;

  EmergencyShareResult({required this.token, required this.expiresAt});
}
