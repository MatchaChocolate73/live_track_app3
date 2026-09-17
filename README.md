# Live Track App

Aplikasi live location tracking privat untuk pasangan/grup kecil yang saling
setuju berbagi lokasi. Dibangun dengan Flutter + Firebase.

## Fitur yang sudah dibangun
- ✅ Live location tracking real-time (update tiap pergerakan ≥3 meter)
- ✅ Kecepatan real-time saat berkendara (km/jam)
- ✅ Sistem grup privat via kode undangan 6 digit (expired 10 menit, sekali pakai)
- ✅ Firebase Security Rules — data lokasi HANYA bisa dibaca anggota grup yang sah
- ✅ Fallback SMS otomatis saat tidak ada koneksi internet
- ✅ Cache "last known location" lokal
- ✅ Bunyikan HP jarak jauh walau mode silent (dengan keterbatasan iOS yang dijelaskan di kode)
- ✅ Auto-cleanup data saat anggota keluar/dikick dari grup

## Fitur yang SENGAJA TIDAK dibangun
- ❌ Akses/ambil foto dari kamera device orang lain secara remote/diam-diam

Ini murni pertimbangan keamanan: kemampuan mengaktifkan kamera orang lain dari
jarak jauh tanpa dia aktif menekan sesuatu di layarnya adalah ciri khas utama
stalkerware, terlepas dari niat baik di baliknya. Kalau butuh "melihat sekitar
pasangan", solusi yang lebih sehat adalah minta dia share live video/foto yang
dia trigger sendiri — dua hal itu teknis beda jauh soal siapa yang pegang kontrol.

## Cara Setup

### 1. Firebase
```bash
# Install Firebase CLI kalau belum ada
npm install -g firebase-tools
firebase login
firebase init
# Pilih: Firestore, Realtime Database, Functions, Authentication
```

Deploy security rules:
```bash
firebase deploy --only firestore:rules
firebase deploy --only database
firebase deploy --only functions
```

Aktifkan di Firebase Console:
- Authentication → Sign-in method → Phone (untuk login OTP)
- Firestore Database → buat database
- Realtime Database → buat database
- Cloud Messaging → otomatis aktif

### 2. Konfigurasi Flutter
```bash
flutter pub get

# Android: download google-services.json dari Firebase Console,
# taruh di android/app/google-services.json

# iOS: download GoogleService-Info.plist dari Firebase Console,
# taruh di ios/Runner/GoogleService-Info.plist
```

### 3. Permission yang wajib ditambahkan

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
<uses-permission android:name="android.permission.SEND_SMS"/>
<uses-permission android:name="android.permission.READ_PHONE_STATE"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Dibutuhkan untuk membagikan lokasimu ke anggota grup.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Dibutuhkan agar lokasimu tetap terbagi walau app di background.</string>
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
  <string>fetch</string>
  <string>remote-notification</string>
</array>
```

Catatan iOS: untuk background location tracking yang benar-benar akurat,
Apple mewajibkan justifikasi jelas saat submit ke App Store (halaman
"Background Location" harus dijelaskan detail tujuannya).

### 4. Jalankan
```bash
flutter run
```

## Struktur Folder
```
lib/
  models/          -> Struktur data (User, LiveLocation, TrackGroup)
  services/        -> Logic inti (location, SMS fallback, ring phone, group)
  screens/         -> UI (login, setup grup, peta live)
