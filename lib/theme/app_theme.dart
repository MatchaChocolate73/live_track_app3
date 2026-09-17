import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ============================================================
/// DESAIN VISUAL: "Presence Pulse"
/// ============================================================
/// Ide dasar: app ini bukan dashboard logistik, tapi cara tetap merasa
/// dekat dengan orang yang disayang meski beda tempat. Jadi identitas
/// visualnya dibangun dari metafora "detak kehadiran" - tiap orang yang
/// live punya cincin yang berdenyut pelan di avatarnya, seperti radar
/// atau detak jantung yang menenangkan, bukan sekadar titik statis di peta.
///
/// Palet: "dusk" (senja) - indigo gelap yang hangat, bukan biru korporat
/// dingin. Amber untuk sinyal "hidup/live", mint untuk "aman/geofence",
/// koral untuk urgensi (emergency/ring). Sengaja menghindari kombinasi
/// klise (cream + terracotta, atau near-black + satu aksen neon).
///
/// Tipografi: Fraunces (serif berkarakter, hangat) untuk judul/nama orang/
/// angka besar, dipasangkan dengan Manrope (sans geometris bersih) untuk
/// body & label, dan Space Mono untuk angka "readout" (kecepatan,
/// timestamp) - kesan seperti alat baca detak/telemetri, bukan teks biasa.
class AppColors {
  AppColors._();

  // Latar & permukaan
  static const Color midnight = Color(0xFF14152B); // background utama
  static const Color duskSlate = Color(0xFF23244A); // permukaan card, sedikit lebih terang
  static const Color duskSlateLight = Color(0xFF2F3060); // hover/pressed state

  // Teks & konten di atas dasar gelap
  static const Color cloud = Color(0xFFF6F1E7); // teks utama, cream hangat
  static const Color cloudMuted = Color(0xFFACA9C7); // teks sekunder

  // Aksen
  static const Color signalAmber = Color(0xFFFFB648); // "live", CTA utama
  static const Color mintPulse = Color(0xFF5EEAD4); // "aman", geofence, sukses
  static const Color coralAlert = Color(0xFFFF6B6B); // emergency, ring, hapus

  // Gradient senja untuk hero/background
  static const List<Color> duskGradient = [
    Color(0xFF14152B),
    Color(0xFF1E1F42),
    Color(0xFF2A2456),
  ];
}

class AppTheme {
  AppTheme._();

  static TextTheme get _textTheme {
    final base = ThemeData.dark().textTheme;
    return base
        .copyWith(
          displayLarge: GoogleFonts.fraunces(
            fontSize: 40,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            color: AppColors.cloud,
            height: 1.1,
          ),
          headlineMedium: GoogleFonts.fraunces(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: AppColors.cloud,
            height: 1.2,
          ),
          titleLarge: GoogleFonts.fraunces(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.cloud,
          ),
          titleMedium: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.cloud,
          ),
          bodyLarge: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.cloud,
          ),
          bodyMedium: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.cloudMuted,
          ),
          labelLarge: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.midnight,
          ),
        )
        .apply(bodyColor: AppColors.cloud, displayColor: AppColors.cloud);
  }

  /// Font "readout" khusus untuk angka kecepatan/timestamp - kesan alat
  /// baca telemetri langsung, bukan teks biasa. Dipakai manual lewat
  /// AppTheme.readout(...) di tempat yang butuh, bukan lewat TextTheme.
  static TextStyle readout({double size = 28, Color? color, FontWeight? weight}) {
    return GoogleFonts.spaceMono(
      fontSize: size,
      fontWeight: weight ?? FontWeight.bold,
      color: color ?? AppColors.cloud,
      letterSpacing: -0.5,
    );
  }

  static ThemeData get theme {
    final textTheme = _textTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.midnight,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.signalAmber,
        onPrimary: AppColors.midnight,
        secondary: AppColors.mintPulse,
        onSecondary: AppColors.midnight,
        error: AppColors.coralAlert,
        surface: AppColors.duskSlate,
        onSurface: AppColors.cloud,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: AppColors.cloud),
      ),
      cardTheme: CardThemeData(
        color: AppColors.duskSlate,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.signalAmber,
          foregroundColor: AppColors.midnight,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.cloud,
          side: const BorderSide(color: AppColors.duskSlateLight, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          textStyle: textTheme.labelLarge?.copyWith(color: AppColors.cloud),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.duskSlate,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.signalAmber, width: 1.5),
        ),
        hintStyle: textTheme.bodyMedium,
        labelStyle: textTheme.bodyMedium,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.duskSlateLight, thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.signalAmber
              : AppColors.cloudMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.signalAmber.withValues(alpha: 0.3)
              : AppColors.duskSlateLight,
        ),
      ),
    );
  }
}
