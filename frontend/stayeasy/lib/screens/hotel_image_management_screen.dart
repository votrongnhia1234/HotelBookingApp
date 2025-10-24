import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import 'package:stayeasy/models/hotel.dart';
import 'package:stayeasy/models/hotel_image.dart';
import 'package:stayeasy/services/api_service.dart';
import 'package:stayeasy/services/hotel_service.dart';
import 'package:stayeasy/state/auth_state.dart';
import 'package:stayeasy/services/admin_service.dart';

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

class HotelImageManagementScreen extends StatefulWidget {
  const HotelImageManagementScreen({super.key});

  @override
  State<HotelImageManagementScreen> createState() =>
      _HotelImageManagementScreenState();
}

class _HotelImageManagementScreenState
    extends State<HotelImageManagementScreen> {
  final _hotelService = HotelService();
  final _adminService = AdminService();
  late Future<List<Hotel>> _hotelsFuture;
  final Map<int, Future<List<HotelImage>>> _hotelImagesFuture = {};

  @override
  void initState() {
    super.initState();
    _hotelsFuture = AuthState.I.isAdmin
        ? _hotelService.fetchHotels()
        : _hotelService.fetchManagedHotels();
  }

  Future<void> _refresh() async {
    setState(() {
      _hotelsFuture = AuthState.I.isAdmin
          ? _hotelService.fetchHotels()
          : _hotelService.fetchManagedHotels();
      _hotelImagesFuture.clear();
    });
    await _hotelsFuture;
  }

  Future<void> _openCreateHotelDialog() async {
    final nameCtl = TextEditingController();
    final addressCtl = TextEditingController();
    final descCtl = TextEditingController();
    final ratingCtl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Thêm khách sạn'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Tên khách sạn *')),
                TextField(controller: addressCtl, decoration: const InputDecoration(labelText: 'Địa chỉ')),
                TextField(controller: descCtl, decoration: const InputDecoration(labelText: 'Mô tả')),
                TextField(controller: ratingCtl, decoration: const InputDecoration(labelText: 'Đánh giá theo số sao')), 
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final rating = double.tryParse(ratingCtl.text);
                  final hotel = await _adminService.createHotel(
                    name: nameCtl.text.trim(),
                    address: addressCtl.text.trim().isEmpty ? null : addressCtl.text.trim(),
                    description: descCtl.text.trim().isEmpty ? null : descCtl.text.trim(),
                    rating: rating,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã tạo: ${hotel.name}')),
                  );
                  Navigator.pop(context);
                  await _refresh();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Không thể tạo khách sạn: $e')),
                  );
                }
              },
              child: const Text('Tạo Khách sạn'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openEditHotelDialog(Hotel hotel) async {
    final nameCtl = TextEditingController(text: hotel.name);
    final addressCtl = TextEditingController(text: hotel.address);
    final cityCtl = TextEditingController(text: hotel.city);
    final countryCtl = TextEditingController();
    final descCtl = TextEditingController(text: hotel.description);
    final ratingCtl = TextEditingController(text: hotel.rating.toString());
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sửa khách sạn'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Tên *')),
                TextField(controller: addressCtl, decoration: const InputDecoration(labelText: 'Địa chỉ')),
                TextField(controller: cityCtl, decoration: const InputDecoration(labelText: 'Thành phố')),
                TextField(controller: countryCtl, decoration: const InputDecoration(labelText: 'Quốc gia')),
                TextField(controller: descCtl, decoration: const InputDecoration(labelText: 'Mô tả')),
                TextField(controller: ratingCtl, decoration: const InputDecoration(labelText: 'Điểm đánh giá')), 
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final rating = double.tryParse(ratingCtl.text);
                  final updated = await _adminService.updateHotel(
                    hotel.id,
                    name: nameCtl.text.trim().isEmpty ? null : nameCtl.text.trim(),
                    address: addressCtl.text.trim().isEmpty ? null : addressCtl.text.trim(),
                    city: cityCtl.text.trim().isEmpty ? null : cityCtl.text.trim(),
                    country: countryCtl.text.trim().isEmpty ? null : countryCtl.text.trim(),
                    description: descCtl.text.trim().isEmpty ? null : descCtl.text.trim(),
                    rating: rating,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã cập nhật: ${updated.name}')),
                  );
                  Navigator.pop(context);
                  await _refresh();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Không thể cập nhật: $e')),
                  );
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteHotel(Hotel hotel) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa khách sạn'),
        content: Text('Bạn có chắc muốn xóa "${hotel.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _adminService.deleteHotel(hotel.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa khách sạn')),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể xóa: $e')),
      );
    }
  }

  Future<void> _openHotelImages(Hotel hotel) async {
    final parentContext = context;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _HotelImagesSheet(
          hotel: hotel,
          service: _hotelService,
          parentContext: parentContext,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý khách sạn'),
        actions: [
          if (AuthState.I.isAdmin)
            IconButton(icon: const Icon(Icons.add_business), tooltip: 'Thêm khách sạn', onPressed: _openCreateHotelDialog),
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
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(hotel.name),
                  subtitle: Text(
                    '${hotel.address}${hotel.address.isNotEmpty ? ', ' : ''}${hotel.city}',
                  ),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: hotel.imageUrl.isNotEmpty
                        ? Image.network(
                            hotel.imageUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.apartment),
                            ),
                          )
                        : FutureBuilder<List<HotelImage>>(
                            future: _hotelImagesFuture[hotel.id] ??=
                                _hotelService.fetchHotelImages(hotel.id),
                            builder: (context, snap) {
                              final images = snap.data ?? const <HotelImage>[];
                              final url = images.isNotEmpty ? images.first.imageUrl : '';
                              if (url.isNotEmpty) {
                                return Image.network(
                                  url,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.apartment),
                                  ),
                                );
                              }
                              return Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.apartment),
                              );
                            },
                          ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.collections_outlined),
                        tooltip: 'Quản lý ảnh',
                        onPressed: () => _openHotelImages(hotel),
                      ),
                      if (AuthState.I.isAdmin)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Sửa',
                          onPressed: () => _openEditHotelDialog(hotel),
                        ),
                      if (AuthState.I.isAdmin)
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Xóa',
                          onPressed: () => _confirmDeleteHotel(hotel),
                        ),
                    ],
                  ),
                  onTap: () => _openHotelImages(hotel),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HotelImagesSheet extends StatefulWidget {
  const _HotelImagesSheet({
    required this.hotel,
    required this.service,
    required this.parentContext,
  });

  final Hotel hotel;
  final HotelService service;
  final BuildContext parentContext;

  @override
  State<_HotelImagesSheet> createState() => _HotelImagesSheetState();
}

