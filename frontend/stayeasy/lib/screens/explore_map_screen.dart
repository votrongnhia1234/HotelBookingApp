import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../models/hotel.dart';
import '../services/hotel_service.dart';
import '../services/location_service.dart';

class ExploreMapScreen extends StatefulWidget {
  const ExploreMapScreen({super.key});

  @override
  State<ExploreMapScreen> createState() => _ExploreMapScreenState();
}

class _ExploreMapScreenState extends State<ExploreMapScreen> {
  final _hotelService = HotelService();
  final _locationService = LocationService();
  late Future<List<Hotel>> _hotelsFuture;
  GoogleMapController? _mapController;
  Position? _currentPosition;
  String? _locationError;
  bool _requestingLocation = false;

  double _minRating = 0;
  double? _maxDistanceKm;

  static const LatLng _fallbackCenter = LatLng(21.028511, 105.804817); // Hà Nội
  static const double _fallbackZoom = 12.0;

  @override
  void initState() {
    super.initState();
    _hotelsFuture = _hotelService.fetchHotels();
    _loadLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    setState(() {
      _requestingLocation = true;
      _locationError = null;
    });
    final result = await _locationService.determinePosition();
    if (!mounted) return;
    setState(() {
      _requestingLocation = false;
      _currentPosition = result.position;
      _locationError = result.error;
    });
  }

  Future<void> _openFilters() async {
    double tempRating = _minRating;
    double? tempDistance = _maxDistanceKm;
    final hasLocation = _currentPosition != null;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Bộ lọc',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempRating = 0;
                            tempDistance = null;
                          });
                        },
                        child: const Text('Xóa lọc'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Đánh giá tối thiểu'),
                  Slider(
                    value: tempRating,
                    min: 0,
                    max: 5,
                    divisions: 10,
                    label: tempRating.toStringAsFixed(1),
                    onChanged: (value) =>
                        setModalState(() => tempRating = value),
                  ),
                  if (hasLocation) ...[
                    const SizedBox(height: 12),
                    const Text('Khoảng cách tối đa (km)'),
                    Slider(
                      value: (tempDistance ?? 50).clamp(0, 50),
                      min: 1,
                      max: 50,
                      divisions: 49,
                      label: tempDistance == null
                          ? 'Không giới hạn'
                          : tempDistance!.toStringAsFixed(0),
                      onChanged: (value) =>
                          setModalState(() => tempDistance = value),
                      onChangeEnd: (value) =>
                          setModalState(() => tempDistance = value),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () =>
                              setModalState(() => tempDistance = null),
                          child: const Text('Bỏ giới hạn'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pop<Map<String, dynamic>>(context, {
                            'rating': tempRating,
                            'distance': hasLocation ? tempDistance : null,
                          }),
                      child: const Text('Áp dụng'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null) return;
    setState(() {
      _minRating = result['rating'] as double? ?? 0;
      _maxDistanceKm = result['distance'] as double?;
    });
  }

  Set<Marker> _markersFor(List<Hotel> hotels) {
    final markers = <Marker>{};
    for (final h in hotels) {
      if (h.latitude == null || h.longitude == null) continue;
      if (_minRating > 0 && h.rating < _minRating) continue;
      if (_maxDistanceKm != null && _currentPosition != null) {
        final d = _locationService.distanceKm(
          latitude: h.latitude,
          longitude: h.longitude,
          from: _currentPosition,
        );
        if (d == null || d > _maxDistanceKm!) continue;
      }
      markers.add(
        Marker(
          markerId: MarkerId('hotel-${h.id}'),
          position: LatLng(h.latitude!, h.longitude!),
          infoWindow: InfoWindow(
            title: h.name,
            snippet:
                '${h.city} • ⭐ ${h.rating.toStringAsFixed(1)}' +
                (h.minPrice != null
                    ? ' • giá từ ${h.minPrice!.toStringAsFixed(0)}đ'
                    : ''),
            onTap: () => Navigator.pushNamed(context, '/hotel', arguments: h),
          ),
        ),
      );
    }
    return markers;
  }

  CameraPosition _initialCamera() {
    if (_currentPosition != null) {
      return CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 13,
      );
    }
    return const CameraPosition(target: _fallbackCenter, zoom: _fallbackZoom);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Khám phá trên bản đồ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Bộ lọc',
            onPressed: _openFilters,
          ),
        ],
      ),
      body: FutureBuilder<List<Hotel>>(
        future: _hotelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Không thể tải dữ liệu.'),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => setState(
                      () => _hotelsFuture = _hotelService.fetchHotels(),
                    ),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          final hotels = snapshot.data ?? [];

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: _initialCamera(),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                compassEnabled: true,
                zoomControlsEnabled: false,
                markers: _markersFor(hotels),
                onMapCreated: (c) => _mapController = c,
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (_minRating > 0)
                      Chip(
                        label: Text(
                          'Đánh giá từ ${_minRating.toStringAsFixed(1)}',
                        ),
                        onDeleted: () => setState(() => _minRating = 0),
                      ),
                    if (_maxDistanceKm != null)
                      Chip(
                        label: Text(
                          '≤ ${_maxDistanceKm!.toStringAsFixed(0)} km',
                        ),
                        onDeleted: () => setState(() => _maxDistanceKm = null),
                      ),
                    if (_locationError != null)
                      Chip(
                        avatar: const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 16,
                        ),
                        label: Text(_locationError!),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _loadLocation();
          if (_currentPosition != null && _mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLng(
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              ),
            );
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