firebase_rules_firestore.txt      -> Security rules Firestore
firebase_rules_realtimedb.json    -> Security rules Realtime Database
functions/index.js                -> Cloud Functions (sync grup, cleanup, trigger ring)
```

## Update terbaru - fitur yang baru ditambahkan
- ✅ Listener SMS masuk (`SmsListenerService`) — otomatis parse lokasi dari
  SMS fallback anggota grup yang offline, lalu teruskan ke Firebase
- ✅ Auto-sync cache lokal ke Firebase begitu koneksi internet kembali
  (`ConnectivitySyncService`)
- ✅ Riwayat rute harian dengan polyline di peta + statistik jarak/kecepatan
  (`RouteHistoryScreen`, tekan-lama nama anggota di peta live untuk membuka)
- ✅ Geofence — notifikasi otomatis saat anggota masuk/keluar area tertentu
  (misal "Ani sampai di Kantor"), dihitung di device masing-masing demi privasi
- ✅ Battery optimization prompt untuk Android, dengan penjelasan jelas ke
  user (bukan diam-diam), supaya tracking background tidak dimatikan sistem
- ✅ Auto-cleanup riwayat rute yang lebih dari 30 hari (Cloud Function)

## Update penyempurnaan ke-2 — fitur privasi ketat

### Custom marker foto profil
Marker di peta sekarang pakai foto profil bulat (atau avatar inisial kalau
tidak ada foto), lihat `lib/services/custom_marker_service.dart`.

### UI Geofence Creator
Tap peta untuk pilih titik, atur radius pakai slider, pilih anggota yang
dipantau — lihat `lib/screens/geofence_creator_screen.dart`.

### Emergency Share (share lokasi sementara ke luar grup)
Fitur ini dibangun dengan pagar privasi yang ketat, karena ini satu-satunya
fitur yang membuka lokasi ke orang DI LUAR grup:

1. **Hanya bisa dipakai untuk diri sendiri** — secara struktural, tidak ada
   parameter `targetUid` yang bisa diisi selain uid yang sedang login
   (dicek dari `context.auth.uid` di server, bukan dari input client).
   Tidak ada anggota grup yang bisa membuat link share atas nama anggota lain.
2. **Hanya lokasi terkini** — endpoint publiknya (`getEmergencySharedLocation`)
   tidak pernah mengembalikan riwayat rute atau data anggota grup lain.
3. **Otomatis expired** (1–24 jam, default 4 jam) — tidak bisa dibuat permanen.
4. **Bisa dicabut kapan saja** dari `lib/screens/emergency_share_screen.dart`,
   langsung mematikan akses walau belum expired.
5. **Firestore rules memblok akses langsung** ke collection `emergency_shares`
   — semua validasi (kepemilikan, expiry, revocation) ditegakkan di Cloud
   Function, bukan dipercaya dari client.

### Home Screen Widget
Menampilkan nama, kecepatan, dan status anggota yang dipilih tanpa perlu
buka app. Data yang ditampilkan widget SAMA dengan yang sudah terlihat di
dalam app — tidak ada data tambahan yang dibocorkan ke widget.

**Setup native (wajib, tidak otomatis dari `flutter pub get`):**

Android — sudah disediakan scaffold-nya:
- `android/app/src/main/kotlin/.../widget/LiveTrackWidgetProvider.kt`
- `android/app/src/main/res/layout/live_track_widget.xml`
- `android/app/src/main/res/xml/live_track_widget_info.xml`

Tambahkan juga di `android/app/src/main/AndroidManifest.xml` di dalam tag `<application>`:
```xml
<receiver android:name=".widget.LiveTrackWidgetProvider" android:exported="false">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/live_track_widget_info" />
</receiver>
```

iOS — WidgetKit butuh Widget Extension target terpisah yang HARUS dibuat
lewat Xcode (File → New → Target → Widget Extension), tidak bisa lewat
kode teks saja. Setelah target dibuat, gunakan `HomeWidget.getWidgetData`
di Swift-nya untuk membaca data yang sama yang disimpan dari Flutter.
Detail lengkap ada di dokumentasi package `home_widget`.

## Update penyempurnaan ke-3 — notifikasi persisten (wajib untuk lolos review store)

Sekarang saat lokasi sedang dibagikan, ada **notifikasi yang tidak bisa
di-dismiss** (Android) atau **indikator sistem iOS** yang selalu terlihat.
Ini bukan fitur opsional — ini pagar privasi inti supaya pemilik HP selalu
tahu kapan lokasinya sedang dibagikan, dan ini juga syarat wajib supaya
lolos review Google Play / Apple App Store untuk app kategori location-tracking.

Cara kerja:
- **Android**: notifikasi terikat ke foreground service (`flutter_background_service`).
  Selama service ini jalan, notifikasi TIDAK BISA di-swipe/dismiss oleh
  user, cuma bisa hilang dengan benar-benar mematikan sharing lewat toggle
  di app bar (`lib/screens/live_map_screen.dart`) — lihat switch besar di
  pojok kanan atas peta live.
- **iOS**: Apple sendiri sudah menampilkan indikator sistem (panah/dot biru
  di status bar) secara otomatis saat app pakai lokasi background, dan ini
  TIDAK BISA dimatikan oleh developer manapun — ini perlindungan bawaan
  dari Apple. Kita tambahkan juga local notification biasa saat
  mulai/berhenti sharing untuk kejelasan tambahan.

**Tambahan permission Android** yang perlu ada di `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```
(FOREGROUND_SERVICE dasar sudah ada di daftar permission sebelumnya di README ini)

## ⚠️ PENTING — Konfigurasi Android setelah `flutter create .`

Kalau kamu regenerate folder `android` lewat `flutter create .` (seperti yang
terjadi saat setup awal), file-nya sekarang berformat **Kotlin DSL**
(`build.gradle.kts`, bukan `build.gradle` lawas). Tambahkan ini secara manual:

**1. `android/build.gradle.kts`** (di root, bukan di dalam app/) — tambahkan
plugin Google Services:
```kotlin
plugins {
    id("com.google.gms.google-services") version "4.4.2" apply false
}
```

**2. `android/app/build.gradle.kts`** — tambahkan di bagian atas (dalam blok `plugins { }`):
```kotlin
plugins {
    id("com.google.gms.google-services")
}
```

**3. `android/app/src/main/AndroidManifest.xml`** — tambahkan permission ini
di dalam tag `<manifest>` (sejajar dengan tag `<application>`, bukan di
dalamnya):
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
<uses-permission android:name="android.permission.SEND_SMS"/>
<uses-permission android:name="android.permission.RECEIVE_SMS"/>
<uses-permission android:name="android.permission.READ_PHONE_STATE"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

Dan tambahkan ini di dalam tag `<application>`, sejajar dengan tag `<activity>`:
```xml
<receiver android:name=".widget.LiveTrackWidgetProvider" android:exported="false">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/live_track_widget_info" />
</receiver>
```

**4. Google Maps API Key** — juga di `AndroidManifest.xml`, di dalam `<application>`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="ISI_API_KEY_MAPS_KAMU_DI_SINI"/>
```

