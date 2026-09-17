import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../services/route_history_service.dart';
import '../models/route_history.dart';
import '../theme/app_theme.dart';

class RouteHistoryScreen extends StatefulWidget {
  final String groupId;
  final String uid;
  final String memberName;

  const RouteHistoryScreen({
    super.key,
    required this.groupId,
    required this.uid,
    required this.memberName,
  });

  @override
  State<RouteHistoryScreen> createState() => _RouteHistoryScreenState();
}

class _RouteHistoryScreenState extends State<RouteHistoryScreen> {
  final RouteHistoryService _service = RouteHistoryService();
  DateTime _selectedDate = DateTime.now();
  DailyRoute? _route;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    setState(() => _loading = true);
    final route = await _service.getRouteForDate(
      groupId: widget.groupId,
      uid: widget.uid,
      date: _selectedDate,
    );
    setState(() {
      _route = route;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rute ${widget.memberName}'),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _route == null || _route!.points.isEmpty
              ? _buildEmptyState()
              : _buildMapWithRoute(_route!),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'Belum ada riwayat rute untuk ${DateFormat('d MMM yyyy').format(_selectedDate)}',
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMapWithRoute(DailyRoute route) {
    final polylinePoints =
        route.points.map((p) => LatLng(p.latitude, p.longitude)).toList();

    return Column(
      children: [
        _buildStatsCard(route),
        Expanded(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: polylinePoints.first,
              zoom: 13,
            ),
            polylines: {
              Polyline(
                polylineId: const PolylineId('route'),
                points: polylinePoints,
                color: AppColors.signalAmber,
                width: 4,
              ),
            },
            markers: {
              Marker(
                markerId: const MarkerId('start'),
                position: polylinePoints.first,
                infoWindow: const InfoWindow(title: 'Mulai'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              ),
              Marker(
                markerId: const MarkerId('end'),
                position: polylinePoints.last,
                infoWindow: const InfoWindow(title: 'Terakhir'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              ),
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard(DailyRoute route) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Jarak', '${route.totalDistanceKm.toStringAsFixed(1)} km'),
          _statItem('Kec. Maks', '${route.maxSpeedKmh.toStringAsFixed(0)} km/j'),
          _statItem('Kec. Rata²', '${route.avgSpeedKmh.toStringAsFixed(0)} km/j'),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTheme.readout(size: 18, color: AppColors.mintPulse)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.cloudMuted)),
      ],
    );
  }
}
