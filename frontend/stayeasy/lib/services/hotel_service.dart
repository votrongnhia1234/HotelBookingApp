import '../config/api_constants.dart';
import '../models/hotel.dart';
import '../models/room.dart';
import 'api_service.dart';
import '../utils/api_data_parser.dart';

class HotelService {
  final _api = ApiService();

  Future<List<Hotel>> fetchHotels() async {
    final raw = await _api.get(ApiConstants.hotels);
    return ApiDataParser.list(raw).map((e) => Hotel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<Room>> fetchRoomsByHotel(int hotelId) async {
    final raw = await _api.get(ApiConstants.roomsByHotel(hotelId)); // /api/rooms/hotel/:id
    final list = ApiDataParser.list(raw).map((e) => Room.fromJson(Map<String, dynamic>.from(e))).toList();
    // log nhỏ để chắc rằng có dữ liệu
    // (sẽ hiện trên console: Rooms[hotelId=1]: 3)
    // ignore: avoid_print
    print('Rooms[hotelId=$hotelId]: ${list.length}');
    return list;
  }
}
