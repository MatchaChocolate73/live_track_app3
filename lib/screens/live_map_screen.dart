import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../services/group_locations_provider.dart';
import '../models/live_location.dart';
import '../services/ring_trigger_helper.dart';
import 'route_history_screen.dart';
import '../services/custom_marker_service.dart';
import 'geofence_creator_screen.dart';
import 'emergency_share_screen.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/presence_pulse_avatar.dart';
import '../widgets/glass_card.dart';
import '../widgets/sharing_pill_toggle.dart';

class LiveMapScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String currentUid;
  final Map<String, String> memberNames; // uid -> nama tampilan
  final Map<String, String?> memberPhotoUrls; // uid -> url foto profil (boleh null)

  const LiveMapScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.currentUid,
    required this.memberNames,
    this.memberPhotoUrls = const {},
  });

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  GoogleMapController? _mapController;
  final Map<String, BitmapDescriptor> _markerIcons = {};
  LocationService? _locationService;
  bool _isSharingMyLocation = false;
  late GroupLocationsProvider _locationsProvider;

  @override
  void initState() {
    super.initState();
    _locationService = LocationService(
      currentUid: widget.currentUid,
      groupId: widget.groupId,
    );
    _locationsProvider = GroupLocationsProvider(groupId: widget.groupId);
  }

  @override
  void dispose() {
    // Catatan: sengaja TIDAK auto-stop tracking saat screen ini ditutup,
    // supaya sharing tetap jalan di background sesuai ekspektasi user
    // (mereka mematikan lewat toggle pill, bukan dengan pindah screen).
    _locationsProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GroupLocationsProvider>.value(
      value: _locationsProvider,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: AppColors.midnight,
        appBar: _buildFloatingAppBar(),
        body: Consumer<GroupLocationsProvider>(
          builder: (context, provider, _) {
            _ensureMarkerIcons(provider);
            final markers = _buildMarkers(provider);

            return Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(-6.2, 106.8), // default Jakarta, ganti sesuai lokasi user
                    zoom: 12,
                  ),
                  markers: markers,
                  onMapCreated: (controller) => _mapController = controller,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
                // Nuansa "dusk" dituangkan lewat gradient tipis di atas peta
                // supaya map tetap fungsional tapi warnanya senada dengan
                // identitas app, bukan biru-hijau default Google Maps mentah.
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.midnight.withValues(alpha: 0.55),
                          Colors.transparent,
                          Colors.transparent,
                          AppColors.midnight.withValues(alpha: 0.4),
                        ],
                        stops: const [0, 0.2, 0.6, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildMemberSheet(provider),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildFloatingAppBar() {
    return AppBar(
      title: Text(widget.groupName, style: Theme.of(context).textTheme.titleLarge),
      actions: [
        SharingPillToggle(isSharing: _isSharingMyLocation, onChanged: _toggleSharing),
        const SizedBox(width: 8),
        _iconPill(Icons.add_location_alt_rounded, 'Buat area geofence', _openGeofenceCreator),
        _iconPill(Icons.ios_share_rounded, 'Bagikan lokasi sementara', _openEmergencyShare),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _iconPill(IconData icon, String tooltip, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.duskSlate.withValues(alpha: 0.85),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: AppColors.cloud),
          ),
        ),
      ),
    );
  }

  /// Bangun icon marker foto profil secara async di background, lalu
  /// panggil setState begitu siap. Dipisah dari _buildMarkers (yang harus
  /// sync) supaya tidak nge-block render peta menunggu foto ter-download.
  void _ensureMarkerIcons(GroupLocationsProvider provider) {
    for (final uid in provider.liveLocations.keys) {
      if (_markerIcons.containsKey(uid)) continue;
      final name = widget.memberNames[uid] ?? 'Anggota';
      final photoUrl = widget.memberPhotoUrls[uid];

      CustomMarkerService.buildMarker(uid: uid, name: name, photoUrl: photoUrl)
          .then((icon) {
        if (!mounted) return;
        setState(() => _markerIcons[uid] = icon);
      });
    }
  }

  Set<Marker> _buildMarkers(GroupLocationsProvider provider) {
    return provider.liveLocations.entries.map((entry) {
      final uid = entry.key;
      final loc = entry.value;
      final name = widget.memberNames[uid] ?? 'Anggota';

      return Marker(
        markerId: MarkerId(uid),
        position: LatLng(loc.latitude, loc.longitude),
        rotation: loc.heading,
        icon: _markerIcons[uid] ?? BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(
          title: name,
          snippet: '${loc.speedKmh.toStringAsFixed(0)} km/j • ${provider.statusLabelFor(uid)}',
        ),
      );
    }).toSet();
  }

  /// Bottom sheet kaca berisi daftar anggota - signature element (avatar
  /// berdenyut) tampil paling jelas di sini, jadi fokus utama layar bukan
  /// cuma peta kosong dengan titik-titik, tapi "siapa lagi hidup sekarang".
  Widget _buildMemberSheet(GroupLocationsProvider provider) {
    final entries = provider.liveLocations.entries.toList();

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.duskSlateLight,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          if (entries.isEmpty)
            _buildEmptyState()
          else
            ...entries.map((entry) => _buildMemberRow(provider, entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const PresencePulseAvatar(name: '', isLive: false, size: 44),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Belum ada yang live', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Nyalakan toggle di pojok kanan atas untuk mulai membagikan lokasimu.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberRow(GroupLocationsProvider provider, String uid, LiveLocation loc) {
    final name = widget.memberNames[uid] ?? 'Anggota';
    final photoUrl = widget.memberPhotoUrls[uid];
    final isLive = !loc.isFromSmsFallback && loc.age.inSeconds < 60;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(LatLng(loc.latitude, loc.longitude)),
          );
        },
        onLongPress: () => _openRouteHistory(uid, name),
        child: Row(
          children: [
            PresencePulseAvatar(name: name, photoUrl: photoUrl, isLive: isLive, size: 48),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    provider.statusLabelFor(uid),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            // Kecepatan ditampilkan seperti readout alat ukur - angka mono
            // besar, bukan teks biasa, biar terasa "hidup & terukur".
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  loc.speedKmh.toStringAsFixed(0),
                  style: AppTheme.readout(
                    size: 22,
                    color: isLive ? AppColors.mintPulse : AppColors.cloudMuted,
                  ),
                ),
                Text('km/j', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10)),
              ],
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _onRingPressed(uid, name),
              borderRadius: BorderRadius.circular(100),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.duskSlateLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.volume_up_rounded, size: 18, color: AppColors.cloud),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleSharing(bool enable) async {
    if (enable) {
      try {
        await _locationService!.startTracking(groupName: widget.groupName);
        setState(() => _isSharingMyLocation = true);
      } catch (e) {
        if (!mounted) return;
        _showSnack('Gagal mengaktifkan: $e', isError: true);
      }
    } else {
      await _locationService!.stopTracking();
      setState(() => _isSharingMyLocation = false);
      if (!mounted) return;
      _showSnack('Lokasimu berhenti dibagikan ke grup ini.');
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.coralAlert : AppColors.duskSlateLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _openGeofenceCreator() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GeofenceCreatorScreen(
          groupId: widget.groupId,
          createdBy: widget.currentUid,
          memberNames: widget.memberNames,
        ),
      ),
    );
  }

  /// PENTING: emergency share HANYA bisa dibuka untuk currentUid sendiri.
  /// Tidak ada opsi "bagikan lokasi si X" dari sini - orang lain di grup
  /// tidak bisa membuat link share atas nama anggota lain. Ini mencegah
  /// satu anggota membocorkan lokasi anggota lain tanpa izin mereka.
  void _openEmergencyShare() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmergencyShareScreen(
          groupId: widget.groupId,
          ownUid: widget.currentUid,
        ),
      ),
    );
  }

  void _openRouteHistory(String uid, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteHistoryScreen(
          groupId: widget.groupId,
          uid: uid,
          memberName: name,
        ),
      ),
    );
  }

  Future<void> _onRingPressed(String targetUid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.duskSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bunyikan HP $name?', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Dia akan dapat notifikasi + getar/suara untuk membantu menemukan HP-nya.',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Kirim'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await RingTriggerHelper.ringPhone(groupId: widget.groupId, targetUid: targetUid);
      if (!mounted) return;
      _showSnack('Sinyal bunyi terkirim ke $name');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal kirim sinyal: $e', isError: true);
    }
  }
}
