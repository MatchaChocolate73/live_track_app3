import 'package:home_widget/home_widget.dart';

/// Menyediakan data ringkas ke home screen widget (Android App Widget /
/// iOS WidgetKit), supaya user bisa lihat posisi terakhir anggota grup
/// tanpa buka aplikasi.
///
/// CATATAN PRIVASI: widget hanya menampilkan data anggota grup yang SAH
/// (sudah lewat proses invite/accept), sama seperti di dalam app. Tidak
/// ada data tambahan yang dibocorkan ke widget dibanding yang sudah
/// terlihat di layar utama.
///
/// CATATAN TEKNIS: package `home_widget` menjembatani Flutter dengan kode
/// native (Kotlin untuk Android App Widget, Swift untuk iOS WidgetKit).
/// Bagian native (layout widget, class Provider Android, Widget iOS)
/// TIDAK bisa ditulis penuh lewat Dart saja - perlu dikerjakan langsung
/// di Android Studio / Xcode. Langkah setupnya ada di README bagian
/// "Setup Home Screen Widget".
class HomeWidgetService {
  static const String _androidWidgetName = 'LiveTrackWidgetProvider';
  static const String _iosWidgetName = 'LiveTrackWidget';

  /// Panggil setiap ada update posisi baru dari anggota yang paling ingin
  /// dipantau (misal pasangan), supaya widget selalu menampilkan data
  /// terbaru begitu dibuka.
  static Future<void> updateWidgetData({
    required String memberName,
    required double speedKmh,
    required String statusLabel,
    required DateTime lastUpdate,
  }) async {
    await HomeWidget.saveWidgetData<String>('member_name', memberName);
    await HomeWidget.saveWidgetData<double>('speed_kmh', speedKmh);
    await HomeWidget.saveWidgetData<String>('status_label', statusLabel);
    await HomeWidget.saveWidgetData<String>(
      'last_update',
      lastUpdate.toIso8601String(),
    );

    await HomeWidget.updateWidget(
      androidName: _androidWidgetName,
      iOSName: _iosWidgetName,
    );
  }

  /// Bersihkan data widget saat user keluar dari grup/logout, supaya
  /// tidak ada data lama yang nyangkut di widget tanpa sepengetahuan user.
  static Future<void> clearWidgetData() async {
    await HomeWidget.saveWidgetData<String>('member_name', '');
    await HomeWidget.saveWidgetData<double>('speed_kmh', 0);
    await HomeWidget.saveWidgetData<String>('status_label', 'Tidak ada data');
    await HomeWidget.updateWidget(
      androidName: _androidWidgetName,
      iOSName: _iosWidgetName,
    );
  }
}
