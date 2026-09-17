const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const firestore = admin.firestore();
const rtdb = admin.database();
const messaging = admin.messaging();

/**
 * Setiap kali dokumen grup di Firestore berubah (anggota masuk/keluar),
 * sinkronkan ke Realtime Database supaya security rules RTDB bisa
 * langsung mengecek keanggotaan tanpa perlu akses Firestore.
 */
exports.syncGroupMembers = functions.firestore
  .document('groups/{groupId}')
  .onWrite(async (change, context) => {
    const groupId = context.params.groupId;

    if (!change.after.exists) {
      // Grup dihapus -> hapus juga data lokasi & member mirror-nya
      await rtdb.ref(`groups/${groupId}`).remove();
      await rtdb.ref(`groupMembers/${groupId}`).remove();
      return;
    }

    const memberUids = change.after.data().memberUids || [];
    const memberMap = {};
    memberUids.forEach((uid) => {
      memberMap[uid] = true;
    });

    await rtdb.ref(`groupMembers/${groupId}`).set(memberMap);

    // Kalau ada anggota yang di-remove, hapus juga data lokasinya
    // supaya tidak ada data basi yang nyangkut walau sudah bukan anggota.
    const beforeMembers = change.before.exists
      ? change.before.data().memberUids || []
      : [];
    const removedUids = beforeMembers.filter((u) => !memberUids.includes(u));
    for (const uid of removedUids) {
      await rtdb.ref(`groups/${groupId}/locations/${uid}`).remove();
    }
  });

/**
 * Cleanup otomatis kode undangan yang sudah expired, jalan tiap 30 menit.
 * Ini juga membatasi masa hidup kode di database supaya makin kecil
 * kemungkinan disalahgunakan.
 */
exports.cleanupExpiredInvites = functions.pubsub
  .schedule('every 30 minutes')
  .onRun(async () => {
    const now = Date.now();
    const snapshot = await firestore
      .collection('invites')
      .where('expiresAt', '<', now)
      .get();

    const batch = firestore.batch();
    snapshot.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    return null;
  });

/**
 * Trigger "bunyikan HP" jarak jauh - dipanggil dari app pengirim lewat
 * HTTPS Callable Function (bukan langsung kirim FCM dari client, supaya
 * kita bisa validasi dulu bahwa pengirim memang anggota grup target).
 */
exports.triggerRingPhone = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Harus login dulu.'
    );
  }

  const { groupId, targetUid } = data;
  const requesterUid = context.auth.uid;

  // Validasi: requester dan target harus sama-sama anggota grup yang sama
  const groupDoc = await firestore.collection('groups').doc(groupId).get();
  if (!groupDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Grup tidak ditemukan.');
  }
  const memberUids = groupDoc.data().memberUids || [];
  if (!memberUids.includes(requesterUid) || !memberUids.includes(targetUid)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Kamu bukan anggota grup ini bersama target.'
    );
  }

  const targetUserDoc = await firestore.collection('users').doc(targetUid).get();
  const fcmToken = targetUserDoc.data()?.fcmToken;
  if (!fcmToken) {
    throw new functions.https.HttpsError('not-found', 'Device target tidak ditemukan.');
  }

  await messaging.send({
    token: fcmToken,
    data: {
      type: 'RING_PHONE',
      fromUid: requesterUid,
      groupId: groupId,
    },
    android: {
      priority: 'high',
    },
    apns: {
      headers: {
        'apns-priority': '10',
        'apns-push-type': 'background',
      },
      payload: {
        aps: {
          'content-available': 1,
        },
      },
    },
  });

  return { success: true };
});

/**
 * Setiap kali ada event geofence baru (anggota masuk/keluar area yang
 * dipantau), kirim push notification ke user yang membuat geofence itu.
 * Contoh notif: "Ani sudah sampai di Kantor" atau "Ani meninggalkan Rumah".
 */
exports.onGeofenceEvent = functions.firestore
  .document('groups/{groupId}/geofence_events/{eventId}')
  .onCreate(async (snap, context) => {
    const event = snap.data();
    const notifyUid = event.notifyUid;

    const userDoc = await firestore.collection('users').doc(notifyUid).get();
    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) return null;

    const actionText = event.entered ? 'sampai di' : 'meninggalkan';

    // Ambil nama orang yang trigger event, biar notif jelas siapa
    const subjectDoc = await firestore.collection('users').doc(event.uid).get();
    const subjectName = subjectDoc.data()?.name || 'Seseorang';

    await messaging.send({
      token: fcmToken,
      notification: {
        title: `${subjectName} ${actionText} ${event.geofenceName}`,
        body: new Date().toLocaleTimeString('id-ID'),
      },
      data: {
        type: 'GEOFENCE_EVENT',
        groupId: context.params.groupId,
      },
    });

    return null;
  });

/**
 * Bersihkan riwayat rute (history) yang lebih tua dari 30 hari, jalan
 * sekali sehari, supaya Realtime Database tidak membengkak terus-terusan.
 */