**5. `google-services.json`** — download dari Firebase Console, taruh persis
di `android/app/google-services.json` (bukan di folder lain).



### 1. Push ke GitHub
```bash
cd live_track_app
git init
git add .
git commit -m "Initial commit - Live Track App"

# Buat repo baru di github.com (bisa lewat web, klik "New repository")
# Jangan centang "Add README" di GitHub supaya tidak konflik dengan yang sudah ada

git remote add origin https://github.com/USERNAME/live_track_app.git
git branch -M main
git push -u origin main
```

Catatan: file `google-services.json`, keystore, dan file sensitif lain
SUDAH otomatis di-skip lewat `.gitignore` — jangan pernah commit file itu
ke repo publik.

### 2. Cek app berjalan tanpa install Flutter (via GitHub Actions)
Repo ini sudah menyertakan `.github/workflows/build_apk.yml` yang otomatis:
1. Build APK debug setiap kamu push ke branch `main`
2. Hasilnya bisa didownload di tab **Actions** di repo GitHub kamu → pilih
   run terakhir → scroll ke bawah ke bagian **Artifacts** → download
   `live-track-app-debug-apk` → extract → install `app-debug.apk` ke HP
   Android (perlu izin "install dari sumber tidak dikenal" di HP)

Ini APK **debug**, jadi cukup untuk cek app-nya jalan atau tidak (buka,
navigasi antar screen, dst), tapi belum konek ke Firebase asli kecuali
kamu isi secret `GOOGLE_SERVICES_JSON` di repo (Settings → Secrets and
variables → Actions → New repository secret → paste isi file
`google-services.json` kamu).

### 3. Cek app berjalan langsung di komputer (lebih lengkap, bisa lihat error real-time)
```bash
git clone https://github.com/USERNAME/live_track_app.git
cd live_track_app
flutter pub get
flutter run   # pastikan HP/emulator sudah terhubung
```
Ini butuh Flutter SDK terpasang (`flutter.dev/docs/get-started/install`)
dan `google-services.json` asli sudah ditaruh manual di
`android/app/google-services.json` (karena tidak ikut ke-push ke GitHub).

## Yang masih bisa dikembangkan lagi

- [ ] Widget iOS (perlu dibuat manual lewat Xcode, tidak bisa lewat kode saja)
- [ ] Rate limiting di endpoint `getEmergencySharedLocation` supaya tidak
      bisa di-spam request (disarankan pakai Firebase App Check atau
      Cloud Armor kalau mau produksi)
- [ ] Notifikasi ke pemilik akun setiap kali link emergency share-nya diakses
      (supaya tahu kapan link-nya benar-benar dibuka orang)

