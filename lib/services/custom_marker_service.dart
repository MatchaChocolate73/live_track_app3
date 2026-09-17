import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Membuat marker icon custom berbentuk foto profil bulat dengan border,
/// supaya lebih mudah dikenali di peta dibanding pin default yang seragam.
class CustomMarkerService {
  static final Map<String, BitmapDescriptor> _cache = {};

  /// [photoUrl] boleh null -> fallback ke avatar inisial nama dengan warna
  /// acak berbasis uid, supaya tetap konsisten tiap render tanpa perlu foto.
  static Future<BitmapDescriptor> buildMarker({
    required String uid,
    required String name,
    String? photoUrl,
    double size = 120,
  }) async {
    final cacheKey = '$uid-$photoUrl';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final ui.Image image = photoUrl != null && photoUrl.isNotEmpty
        ? await _loadNetworkImage(photoUrl, size)
        : await _buildInitialAvatar(uid, name, size);

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.bytes(byteData!.buffer.asUint8List());

    _cache[cacheKey] = descriptor;
    return descriptor;
  }

  static Future<ui.Image> _loadNetworkImage(String url, double size) async {
    try {
      final response = await http.get(Uri.parse(url));
      final bytes = response.bodyBytes;
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: size.toInt());
      final frame = await codec.getNextFrame();
      return _drawCircularBorder(frame.image, size);
    } catch (_) {
      // Kalau foto gagal dimuat (link rusak/tidak ada internet), tetap
      // tampilkan sesuatu yang wajar daripada marker kosong/error.
      return _buildInitialAvatar(url, '?', size);
    }
  }

  static Future<ui.Image> _buildInitialAvatar(String seed, String name, double size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final radius = size / 2;

    final colors = [
      Colors.indigo, Colors.teal, Colors.deepOrange,
      Colors.purple, Colors.blue, Colors.green,
    ];
    final color = colors[seed.hashCode % colors.length];

    canvas.drawCircle(Offset(radius, radius), radius, Paint()..color = color);
    canvas.drawCircle(
      Offset(radius, radius),
      radius - 3,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final textPainter = TextPainter(
      text: TextSpan(
        text: initial,
        style: TextStyle(color: Colors.white, fontSize: size * 0.4, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(radius - textPainter.width / 2, radius - textPainter.height / 2),
    );

    final picture = recorder.endRecording();
    return picture.toImage(size.toInt(), size.toInt());
  }

  static Future<ui.Image> _drawCircularBorder(ui.Image src, double size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final radius = size / 2;

    final path = Path()..addOval(Rect.fromCircle(center: Offset(radius, radius), radius: radius - 3));
    canvas.clipPath(path);
    canvas.drawImageRect(
      src,
      Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      Rect.fromLTWH(0, 0, size, size),
      Paint(),
    );

    canvas.drawCircle(
      Offset(radius, radius),
      radius - 3,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final picture = recorder.endRecording();
    return picture.toImage(size.toInt(), size.toInt());
  }

  static void clearCache() => _cache.clear();
}
