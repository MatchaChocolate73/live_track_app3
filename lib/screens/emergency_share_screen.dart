import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/emergency_share_service.dart';
import '../theme/app_theme.dart';

/// Screen ini hanya bisa dibuka untuk membagikan lokasi PEMILIK AKUN
/// SENDIRI (ownUid == user yang sedang login). Tidak ada cara membuka
/// screen ini untuk "membagikan lokasi anggota grup lain" - lihat
/// pemanggilnya di live_map_screen.dart.
class EmergencyShareScreen extends StatefulWidget {
  final String groupId;
  final String ownUid;

  const EmergencyShareScreen({
    super.key,
    required this.groupId,
    required this.ownUid,
  });

  @override
  State<EmergencyShareScreen> createState() => _EmergencyShareScreenState();
}

class _EmergencyShareScreenState extends State<EmergencyShareScreen> {
  EmergencyShareResult? _activeShare;
  bool _loading = false;
  int _durationHours = 4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bagikan Lokasi Sementara')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: AppColors.duskSlateLight,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  '⚠️ Ini akan membuat link yang bisa dibuka SIAPA SAJA yang '
                  'memegang link-nya, untuk melihat lokasimu SAAT INI SAJA '
                  '(bukan riwayat, bukan data anggota grup lain). Link '
                  'otomatis mati sendiri dan bisa kamu cabut kapan saja.',
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_activeShare == null) ...[
              Text('Durasi aktif: $_durationHours jam'),
              Slider(
                min: 1,
                max: 24,
                divisions: 23,
                value: _durationHours.toDouble(),
                label: '$_durationHours jam',
                onChanged: (v) => setState(() => _durationHours = v.toInt()),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.share_location),
                label: const Text('Buat Link Share'),
                onPressed: _loading ? null : _createShare,
              ),
            ] else ...[
              _buildActiveShareCard(),
            ],
            if (_loading) const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveShareCard() {
    final share = _activeShare!;
    final remaining = share.expiresAt.difference(DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Link aktif:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SelectableText(share.token, style: AppTheme.readout(size: 14, color: AppColors.mintPulse)),
            const SizedBox(height: 8),
            Text('Otomatis mati dalam ${remaining.inHours} jam ${remaining.inMinutes % 60} menit'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Salin'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: share.token));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Token disalin')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cabut Sekarang'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.coralAlert,
                      foregroundColor: AppColors.midnight,
                    ),
                    onPressed: _loading ? null : _revokeShare,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createShare() async {
    setState(() => _loading = true);
    try {
      final result = await EmergencyShareService.createShare(
        durationHours: _durationHours,
      );
      setState(() => _activeShare = result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat link: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _revokeShare() async {
    if (_activeShare == null) return;
    setState(() => _loading = true);
    try {
      await EmergencyShareService.revokeShare(_activeShare!.token);
      setState(() => _activeShare = null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link berhasil dicabut, sudah tidak bisa diakses lagi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mencabut: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
