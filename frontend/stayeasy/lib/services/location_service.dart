import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<LocationResult> determinePosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(
          error: 'Vui lòng bật GPS để xem các khách sạn gần bạn.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(
          error: 'Ứng dụng cần quyền truy cập vị trí để gợi ý khách sạn gần bạn.',
          permissionDenied: true,
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          error:
              'Bạn đã từ chối quyền vị trí vĩnh viễn. Vui lòng mở Cài đặt và cho phép StayEasy truy cập vị trí.',
          permissionDenied: true,
        );
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      return LocationResult(position: position);
    } catch (e) {
      return LocationResult(error: 'Không thể xác định vị trí: $e');
    }
  }

  double? distanceKm({
    required double? latitude,
    required double? longitude,
    required Position? from,
  }) {
    if (latitude == null || longitude == null || from == null) return null;
    final meters = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      latitude,
      longitude,
    );
    return meters / 1000;
  }
}

class LocationResult {
  final Position? position;
  final String? error;
  final bool permissionDenied;

  const LocationResult({
    this.position,
    this.error,
    this.permissionDenied = false,
  });
}
