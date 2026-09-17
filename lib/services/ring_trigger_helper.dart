import 'package:cloud_functions/cloud_functions.dart';

class RingTriggerHelper {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Meminta server (Cloud Function) mengirim sinyal bunyikan HP ke
  /// [targetUid]. Validasi keanggotaan grup dilakukan di server, jadi
  /// client tidak bisa memaksa kirim ke orang di luar grupnya.
  static Future<void> ringPhone({
    required String groupId,
    required String targetUid,
  }) async {
    final callable = _functions.httpsCallable('triggerRingPhone');
    await callable.call({
      'groupId': groupId,
      'targetUid': targetUid,
    });
  }
}
