import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Toggle "Membagikan / Tidak" berbentuk pill dengan titik berdenyut saat
/// aktif - dipakai di app bar peta live. Sengaja dibuat besar & jelas
/// (bukan Switch kecil di pojok) karena ini status paling penting yang
/// harus selalu bisa dilihat sekilas.
class SharingPillToggle extends StatelessWidget {
  final bool isSharing;
  final ValueChanged<bool> onChanged;

  const SharingPillToggle({
    super.key,
    required this.isSharing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!isSharing),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSharing
              ? AppColors.signalAmber.withValues(alpha: 0.16)
              : AppColors.duskSlateLight,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSharing ? AppColors.signalAmber : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSharing ? AppColors.signalAmber : AppColors.cloudMuted,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isSharing ? 'Membagikan' : 'Tidak membagikan',
              style: AppTheme.readout(
                size: 12,
                weight: FontWeight.w700,
                color: isSharing ? AppColors.signalAmber : AppColors.cloudMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
