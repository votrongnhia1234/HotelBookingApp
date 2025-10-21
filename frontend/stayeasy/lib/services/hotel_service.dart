import '../config/api_constants.dart';
import '../models/attraction_photo.dart';
import '../models/hotel.dart';
import '../models/room.dart';
import 'api_service.dart';
import '../utils/api_data_parser.dart';

class HotelService {
  final _api = ApiService();

  Future<List<Hotel>> fetchHotels() async {
    final raw = await _api.get(ApiConstants.hotels);
    return ApiDataParser.list(raw)
        .map((e) => Hotel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Room>> fetchRoomsByHotel(int hotelId) async {
    final raw = await _api.get(ApiConstants.roomsByHotel(hotelId)); // /api/rooms/hotel/:id
    final list = ApiDataParser.list(raw)
        .map((e) => Room.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    // ignore: avoid_print
    print('Rooms[hotelId=$hotelId]: ${list.length}');
    return list;
  }

  Future<List<AttractionPhoto>> fetchCityAttractions(String city, {int limit = 8}) async {
    final normalizedCity = city.trim();
    if (normalizedCity.isEmpty) return [];
    final raw = await _api.get('${ApiConstants.cityAttractions(normalizedCity)}?limit=$limit');
    final photos = ApiDataParser.map(raw)['photos'] ?? ApiDataParser.list(raw);
    return ApiDataParser.list(photos)
        .map((e) => AttractionPhoto.fromJson(Map<String, dynamic>.from(e)))
        .where((photo) => photo.imageUrl.isNotEmpty)
        .toList();
  }
}
