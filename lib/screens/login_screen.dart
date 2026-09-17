import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../theme/app_theme.dart';
import '../widgets/presence_pulse_avatar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  String? _verificationId;
  bool _loading = false;
  bool _codeSent = false;

  Future<void> _sendOtp() async {
    setState(() => _loading = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _phoneController.text.trim(),
      verificationCompleted: (credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        await _saveUserProfile();
      },
      verificationFailed: (e) {
        setState(() => _loading = false);
        _showError(e.message ?? 'Verifikasi gagal.');
      },
      codeSent: (verificationId, resendToken) {
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
          _loading = false;
        });
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> _verifyOtp() async {
    if (_verificationId == null) return;
    setState(() => _loading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      await _saveUserProfile();
    } catch (e) {
      _showError('Kode OTP salah.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final fcmToken = await FirebaseMessaging.instance.getToken();

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'name': _nameController.text.trim().isEmpty
          ? 'Pengguna'
          : _nameController.text.trim(),
      'phoneNumber': user.phoneNumber,
      'fcmToken': fcmToken ?? '',
    }, SetOptions(merge: true));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.duskGradient,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(),
                const SizedBox(height: 48),
                _codeSent ? _buildOtpStep() : _buildPhoneStep(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Hero pembuka: pulse besar sebagai thesis visual app ini - "kamu akan
  /// selalu merasakan detak kehadiran orang yang kamu sayang", bukan cuma
  /// judul app + logo generik.
  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PresencePulseAvatar(
          name: '',
          isLive: true,
          size: 64,
          pulseColor: AppColors.signalAmber,
        ),
        const SizedBox(height: 28),
        Text(
          'Selalu tahu\nkabarnya.',
          style: Theme.of(context).textTheme.displayLarge,
        ),
        const SizedBox(height: 12),
        Text(
          'Berbagi lokasi hidup dengan orang yang saling percaya. '
          'Privat, cuma untuk kalian berdua atau grup kecilmu.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      key: const ValueKey('phone-step'),
      children: [
        Text('Namamu', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: AppColors.cloud),
          decoration: const InputDecoration(hintText: 'Misal: Aya'),
        ),
        const SizedBox(height: 24),
        Text('Nomor HP', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: AppColors.cloud),
          decoration: const InputDecoration(hintText: '+62 812xxxxxxx'),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _sendOtp,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.midnight),
                  )
                : const Text('Kirim kode OTP'),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      key: const ValueKey('otp-step'),
      children: [
        Text('Kode verifikasi', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          'Kami kirim ke ${_phoneController.text.trim()}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          style: AppTheme.readout(size: 22, color: AppColors.cloud),
          decoration: const InputDecoration(hintText: '••••••'),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _verifyOtp,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.midnight),
                  )
                : const Text('Masuk'),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _codeSent = false),
            child: const Text('Ganti nomor', style: TextStyle(color: AppColors.cloudMuted)),
          ),
        ),
      ],
    );
  }
}
