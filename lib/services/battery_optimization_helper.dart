import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android sering mematikan background service demi hemat batre
/// (terutama merk Xiaomi/Oppo/Vivo yang agresif soal ini). Ini bikin
/// live tracking "kelihatan mati" walau app tidak di-uninstall/force-stop.
///
/// Helper ini meminta user menambahkan app ke daftar "unrestricted battery
/// usage" secara eksplisit, dengan penjelasan alasannya - bukan diam-diam.
class BatteryOptimizationHelper {
  /// Panggil ini sekali setelah user pertama kali join/buat grup, dengan
  /// dialog penjelasan dulu (jangan langsung minta permission tanpa context).
  static Future<void> promptIfNeeded(BuildContext context) async {
    if (!Platform.isAndroid) return; // iOS tidak punya konsep ini

    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) return;

    if (!context.mounted) return;
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supaya Tracking Tidak Berhenti Sendiri'),
        content: const Text(
          'Beberapa merk HP Android mematikan aplikasi di background demi '
          'hemat batre, yang bisa membuat lokasimu berhenti update tanpa '
          'kamu sadari. Izinkan aplikasi ini berjalan tanpa dibatasi supaya '
          'live tracking tetap akurat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nanti Saja'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Atur Sekarang'),
          ),
        ],
      ),
    );

    if (shouldProceed == true) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }
}