class _HotelImagesSheetState extends State<_HotelImagesSheet> {
  bool _loading = true;
  String? _error;
  List<HotelImage> _images = [];

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
      final images = await widget.service.fetchHotelImages(widget.hotel.id);
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

      final withPath = kIsWeb
          ? <XFile>[]
          : files.where((f) => f.path.isNotEmpty).toList();
      final withoutPath = kIsWeb
          ? files
          : files.where((f) => f.path.isEmpty).toList();

      if (withPath.isNotEmpty) {
        final paths = withPath.map((f) => f.path).toList();
        if (paths.length > 1) {
          await widget.service.addHotelImagesBulk(
            hotelId: widget.hotel.id,
            localFilePaths: paths,
          );
          _showSnack('Đã tải ${paths.length} ảnh.');
        } else {
          await widget.service.addHotelImage(
            hotelId: widget.hotel.id,
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
        await widget.service.addHotelImagesBytesBulk(
          hotelId: widget.hotel.id,
          filesBytes: bytesList,
          fileNames: names,
        );
        _showSnack('Đã tải ${withoutPath.length} ảnh.');
      }

      await _load();
    } catch (e) {
      _showSnack('Không thể thêm ảnh: ${_formatApiError(e)}');
    }
  }

  Future<void> _handleReplace(HotelImage image) async {
    try {
      final picked = await _pickSingleImageFromDevice();
      if (picked == null) return;

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        final name = picked.name.isNotEmpty
            ? picked.name
            : 'image_${DateTime.now().microsecondsSinceEpoch}.jpg';
        await widget.service.replaceHotelImageBytes(
          imageId: image.id,
          bytes: bytes,
          fileName: name,
        );
      } else if (picked.path.isEmpty) {
        final bytes = await picked.readAsBytes();
        final name = picked.name.isNotEmpty
            ? picked.name
            : 'image_${DateTime.now().microsecondsSinceEpoch}.jpg';
        await widget.service.replaceHotelImageBytes(
          imageId: image.id,
          bytes: bytes,
          fileName: name,
        );
      } else {
        await widget.service.replaceHotelImage(
          imageId: image.id,
          localFilePath: picked.path,
        );
      }
      _showSnack('Đã cập nhật ảnh.');
      await _load();
    } catch (e) {
      _showSnack('Không thể đổi ảnh: ${_formatApiError(e)}');
    }
  }

  Future<void> _handleDelete(HotelImage image) async {
    try {
      await widget.service.deleteHotelImage(image.id);
      _showSnack('Đã xóa ảnh.');
      await _load();
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
                    'Ảnh khách sạn: ${widget.hotel.name}',
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
                child: Text('Chưa có ảnh nào cho khách sạn này.'),
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