## Update — Icon App "MC" & Cara Pasang Sendiri ke HP (tanpa publish ke store)

### Icon App
Sudah dibuatkan icon dengan monogram "MC" (nuansa gradient dusk + aksen
titik amber, senada dengan identitas visual "Presence Pulse"), disimpan di
`assets/icon/icon.png`. Icon ini otomatis diterapkan ke Android & iOS lewat
package `flutter_launcher_icons` — tidak perlu ganti file manual satu-satu.
Kalau mau ganti icon, cukup timpa file `assets/icon/icon.png` (ukuran
1024x1024px), lalu jalankan ulang `dart run flutter_launcher_icons`.

### 📱 Android — cara paling gampang dapat APK siap pasang
1. Push kode ini ke GitHub (lihat bagian "Cara Upload ke GitHub" di atas).
2. Buka tab **Actions** di repo GitHub kamu, tunggu job **build-android**
   selesai (beberapa menit).
3. Download artifact **live-track-app-android-release** → extract →
   dapat file `app-release.apk`.
4. Kirim file itu ke HP Android kamu (kabel USB / Google Drive / email),
   aktifkan **"Izinkan instal dari sumber tidak dikenal"** di Setelan HP
   kamu (biasanya muncul otomatis saat pertama kali buka file APK), lalu
   tap file APK-nya untuk install. Selesai — muncul icon "MC" di layar
   utama HP kamu.

APK ini ditandatangani otomatis pakai debug key bawaan Flutter, jadi cukup
untuk pemakaian pribadi (tidak untuk di-upload ke Play Store — itu perlu
proses signing terpisah yang sengaja tidak kita urus di sini karena kamu
bilang tidak perlu dipublikasikan).

### 🍎 iOS — perlu dipahami dulu keterbatasannya
Apple **mewajibkan** setiap app yang berjalan di iPhone asli (bukan
simulator) ditandatangani pakai identitas Apple ID/Developer — ini aturan
dari Apple sendiri untuk semua app termasuk yang dipakai sendiri, tidak ada
cara sah untuk melewatinya (beda dengan Android yang bisa "install dari
sumber tidak dikenal" bebas).

Job **build-ios-unsigned** di GitHub Actions menghasilkan file `.ipa`
**tanpa tanda tangan** — ini belum bisa langsung diinstall, masih perlu
1 langkah lagi dari kamu:

**Opsi A — Sideloadly (gratis, paling praktis, bisa dari Windows)**
1. Download & install [Sideloadly](https://sideloadly.io/) di komputer
   (tersedia untuk Windows & Mac).
2. Colokkan iPhone ke komputer lewat kabel, buka Sideloadly.
3. Drag file `.ipa` hasil download dari GitHub Actions ke Sideloadly.
4. Masukkan Apple ID kamu (yang biasa dipakai App Store, gratis, tidak
   perlu akun Developer berbayar) saat diminta.
5. Klik Start — Sideloadly akan menandatangani & install app itu ke
   iPhone kamu otomatis.
6. Di iPhone: Settings → General → VPN & Device Management → percayai
   profil developer itu.
7. **Catatan**: dengan Apple ID gratis, app ini akan "expired" tiap 7 hari
   dan perlu diulang proses install lewat Sideloadly lagi. Kalau mau app
   ini permanen tanpa perlu diulang, perlu akun Apple Developer Program
   ($99/tahun) — dengan itu app bisa dipasang untuk 1 tahun penuh sekali
   proses.

**Opsi B — Xcode langsung (kalau kamu punya Mac)**
Lebih stabil dan tidak perlu tool pihak ketiga:
1. Buka `ios/Runner.xcworkspace` (bukan `.xcodeproj`) di Xcode.
2. Colokkan iPhone, pilih device kamu sebagai target.
3. Sign in dengan Apple ID kamu di Xcode (Xcode → Settings → Accounts).
4. Klik tombol Run (▶). Xcode akan build, sign, dan install langsung ke
   HP kamu. Sama seperti opsi A, dengan Apple ID gratis app akan expired
   tiap 7 hari kecuali pakai akun Developer berbayar.

Kalau kamu tidak punya Mac sama sekali dan tidak keberatan proses ulang
tiap minggu, Opsi A (Sideloadly di Windows) adalah jalan paling realistis
untuk pemakaian pribadi tanpa biaya.
