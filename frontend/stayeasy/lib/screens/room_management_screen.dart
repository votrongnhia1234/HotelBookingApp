import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import 'package:stayeasy/models/hotel.dart';
import 'package:stayeasy/models/room.dart';
import 'package:stayeasy/models/room_image.dart';
import 'package:stayeasy/services/api_service.dart';
import 'package:stayeasy/services/hotel_service.dart';
import 'package:stayeasy/services/room_service.dart';

Future<List<XFile>> _pickImagesFromDevice({bool allowMultiple = true}) async {
  final isMobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  if (isMobile) {
    final picker = ImagePicker();
    if (allowMultiple) {
      final result = await picker.pickMultiImage(maxWidth: 1600);
      return result ?? <XFile>[];
    }
    final single = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
    );
    return single == null ? <XFile>[] : <XFile>[single];
  }

  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: allowMultiple,
    withData: true,
  );
  if (result == null) return <XFile>[];

  final xFiles = <XFile>[];

  for (final file in result.files) {
    // Trên web, không tin cậy vào đường dẫn (thường là C:\\fakepath\\...). Luôn dùng bytes.
    if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
      xFiles.add(XFile(file.path!));
      continue;
    }
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) continue;

    final fileName = file.name.isNotEmpty
        ? file.name
        : 'image_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final mimeType = lookupMimeType(fileName);
    xFiles.add(XFile.fromData(bytes, name: fileName, mimeType: mimeType));
  }

  return xFiles;
}

Future<XFile?> _pickSingleImageFromDevice() async {
  final files = await _pickImagesFromDevice(allowMultiple: false);
  if (files.isEmpty) return null;
  return files.first;
}

class RoomManagementScreen extends StatefulWidget {
  const RoomManagementScreen({super.key});