exports.cleanupOldRouteHistory = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - 30);

    const groupsSnapshot = await firestore.collection('groups').get();
    for (const groupDoc of groupsSnapshot.docs) {
      const historyRef = rtdb.ref(`groups/${groupDoc.id}/history`);
      const historySnapshot = await historyRef.once('value');
      const historyData = historySnapshot.val();
      if (!historyData) continue;

      for (const uid of Object.keys(historyData)) {
        for (const dateKey of Object.keys(historyData[uid])) {
          const date = new Date(dateKey);
          if (date < cutoff) {
            await historyRef.child(uid).child(dateKey).remove();
          }
        }
      }
    }
    return null;
  });

/**
 * ================== EMERGENCY SHARE (share lokasi sementara ke luar grup) ==================
 *
 * ATURAN PRIVASI KETAT (jangan diubah tanpa mempertimbangkan ulang):
 * 1. HANYA pemilik lokasi (request.auth.uid === targetUid) yang bisa membuat
 *    atau mencabut share atas namanya sendiri. Tidak ada endpoint untuk
 *    membuat share atas nama orang lain, bahkan oleh sesama anggota grup.
 * 2. Link yang dihasilkan HANYA menunjukkan lokasi TERKINI orang itu -
 *    tidak ada riwayat rute, tidak ada data anggota grup lain, tidak ada
 *    nomor HP/data pribadi lain.
 * 3. Otomatis expired (default 4 jam, maksimal 24 jam) - tidak bisa dibuat
 *    permanen.
 * 4. Bisa dicabut kapan saja oleh pemiliknya, membuat link langsung mati
 *    walau belum expired.
 * 5. Token acak panjang (tidak bisa ditebak/brute-force dengan wajar).
 */

exports.createEmergencyShare = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Harus login dulu.');
  }

  const ownerUid = context.auth.uid; // SELALU dari auth, tidak menerima uid dari client
  const durationHours = Math.min(Math.max(data.durationHours || 4, 1), 24);
  const token = require('crypto').randomBytes(24).toString('hex');

  const expiresAt = Date.now() + durationHours * 60 * 60 * 1000;

  await firestore.collection('emergency_shares').doc(token).set({
    ownerUid,
    expiresAt,
    revoked: false,
    createdAt: Date.now(),
  });

  return { token, expiresAt };
});

exports.revokeEmergencyShare = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Harus login dulu.');
  }

  const { token } = data;
  const doc = await firestore.collection('emergency_shares').doc(token).get();
  if (!doc.exists) {
    throw new functions.https.HttpsError('not-found', 'Link tidak ditemukan.');
  }

  if (doc.data().ownerUid !== context.auth.uid) {
    throw new functions.https.HttpsError('permission-denied', 'Bukan link milikmu.');
  }

  await doc.ref.update({ revoked: true });
  return { success: true };
});

/**
 * Endpoint publik (tanpa auth, karena dibuka orang di luar grup lewat
 * link) untuk mengambil lokasi TERKINI SAJA dari owner token. Tidak
 * pernah mengembalikan riwayat, data anggota grup lain, atau data pribadi
 * di luar nama depan + posisi.
 */
exports.getEmergencySharedLocation = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  const token = req.query.token;
  if (!token) {
    res.status(400).json({ error: 'Token tidak ada.' });
    return;
  }

  const doc = await firestore.collection('emergency_shares').doc(token).get();
  if (!doc.exists) {
    res.status(404).json({ error: 'Link tidak valid.' });
    return;
  }

  const shareData = doc.data();
  if (shareData.revoked) {
    res.status(410).json({ error: 'Link ini sudah dicabut oleh pemiliknya.' });
    return;
  }
  if (Date.now() > shareData.expiresAt) {
    res.status(410).json({ error: 'Link ini sudah expired.' });
    return;
  }

  const groupsSnapshot = await firestore
    .collection('groups')
    .where('memberUids', 'array-contains', shareData.ownerUid)
    .get();

  let latestLocation = null;
  for (const groupDoc of groupsSnapshot.docs) {
    const locSnapshot = await rtdb
      .ref(`groups/${groupDoc.id}/locations/${shareData.ownerUid}`)
      .once('value');
    const loc = locSnapshot.val();
    if (loc && (!latestLocation || loc.ts > latestLocation.ts)) {
      latestLocation = loc;
    }
  }

  if (!latestLocation) {
    res.status(404).json({ error: 'Lokasi belum tersedia.' });
    return;
  }

  const ownerDoc = await firestore.collection('users').doc(shareData.ownerUid).get();
  const ownerName = ownerDoc.data()?.name || 'Seseorang';

  // Beri tahu pemilik setiap kali link-nya diakses, supaya dia tahu
  // persis kapan lokasinya benar-benar dilihat orang - transparansi ini
  // bagian dari menjaga privasi, bukan cuma soal siapa yang bisa akses.
  const ownerFcmToken = ownerDoc.data()?.fcmToken;
  if (ownerFcmToken) {
    await messaging.send({
      token: ownerFcmToken,
      notification: {
        title: 'Link lokasimu baru saja dibuka',
        body: 'Seseorang melihat lokasi share sementara kamu barusan.',
      },
      data: { type: 'EMERGENCY_SHARE_ACCESSED' },
    }).catch(() => {}); // jangan sampai gagal kirim notif bikin request utama gagal
  }

  res.status(200).json({
    name: ownerName,
    lat: latestLocation.lat,
    lng: latestLocation.lng,
    speed: latestLocation.speed,
    timestamp: latestLocation.ts,
    expiresAt: shareData.expiresAt,
  });
});
