import '../config/api_constants.dart';
import '../models/room.dart';
import '../utils/api_data_parser.dart';
import 'api_service.dart';

class RoomService {
  final ApiService _api = ApiService();

  Future<List<Room>> listByHotel(int hotelId) async {
    final raw = await _api.get(ApiConstants.roomsByHotel(hotelId));
    return ApiDataParser.list(raw)
        .map((e) => Room.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> createRoom({
    required int hotelId,
    required String roomNumber,
    required String type,
    required num pricePerNight,
    String status = 'available',
  }) async {
    await _api.post(ApiConstants.rooms, {
      'hotel_id': hotelId,
      'room_number': roomNumber,
      'type': type,
      'price_per_night': pricePerNight,
      'status': status,
    });
  }

  Future<void> updateStatus({
    required int roomId,
    required String status,
  }) async {
    await _api.patch(ApiConstants.roomStatus(roomId), {'status': status});
  }

  Future<void> addImage({
    required int roomId,
    required String imageUrl,
  }) async {
    await _api.post(ApiConstants.roomImages, {
      'room_id': roomId,
      'image_url': imageUrl,
    });
  }
}
