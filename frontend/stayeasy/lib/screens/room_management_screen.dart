import 'package:flutter/material.dart';
import 'package:stayeasy/models/hotel.dart';
import 'package:stayeasy/models/room.dart';
import 'package:stayeasy/services/hotel_service.dart';
import 'package:stayeasy/services/room_service.dart';

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
    _hotelsFuture = _hotelService.fetchHotels();
  }

  Future<void> _refresh() async {
    setState(() {
      _hotelsFuture = _hotelService.fetchHotels();
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
    final roomNumberController = TextEditingController();
    final typeController = TextEditingController();
    final priceController = TextEditingController();
    String status = 'available';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Thêm phòng cho ${hotel.name}'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: roomNumberController,
                    decoration: const InputDecoration(labelText: 'Số phòng'),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Nhập số phòng' : null,
                  ),
                  TextFormField(
                    controller: typeController,
                    decoration: const InputDecoration(labelText: 'Loại phòng'),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Nhập loại phòng' : null,
                  ),
                  TextFormField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Giá/đêm (VND)',
                    ),
                    keyboardType: TextInputType.number,
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
                    decoration: const InputDecoration(labelText: 'Trạng thái'),
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
                    onChanged: (value) => status = value ?? status,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    try {
      await _roomService.createRoom(
        hotelId: hotel.id,
        roomNumber: roomNumberController.text.trim(),
        type: typeController.text.trim(),
        pricePerNight: double.parse(priceController.text.trim()),
        status: status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã thêm phòng mới.')));
      await _loadRooms(hotel.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể tạo phòng: $e')));
    }
  }

  Future<void> _updateStatus(Room room, String status) async {
    try {
      await _roomService.updateStatus(roomId: room.id, status: status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật phòng ${room.roomNumber}')),
      );
      await _loadRooms(room.hotelId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật trạng thái: $e')),
      );
    }
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
                  subtitle: Text(hotel.address),
                  onExpansionChanged: (expanded) {
                    if (expanded && roomsFuture == null) {
                      _loadRooms(hotel.id);
                    }
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Thêm phòng',
                    onPressed: () => _showCreateRoomDialog(hotel),
                  ),
                  children: [
                    FutureBuilder<List<Room>>(
                      future: roomsFuture ?? _roomService.listByHotel(hotel.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Không thể tải phòng: ${snapshot.error}',
                            ),
                          );
                        }
                        final rooms = snapshot.data ?? [];
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
                                  title: Text(
                                    'Phòng ${room.roomNumber} • ${room.type}',
                                  ),
                                  subtitle: Text(
                                    'Giá: ${room.pricePerNight.toStringAsFixed(0)} đ/đêm',
                                  ),
                                  trailing: DropdownButton<String>(
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
