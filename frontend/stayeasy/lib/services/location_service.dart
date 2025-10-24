import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<LocationResult> determinePosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(
          error: 'Vui lòng bật dịch vụ vị trí/GPS.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(
          error: 'Quyền vị trí bị từ chối. Hãy cấp quyền và thử lại.',
          permissionDenied: true,
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          error:
              'Quyền vị trí bị từ chối vĩnh viễn. Vui lòng mở Cài đặt và cho phép StayEasy truy cập vị trí.',
          permissionDenied: true,
        );
      }

      // Ưu tiên vị trí hiện tại với timeout, sau đó fallback về vị trí gần nhất đã biết.
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        ).timeout(const Duration(seconds: 10));
        return LocationResult(position: position);
      } on TimeoutException {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return LocationResult(position: lastKnown);
        }
        return const LocationResult(
          error: 'Mất quá nhiều thời gian khi truy vấn vị trí thiết bị.',
        );
      }
    } catch (e) {
      final msg = e.toString();
      // Làm thông báo thân thiện hơn cho lỗi dịch vụ mạng trên web.
      if (msg.contains('Failed to query location')) {
        return const LocationResult(
          error:
              'Không thể truy vấn vị trí từ dịch vụ mạng của trình duyệt. Hãy cấp quyền vị trí cho trang (biểu tượng khoá → Quyền → Vị trí) và thử lại.',
        );
      }
      return LocationResult(error: 'Không thể xác định vị trí: $msg');
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
