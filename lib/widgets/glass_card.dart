import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Kartu semi-transparan dengan efek blur - dipakai untuk elemen yang
/// mengambang di atas peta (bottom sheet anggota, app bar), supaya peta
/// di baliknya tetap "hadir" tapi kontennya tetap terbaca jelas.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(28)),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.duskSlate.withValues(alpha: 0.82),
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
