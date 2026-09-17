import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/track_group.dart';

/// Mengatur pairing antar user. Prinsip privasi:
/// - Tidak ada "cari user by nama/nomor" secara publik
/// - Satu-satunya cara masuk grup adalah lewat inviteCode yang dibuat
///   pemilik grup, berlaku 10 menit, sekali pakai
/// - User yang sudah keluar/dikick tidak bisa lihat lokasi lagi (dicek di
///   security rules Firebase, bukan cuma di client)
class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<TrackGroup> createGroup({
    required String ownerUid,
    required String groupName,
  }) async {
    final inviteCode = _generateInviteCode();
    final docRef = _firestore.collection('groups').doc();

    final group = TrackGroup(
      groupId: docRef.id,
      name: groupName,
      ownerUid: ownerUid,
      memberUids: [ownerUid],
      inviteCode: inviteCode,
      createdAt: DateTime.now(),
    );

    await docRef.set(group.toMap());

    // Simpan mapping kode -> groupId dengan expiry, di collection terpisah
    // supaya gampang di-cleanup dan tidak bisa ditebak-tebak dari luar
    await _firestore.collection('invites').doc(inviteCode).set({
      'groupId': docRef.id,
      'expiresAt': DateTime.now()
          .add(const Duration(minutes: 10))
          .millisecondsSinceEpoch,
      'used': false,
    });

    return group;
  }

  /// User memasukkan kode undangan yang didapat langsung dari pasangan/
  /// temannya (lewat WA, ketemu langsung, dsb) - bukan dicari di dalam app.
  Future<TrackGroup?> joinGroupWithCode({
    required String uid,
    required String inviteCode,
  }) async {
    final inviteDoc =
        await _firestore.collection('invites').doc(inviteCode).get();

    if (!inviteDoc.exists) {
      throw Exception('Kode undangan tidak valid.');
    }

    final inviteData = inviteDoc.data()!;
    final expiresAt = inviteData['expiresAt'] as int;
    final used = inviteData['used'] as bool;

    if (used) {
      throw Exception('Kode undangan sudah pernah dipakai.');
    }
    if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
      throw Exception('Kode undangan sudah expired.');
    }

    final groupId = inviteData['groupId'] as String;
    final groupRef = _firestore.collection('groups').doc(groupId);

    await groupRef.update({
      'memberUids': FieldValue.arrayUnion([uid]),
    });
    await inviteDoc.reference.update({'used': true});

    final updatedGroup = await groupRef.get();
    return TrackGroup.fromMap(updatedGroup.data()!, groupId);
  }

  /// Keluarkan anggota (dipakai pemilik grup) atau keluar sendiri.
  /// Begitu di-remove, security rules Firebase akan otomatis blok akses
  /// dia ke node lokasi grup ini (lihat firebase_rules.txt).
  Future<void> removeMember({
    required String groupId,
    required String uidToRemove,
  }) async {
    await _firestore.collection('groups').doc(groupId).update({
      'memberUids': FieldValue.arrayRemove([uidToRemove]),
    });
  }

  Future<void> deleteGroup(String groupId) async {
    await _firestore.collection('groups').doc(groupId).delete();
    // Catatan: hapus juga node locations di Realtime DB lewat Cloud Function
    // trigger (lihat functions/index.js) supaya data lokasi ikut terhapus.
  }

  String _generateInviteCode() {
    final rand = Random.secure();
    return List.generate(6, (_) => rand.nextInt(10)).join();
  }

  Stream<TrackGroup> watchGroup(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .snapshots()
        .map((doc) => TrackGroup.fromMap(doc.data()!, doc.id));
  }
}
