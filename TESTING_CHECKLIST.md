# Checklist Testing Manual

Setelah `flutter run` berhasil dan app terbuka, test satu-satu fitur ini
dengan **2 device berbeda** (atau 1 device + 1 emulator) supaya bisa lihat
interaksi antar akun:

## 1. Login
- [ ] Masukkan nomor HP, dapat SMS OTP asli (pastikan nomor HP asli, bukan emulator kosong)
- [ ] Berhasil masuk ke halaman "Grup Live Tracking"

## 2. Buat & Gabung Grup
- [ ] Device A: buat grup baru, dapat kode 6 digit
- [ ] Device B: masukkan kode itu, berhasil masuk ke peta live yang sama
- [ ] Coba masukkan kode salah/expired di Device B → harus muncul pesan error, bukan crash

## 3. Live Tracking + Kecepatan
- [ ] Aktifkan toggle "Membagikan" di Device A
- [ ] **Notifikasi persisten muncul di Device A** dan tidak bisa di-swipe
- [ ] Device B melihat marker Device A bergerak di peta secara real-time
- [ ] Bawa Device A jalan kaki/naik motor → cek angka kecepatan berubah wajar

## 4. Mode Offline (SMS Fallback)
- [ ] Matikan data internet di Device A (tapi sinyal SMS tetap ada)
- [ ] Device A tetap bergerak → cek di Device B apakah lokasi masih terupdate (mungkin ada delay karena lewat SMS)
- [ ] Nyalakan lagi internet Device A → cek data lokasi lanjut normal (real-time lagi)

## 5. Bunyikan HP
- [ ] Set Device B ke mode silent
- [ ] Dari Device A, tekan ikon speaker di sebelah nama Device B
- [ ] Device B harus bergetar + bunyi (Android) atau minimal notifikasi + getar (iOS silent mode)

## 6. Riwayat Rute
- [ ] Setelah Device A bergerak beberapa saat, tekan-lama nama Device A di daftar anggota (Device B)
- [ ] Cek polyline rute muncul di peta + statistik jarak/kecepatan masuk akal

## 7. Geofence
- [ ] Buat geofence lewat ikon di app bar, pilih lokasi & radius, pilih Device A sebagai yang dipantau
- [ ] Gerakkan Device A masuk/keluar radius itu → cek notifikasi muncul di device pembuat geofence

## 8. Emergency Share
- [ ] Buka menu emergency share, buat link
- [ ] Buka link itu di browser (device ketiga/laptop) → harus muncul lokasi terkini saja
- [ ] Cabut link → buka lagi link yang sama → harus muncul pesan "sudah dicabut"

## Error umum yang mungkin muncul di percobaan pertama
| Gejala | Kemungkinan Penyebab |
|---|---|
| App crash saat start | `google-services.json` belum ditaruh/salah tempat |
| Peta blank/abu-abu | API Key Google Maps belum diisi/salah |
| Login OTP tidak sampai | Fitur Phone Auth belum diaktifkan di Firebase Console |
| Lokasi tidak update sama sekali | Security Rules belum di-deploy, atau permission lokasi ditolak di HP |
| Notifikasi tidak muncul | Permission notifikasi ditolak (khusus Android 13+, harus izin manual) |
