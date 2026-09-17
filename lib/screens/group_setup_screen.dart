import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/group_service.dart';
import '../services/battery_optimization_helper.dart';
import '../theme/app_theme.dart';
import 'live_map_screen.dart';

class GroupSetupScreen extends StatefulWidget {
  const GroupSetupScreen({super.key});

  @override
  State<GroupSetupScreen> createState() => _GroupSetupScreenState();
}

class _GroupSetupScreenState extends State<GroupSetupScreen> {
  final GroupService _groupService = GroupService();
  bool _loading = false;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Future<void> _createGroup(String groupName) async {
    setState(() => _loading = true);
    try {
      final group = await _groupService.createGroup(
        ownerUid: _uid,
        groupName: groupName,
      );
      if (!mounted) return;
      await _showInviteCodeDialog(group.inviteCode);
      if (!mounted) return;

      await BatteryOptimizationHelper.promptIfNeeded(context);
      if (!mounted) return;

      _goToMap(groupId: group.groupId, groupName: group.name);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinGroup(String code) async {
    if (code.length != 6) {
      _showError('Kode undangan harus 6 digit.');
      return;
    }
    setState(() => _loading = true);
    try {
      final group = await _groupService.joinGroupWithCode(uid: _uid, inviteCode: code);
      if (!mounted || group == null) return;

      await BatteryOptimizationHelper.promptIfNeeded(context);
      if (!mounted) return;

      _goToMap(groupId: group.groupId, groupName: group.name);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToMap({required String groupId, required String groupName}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveMapScreen(
          groupId: groupId,
          groupName: groupName,
          currentUid: _uid,
          memberNames: {_uid: 'Kamu'},
        ),
      ),
    );
  }

  Future<void> _showInviteCodeDialog(String code) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.duskSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.signalAmber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.mail_outline_rounded, color: AppColors.signalAmber),
              ),
              const SizedBox(height: 20),
              Text('Kode undanganmu', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Kirim ini langsung ke orangnya. Berlaku 10 menit, sekali pakai.',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: AppColors.midnight,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  code,
                  style: AppTheme.readout(size: 34, color: AppColors.signalAmber),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Siap'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.coralAlert,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _openCreateSheet() {
    final controller = TextEditingController();
    _showActionSheet(
      icon: Icons.add_circle_outline_rounded,
      title: 'Lingkaran baru',
      subtitle: 'Beri nama supaya gampang dikenali, misal "Aku & Dia" atau "Keluarga".',
      fieldHint: 'Nama lingkaran',
      controller: controller,
      buttonLabel: 'Buat & dapatkan kode',
      onSubmit: () => _createGroup(controller.text.trim()),
    );
  }

  void _openJoinSheet() {
    final controller = TextEditingController();
    _showActionSheet(
      icon: Icons.link_rounded,
      title: 'Gabung lingkaran',
      subtitle: 'Masukkan 6 digit kode yang dikirim orang yang mengundangmu.',
      fieldHint: '000000',
      controller: controller,
      buttonLabel: 'Gabung',
      keyboardType: TextInputType.number,
      maxLength: 6,
      readout: true,
      onSubmit: () => _joinGroup(controller.text.trim()),
    );
  }

  void _showActionSheet({
    required IconData icon,
    required String title,
    required String subtitle,
    required String fieldHint,
    required TextEditingController controller,
    required String buttonLabel,
    required VoidCallback onSubmit,
    TextInputType? keyboardType,
    int? maxLength,
    bool readout = false,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          decoration: const BoxDecoration(
            color: AppColors.duskSlate,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.duskSlateLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Icon(icon, color: AppColors.signalAmber, size: 28),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(subtitle, style: Theme.of(ctx).textTheme.bodyMedium),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: keyboardType,
                maxLength: maxLength,
                style: readout
                    ? AppTheme.readout(size: 22, color: AppColors.cloud)
                    : const TextStyle(color: AppColors.cloud),
                decoration: InputDecoration(hintText: fieldHint, counterText: ''),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          onSubmit();
                        },
                  child: Text(buttonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.duskGradient,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lingkaranmu', style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: 8),
                Text(
                  'Ruang privat untuk kalian yang saling percaya.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
                _buildActionCard(
                  icon: Icons.favorite_rounded,
                  iconColor: AppColors.signalAmber,
                  title: 'Mulai lingkaran baru',
                  subtitle: 'Undang pasangan atau orang terdekatmu lewat kode.',
                  onTap: _loading ? null : _openCreateSheet,
                  featured: true,
                ),
                const SizedBox(height: 16),
                _buildActionCard(
                  icon: Icons.qr_code_rounded,
                  iconColor: AppColors.mintPulse,
                  title: 'Punya kode undangan?',
                  subtitle: 'Gabung ke lingkaran yang sudah dibuat orang lain.',
                  onTap: _loading ? null : _openJoinSheet,
                  featured: false,
                ),
                const Spacer(),
                if (_loading)
                  const Center(child: CircularProgressIndicator(color: AppColors.signalAmber)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required bool featured,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: featured ? AppColors.duskSlateLight : AppColors.duskSlate,
          borderRadius: BorderRadius.circular(24),
          border: featured
              ? Border.all(color: AppColors.signalAmber.withValues(alpha: 0.35))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.cloudMuted),
          ],
        ),
      ),
    );
  }
}
