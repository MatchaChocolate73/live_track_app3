import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// ELEMEN SIGNATURE APP INI.
///
/// Avatar dengan cincin yang berdenyut pelan (seperti detak/radar) selagi
/// orangnya live. Begitu datanya basi (offline/last-seen lama), cincin
/// berhenti berdenyut dan memudar jadi outline statis abu-abu - encoding
/// visual yang jujur soal recency data, bukan cuma dekorasi.
class PresencePulseAvatar extends StatefulWidget {
  final String name;
  final String? photoUrl;
  final bool isLive;
  final double size;
  final Color pulseColor;

  const PresencePulseAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    required this.isLive,
    this.size = 56,
    this.pulseColor = AppColors.signalAmber,
  });

  @override
  State<PresencePulseAvatar> createState() => _PresencePulseAvatarState();
}

class _PresencePulseAvatarState extends State<PresencePulseAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.isLive) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant PresencePulseAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isLive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringBudget = widget.size * 0.5; // ruang ekstra untuk cincin denyut

    return SizedBox(
      width: widget.size + ringBudget,
      height: widget.size + ringBudget,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.isLive)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  size: Size(widget.size + ringBudget, widget.size + ringBudget),
                  painter: _PulsePainter(
                    progress: _controller.value,
                    color: widget.pulseColor,
                  ),
                );
              },
            ),
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.isLive ? widget.pulseColor : AppColors.cloudMuted,
                width: 2.5,
              ),
              color: AppColors.duskSlateLight,
              image: widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(widget.photoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                ? null
                : widget.name.isNotEmpty
                    ? Text(
                        widget.name[0].toUpperCase(),
                        style: AppTheme.readout(
                          size: widget.size * 0.36,
                          color: widget.isLive ? widget.pulseColor : AppColors.cloudMuted,
                        ),
                      )
                    : Container(
                        width: widget.size * 0.28,
                        height: widget.size * 0.28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isLive ? widget.pulseColor : AppColors.cloudMuted,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double progress; // 0..1, satu siklus denyut
  final Color color;

  _PulsePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Dua gelombang cincin bertahap, saling menyusul, biar terasa seperti
    // detak berkelanjutan, bukan satu ping tunggal yang terasa terputus.
    for (final offset in [0.0, 0.5]) {
      final t = (progress + offset) % 1.0;
      final radius = maxRadius * 0.55 + (maxRadius * 0.45 * t);
      final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.55;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
