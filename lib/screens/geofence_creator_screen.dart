import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/geofence_service.dart';
import '../theme/app_theme.dart';

class GeofenceCreatorScreen extends StatefulWidget {
  final String groupId;
  final String createdBy;
  final Map<String, String> memberNames;

  const GeofenceCreatorScreen({
    super.key,
    required this.groupId,
    required this.createdBy,
    required this.memberNames,
  });

  @override
  State<GeofenceCreatorScreen> createState() => _GeofenceCreatorScreenState();
}

class _GeofenceCreatorScreenState extends State<GeofenceCreatorScreen> {
  final GeofenceService _service = GeofenceService();
  final _nameController = TextEditingController();

  LatLng? _selectedPoint;
  double _radiusMeters = 150;
  String? _watchedUid;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Area Geofence')),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(-6.2, 106.8),
                zoom: 13,
              ),
              onTap: (point) => setState(() => _selectedPoint = point),
              markers: _selectedPoint == null
                  ? {}
                  : {
                      Marker(
                        markerId: const MarkerId('selected'),
                        position: _selectedPoint!,
                        draggable: true,
                        onDragEnd: (newPos) => setState(() => _selectedPoint = newPos),
                      ),
                    },
              circles: _selectedPoint == null
                  ? {}
                  : {
                      Circle(
                        circleId: const CircleId('radius'),
                        center: _selectedPoint!,
                        radius: _radiusMeters,
                        fillColor: AppColors.mintPulse.withValues(alpha: 0.18),
                        strokeColor: AppColors.mintPulse,
                        strokeWidth: 2,
                      ),
                    },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_selectedPoint == null)
                  const Text(
                    'Ketuk peta untuk memilih titik lokasi (mis. rumah/kantor)',
                    textAlign: TextAlign.center,
                  ),
                if (_selectedPoint != null) ...[
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama area (mis. "Rumah", "Kantor")',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Radius: ${_radiusMeters.toInt()} meter'),
                  Slider(
                    min: 50,
                    max: 1000,
                    divisions: 19,
                    value: _radiusMeters,
                    onChanged: (v) => setState(() => _radiusMeters = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Pantau siapa yang masuk/keluar area ini?',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.memberNames.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setState(() => _watchedUid = v),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const CircularProgressIndicator()
                        : const Text('Simpan Geofence'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_selectedPoint == null ||
        _nameController.text.trim().isEmpty ||
        _watchedUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi nama area dan pilih siapa yang dipantau.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.createGeofence(
        groupId: widget.groupId,
        name: _nameController.text.trim(),
        latitude: _selectedPoint!.latitude,
        longitude: _selectedPoint!.longitude,
        radiusMeters: _radiusMeters,
        createdBy: widget.createdBy,
        watchedUid: _watchedUid!,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