  @override
  State<RoomManagementScreen> createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> {
  final _hotelService = HotelService();
  final _roomService = RoomService();

  late Future<List<Hotel>> _hotelsFuture;
  final Map<int, Future<List<Room>>> _roomsFuture = {};

  @override
  void initState() {
    super.initState();
    _hotelsFuture = _hotelService.fetchManagedHotels();
  }

  Future<void> _refresh() async {
    setState(() {
      _hotelsFuture = _hotelService.fetchManagedHotels();
      _roomsFuture.clear();
    });
    await _hotelsFuture;
  }

  Future<void> _loadRooms(int hotelId) async {
    setState(() {
      _roomsFuture[hotelId] = _roomService.listByHotel(hotelId);
    });
  }

  Future<void> _showCreateRoomDialog(Hotel hotel) async {
    final formKey = GlobalKey<FormState>();
    String roomNumber = '';
    String roomType = '';
    String priceText = '';
    String status = 'available';
    List<XFile> selectedImages = [];

    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text('Thêm phòng cho ${hotel.name}'),
                content: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Số phòng',
                          ),
                          keyboardType: TextInputType.text,
                          onChanged: (value) => roomNumber = value.trim(),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Nhập số phòng'
                              : null,
                        ),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Loại phòng',
                          ),
                          keyboardType: TextInputType.text,
                          onChanged: (value) => roomType = value.trim(),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Nhập loại phòng'
                              : null,
                        ),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Giá/đêm (VND)',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => priceText = value.trim(),
                          validator: (value) {
                            final raw = (value ?? '').trim();
                            if (raw.isEmpty) return 'Nhập giá phòng';
                            return double.tryParse(raw) == null
                                ? 'Giá không hợp lệ'
                                : null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: status,
                          decoration: const InputDecoration(
                            labelText: 'Trạng thái',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'available',
                              child: Text('Sẵn sàng'),
                            ),
                            DropdownMenuItem(
                              value: 'booked',
                              child: Text('Đang được đặt'),
                            ),
                            DropdownMenuItem(
                              value: 'maintenance',
                              child: Text('Bảo trì'),
                            ),
                          ],
                          onChanged: (value) => setDialogState(() {
                            status = value ?? status;
                          }),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Ảnh phòng (tùy chọn)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        if (selectedImages.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (int i = 0; i < selectedImages.length; i++)
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: FutureBuilder<Uint8List>(
                                              future: selectedImages[i]
                                                  .readAsBytes(),
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState !=
                                                    ConnectionState.done) {
                                                  return const SizedBox(
                                                    width: 72,
                                                    height: 72,
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    ),
                                                  );
                                                }
                                                if (!snapshot.hasData ||
                                                    snapshot.data == null) {
                                                  return const SizedBox(
                                                    width: 72,
                                                    height: 72,
                                                    child: Icon(
                                                      Icons.image_not_supported,
                                                    ),
                                                  );
                                                }
                                                return Image.memory(
                                                  snapshot.data!,
                                                  width: 72,
                                                  height: 72,
                                                  fit: BoxFit.cover,
                                                );
                                              },
                                            ),
                                    ),
                                    Positioned(
                                      top: -8,
                                      right: -8,
                                      child: IconButton(
                                        icon: const Icon(Icons.close, size: 18),
                                        splashRadius: 18,
                                        onPressed: () {
                                          setDialogState(() {
                                            selectedImages.removeAt(i);
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          )
                        else
                          const Text(
                            'Chưa chọn ảnh nào.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('Chọn ảnh'),
                          onPressed: () async {
                            final files = await _pickImagesFromDevice(
                              allowMultiple: true,
                            );
                            if (files.isEmpty) return;
                            setDialogState(() {
                              selectedImages = [...selectedImages, ...files];
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Hủy'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState?.validate() ?? false) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    },
                    child: const Text('Thêm'),
                  ),
                ],
              );
            },
          );
        },
      );

      final price = double.tryParse(priceText);
      if (result == true &&
          price != null &&
          roomNumber.isNotEmpty &&
          roomType.isNotEmpty) {
        try {
          final newRoomId = await _roomService.createRoom(
            hotelId: hotel.id,
            roomNumber: roomNumber,
            type: roomType,
            pricePerNight: price,
            status: status,
          );

          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Đã thêm phòng mới.')));

          if (selectedImages.isNotEmpty) {
            int uploaded = 0;
            final withPath = selectedImages
                .where((x) => x.path.isNotEmpty)
                .toList();
            final withoutPath = selectedImages
                .where((x) => x.path.isEmpty)
                .toList();

            if (withPath.isNotEmpty) {
              final paths = withPath.map((x) => x.path).toList();
              if (paths.length > 1) {
                await _roomService.addImagesBulk(
                  roomId: newRoomId,
                  localFilePaths: paths,
                );
                uploaded += paths.length;
              } else {
                await _roomService.addImage(
                  roomId: newRoomId,
                  localFilePath: paths.first,
                );
                uploaded += 1;
              }
            }

            if (withoutPath.isNotEmpty) {
              final bytesList = await Future.wait(
                withoutPath.map((x) => x.readAsBytes()),
              );
              final names = withoutPath
                  .map(
                    (x) => x.name.isNotEmpty
                        ? x.name
                        : 'image_${DateTime.now().microsecondsSinceEpoch}.jpg',
                  )
                  .toList();
              await _roomService.addImagesBytesBulk(
                roomId: newRoomId,
                filesBytes: bytesList,
                fileNames: names,
              );
              uploaded += withoutPath.length;
            }

            if (mounted) {
              if (uploaded > 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã tải $uploaded ảnh cho phòng mới.'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Không thể tải ảnh vừa chọn.')),
                );
              }
            }
          }

          await _loadRooms(hotel.id);
        } catch (e) {
          if (!mounted) return;
          final message = _formatApiError(e);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể tạo phòng: $message')),
          );
        }
      }
    } finally {
      selectedImages.clear();
    }
  }

  Future<void> _updateStatus(Room room, String status) async {
    try {
      await _roomService.updateStatus(roomId: room.id, status: status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật phòng ${room.roomNumber}.')),
      );
      await _loadRooms(room.hotelId);
    } catch (e) {
      if (!mounted) return;
      final message = _formatApiError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật trạng thái: $message')),
      );
    }
  }

  Future<void> _openRoomImages(Room room) async {
    final parentContext = context;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _RoomImagesSheet(
          room: room,
          service: _roomService,
          parentContext: parentContext,
          onUpdated: () => _loadRooms(room.hotelId),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý phòng'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
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
                  const Text('Không thể tải danh sách khách sạn.'),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _refresh,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          final hotels = snapshot.data ?? [];
          if (hotels.isEmpty) {
            return const Center(
              child: Text('Chưa có khách sạn trong hệ thống.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: hotels.length,
            itemBuilder: (context, index) {
              final hotel = hotels[index];
              final roomsFuture = _roomsFuture[hotel.id];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ExpansionTile(
                  title: Text(hotel.name),
                  subtitle: Text(
                    '${hotel.address ?? ''}${hotel.address.isNotEmpty ? ', ' : ''}${hotel.city ?? ''}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Thêm phòng',
                    onPressed: () => _showCreateRoomDialog(hotel),
                  ),
                  children: [
                    FutureBuilder<List<Room>>(
                      future: roomsFuture ?? _roomService.listByHotel(hotel.id),
                      builder: (context, roomSnapshot) {
                        if (roomSnapshot.connectionState !=
                            ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (roomSnapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Không thể tải phòng: ${roomSnapshot.error}',
                            ),
                          );
                        }
                        final rooms = roomSnapshot.data ?? [];
                        if (rooms.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Chưa có phòng cho khách sạn này.'),
                          );
                        }
                        return Column(
                          children: rooms
                              .map(
                                (room) => ListTile(
                                  onTap: () => _openRoomImages(room),
                                  title: Text(
                                    'Phòng ${room.roomNumber} • ${room.type}',
                                  ),
                                  subtitle: Text(
                                    'Giá: ${room.pricePerNight.toStringAsFixed(0)} đ/đêm',
                                  ),
                                  leading: room.thumbnailUrl != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            room.thumbnailUrl!,
                                            width: 56,
                                            height: 56,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                  Icons.image_not_supported,
                                                ),
                                          ),
                                        )
                                      : Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(Icons.hotel),
                                        ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.collections_outlined,
                                        ),
                                        tooltip: 'Quản lý ảnh',
                                        onPressed: () => _openRoomImages(room),
                                      ),
                                      DropdownButton<String>(
                                        value: room.status,
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'available',
                                            child: Text('Sẵn sàng'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'booked',
                                            child: Text('Đang được đặt'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'maintenance',
                                            child: Text('Bảo trì'),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          if (value != null &&
                                              value != room.status) {
                                            _updateStatus(room, value);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RoomImagesSheet extends StatefulWidget {
  const _RoomImagesSheet({
    required this.room,
    required this.service,
    required this.parentContext,
    required this.onUpdated,
  });

  final Room room;
  final RoomService service;
  final BuildContext parentContext;
  final VoidCallback onUpdated;

  @override
  State<_RoomImagesSheet> createState() => _RoomImagesSheetState();
}

class _RoomImagesSheetState extends State<_RoomImagesSheet> {
  bool _loading = true;
  String? _error;
  List<RoomImage> _images = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final images = await widget.service.fetchRoomImages(widget.room.id);
      if (!mounted) return;
      setState(() {
        _images = images;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _formatApiError(e);
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      widget.parentContext,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleAdd() async {
    try {
      final files = await _pickImagesFromDevice(allowMultiple: true);
      if (files.isEmpty) return;

      // Trên web, luôn dùng bytes. Không dùng đường dẫn (blob/fake path).
      final withPath = kIsWeb
          ? <XFile>[]
          : files.where((f) => f.path.isNotEmpty).toList();
      final withoutPath = kIsWeb
          ? files
          : files.where((f) => f.path.isEmpty).toList();

      if (withPath.isNotEmpty) {
        final paths = withPath.map((f) => f.path).toList();
        if (paths.length > 1) {
          await widget.service.addImagesBulk(
            roomId: widget.room.id,
            localFilePaths: paths,
          );
          _showSnack('Đã tải ${paths.length} ảnh.');
        } else {
          await widget.service.addImage(
            roomId: widget.room.id,
            localFilePath: paths.first,
          );
          _showSnack('Đã tải 1 ảnh.');
        }
      }

      if (withoutPath.isNotEmpty) {
        final bytesList = await Future.wait(
          withoutPath.map((x) => x.readAsBytes()),
        );
        final names = withoutPath
            .map(
              (x) => x.name.isNotEmpty
                  ? x.name
                  : 'image_${DateTime.now().microsecondsSinceEpoch}.jpg',
            )
            .toList();
        await widget.service.addImagesBytesBulk(
          roomId: widget.room.id,
          filesBytes: bytesList,
          fileNames: names,
        );
        _showSnack('Đã tải ${withoutPath.length} ảnh.');
      }

      await _load();
      widget.onUpdated();
    } catch (e) {
      _showSnack('Không thể thêm ảnh: ${_formatApiError(e)}');
    }
  }

  Future<void> _handleReplace(RoomImage image) async {
    try {
      final picked = await _pickSingleImageFromDevice();
      if (picked == null) return;

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        final name = picked.name.isNotEmpty
            ? picked.name
            : 'image_${DateTime.now().microsecondsSinceEpoch}.jpg';
        await widget.service.replaceRoomImageBytes(
          imageId: image.id,
          bytes: bytes,
          fileName: name,
        );
      } else if (picked.path.isEmpty) {
        final bytes = await picked.readAsBytes();
        final name = picked.name.isNotEmpty
            ? picked.name
            : 'image_${DateTime.now().microsecondsSinceEpoch}.jpg';
        await widget.service.replaceRoomImageBytes(
          imageId: image.id,
          bytes: bytes,
          fileName: name,
        );
      } else {
        await widget.service.replaceRoomImage(
          imageId: image.id,
          localFilePath: picked.path,
        );
      }
      _showSnack('Đã cập nhật ảnh.');
      await _load();
      widget.onUpdated();
    } catch (e) {
      _showSnack('Không thể đổi ảnh: ${_formatApiError(e)}');
    }
  }

  Future<void> _handleDelete(RoomImage image) async {
    try {
      await widget.service.deleteRoomImage(image.id);
      _showSnack('Đã xóa ảnh.');
      await _load();
      widget.onUpdated();
    } catch (e) {
      _showSnack('Không thể xóa ảnh: ${_formatApiError(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.6;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: media.viewInsets.bottom + 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ảnh phòng ${widget.room.roomNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Không thể tải ảnh: ${_error ?? ''}'),
              )
            else if (_images.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Chưa có ảnh nào cho phòng này.'),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _images.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final image = _images[index];
                    final createdAt = image.createdAt?.toLocal();
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          image.imageUrl,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.image_not_supported),
                        ),
                      ),
                      title: Text('Ảnh #${image.id}'),
                      subtitle: createdAt != null
                          ? Text(
                              'Tải lên: ${createdAt.toString().split(".").first}',
                            )
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.swap_horiz),
                            tooltip: 'Đổi ảnh',
                            onPressed: () => _handleReplace(image),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Xóa ảnh',
                            onPressed: () => _handleDelete(image),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Thêm ảnh'),
                    onPressed: _handleAdd,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatApiError(Object error) {
  if (error is ApiException) {
    try {
      final decoded = jsonDecode(error.body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {}
    final trimmed = error.body.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return 'API ${error.statusCode}';
  }
  return error.toString();
}
