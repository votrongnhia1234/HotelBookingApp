import 'dart:typed_data';
import '../config/api_constants.dart';
import '../models/attraction_photo.dart';
import '../models/hotel.dart';
import '../models/room.dart';
import '../models/hotel_image.dart';
import 'api_service.dart';
import '../utils/api_data_parser.dart';

class HotelService {
  final _api = ApiService();

  Future<List<Hotel>> fetchHotels({int page = 1, int limit = 20, String? q, String? city}) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final raw = await _api.get('${ApiConstants.hotels}?$query');
    return ApiDataParser.list(raw)
        .map((e) => Hotel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Hotel>> fetchManagedHotels() async {
    final raw = await _api.get(ApiConstants.managedHotels);
    return ApiDataParser.list(raw)
        .map((e) => Hotel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Room>> fetchRoomsByHotel(int hotelId) async {
    final raw = await _api.get(ApiConstants.roomsByHotel(hotelId)); // /api/rooms/hotel/:id
    final list = ApiDataParser.list(raw)
        .map((e) => Room.fromJson(Map<String, dynamic>.from(e)))
        .toList();
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

  // Hotel images
  Future<List<HotelImage>> fetchHotelImages(int hotelId) async {
    final raw = await _api.get(ApiConstants.hotelImagesByHotel(hotelId));
    return ApiDataParser.list(raw)
        .map((e) => HotelImage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> addHotelImage({
    required int hotelId,
    String? imageUrl,
    String? localFilePath,
  }) async {
    if (localFilePath != null) {
      await _api.uploadFile(
        ApiConstants.hotelImagesUpload,
        'file',
        localFilePath,
        fields: {'hotel_id': hotelId.toString()},
      );
      return;
    }
    if (imageUrl != null) {
      await _api.post(ApiConstants.hotelImages, {
        'hotel_id': hotelId,
        'image_url': imageUrl,
      });
      return;
    }
    throw Exception('Phải cung cấp URL ảnh hoặc đường dẫn tệp để tải lên');
  }

  Future<void> addHotelImagesBulk({
    required int hotelId,
    required List<String> localFilePaths,
  }) async {
    if (localFilePaths.isEmpty) return;
    await _api.uploadFiles(
      ApiConstants.hotelImagesUploadMany,
      localFilePaths,
      fieldName: 'files',
      fields: {'hotel_id': hotelId.toString()},
    );
  }

  Future<void> addHotelImageBytes({
    required int hotelId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    await _api.uploadFileBytes(
      ApiConstants.hotelImagesUpload,
      'file',
      bytes,
      filename: fileName,
      fields: {'hotel_id': hotelId.toString()},
    );
  }

  Future<void> addHotelImagesBytesBulk({
    required int hotelId,
    required List<Uint8List> filesBytes,
    required List<String> fileNames,
  }) async {
    if (filesBytes.isEmpty) return;
    await _api.uploadFilesBytes(
      ApiConstants.hotelImagesUploadMany,
      filesBytes,
      fileNames: fileNames,
      fieldName: 'files',
      fields: {'hotel_id': hotelId.toString()},
    );
  }

  Future<void> replaceHotelImage({
    required int imageId,
    required String localFilePath,
  }) async {
    await _api.uploadFile(
      ApiConstants.hotelImageById(imageId),
      'file',
      localFilePath,
      method: 'PATCH',
    );
  }

  Future<void> replaceHotelImageBytes({
    required int imageId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    await _api.uploadFileBytes(
      ApiConstants.hotelImageById(imageId),
      'file',
      bytes,
      filename: fileName,
      method: 'PATCH',
    );
  }

  Future<void> deleteHotelImage(int imageId) async {
    await _api.delete(ApiConstants.hotelImageById(imageId));
  }
}
