import 'dart:typed_data';
import '../config/api_constants.dart';
import '../models/room.dart';
import '../models/room_image.dart';
import '../utils/api_data_parser.dart';
import 'api_service.dart';

class RoomService {
  final ApiService _api = ApiService();

  Future<List<Room>> listByHotel(int hotelId) async {
    final raw = await _api.get(ApiConstants.managedRoomsByHotel(hotelId));
    return ApiDataParser.list(raw)
        .map((e) => Room.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<int> createRoom({
    required int hotelId,
    required String roomNumber,
    required String type,
    required num pricePerNight,
    String status = 'available',
  }) async {
    final raw = await _api.post(ApiConstants.rooms, {
      'hotel_id': hotelId,
      'room_number': roomNumber,
      'type': type,
      'price_per_night': pricePerNight,
      'status': status,
    });
    final map = ApiDataParser.map(raw);
    final payload = Map<String, dynamic>.from(map['data'] ?? map);
    final idValue = payload['id'] ?? payload['room_id'];
    if (idValue == null) {
      throw Exception('Không nhận được mã phòng mới tạo');
    }
    int id;
    if (idValue is int) {
      id = idValue;
    } else if (idValue is num) {
      id = idValue.toInt();
    } else if (idValue is String) {
      id = int.tryParse(idValue) ??
          double.tryParse(idValue)?.toInt() ??
          -1;
    } else {
      id = -1;
    }
    if (id <= 0) {
      throw Exception('Không nhận được mã phòng hợp lệ');
    }
    return id;
  }

  Future<void> updateStatus({
    required int roomId,
    required String status,
  }) async {
    await _api.patch(ApiConstants.roomStatus(roomId), {'status': status});
  }

  Future<void> updateDetails({
    required int roomId,
    String? roomNumber,
    String? type,
    num? pricePerNight,
  }) async {
    final payload = <String, dynamic>{
      if (roomNumber != null) 'room_number': roomNumber,
      if (type != null) 'type': type,
      if (pricePerNight != null) 'price_per_night': pricePerNight,
    };
    if (payload.isEmpty) return; // nothing to update
    await _api.patch(ApiConstants.roomById(roomId), payload);
  }

  Future<void> addImage({
    required int roomId,
    String? imageUrl,
    String? localFilePath,
  }) async {
    if (localFilePath != null) {
      await _api.uploadFile(
        ApiConstants.roomImagesUpload,
        'file',
        localFilePath,
        fields: {'room_id': roomId.toString()},
      );
      return;
    }
    if (imageUrl != null) {
      await _api.post(ApiConstants.roomImages, {
        'room_id': roomId,
        'image_url': imageUrl,
      });
      return;
    }
    throw Exception('Phải cung cấp URL ảnh hoặc đường dẫn tệp để tải lên');
  }

  // Bulk upload multiple local files in one request
  Future<void> addImagesBulk({
    required int roomId,
    required List<String> localFilePaths,
  }) async {
    if (localFilePaths.isEmpty) return;
    await _api.uploadFiles(
      ApiConstants.roomImagesUploadMany,
      localFilePaths,
      fieldName: 'files',
      fields: {'room_id': roomId.toString()},
    );
  }

  // Upload single image from bytes (web)
  Future<void> addImageBytes({
    required int roomId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    await _api.uploadFileBytes(
      ApiConstants.roomImagesUpload,
      'file',
      bytes,
      filename: fileName,
      fields: {'room_id': roomId.toString()},
    );
  }

  // Bulk upload images from bytes (web)
  Future<void> addImagesBytesBulk({
    required int roomId,
    required List<Uint8List> filesBytes,
    required List<String> fileNames,
  }) async {
    if (filesBytes.isEmpty) return;
    await _api.uploadFilesBytes(
      ApiConstants.roomImagesUploadMany,
      filesBytes,
      fileNames: fileNames,
      fieldName: 'files',
      fields: {'room_id': roomId.toString()},
    );
  }

  Future<List<RoomImage>> fetchRoomImages(int roomId) async {
    final raw = await _api.get(ApiConstants.roomImagesByRoom(roomId));
    return ApiDataParser.list(raw)
        .map((e) => RoomImage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> replaceRoomImage({
    required int imageId,
    required String localFilePath,
  }) async {
    await _api.uploadFile(
      ApiConstants.roomImageById(imageId),
      'file',
      localFilePath,
      method: 'PATCH',
    );
  }

  Future<void> replaceRoomImageBytes({
    required int imageId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    await _api.uploadFileBytes(
      ApiConstants.roomImageById(imageId),
      'file',
      bytes,
      filename: fileName,
      method: 'PATCH',
    );
  }

  Future<void> deleteRoomImage(int imageId) async {
    await _api.delete(ApiConstants.roomImageById(imageId));
  }
}
