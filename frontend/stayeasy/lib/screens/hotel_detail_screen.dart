import 'package:flutter/material.dart';

import '../models/attraction_photo.dart';
import '../models/hotel.dart';
import '../models/room.dart';
import '../services/hotel_service.dart';
import '../widgets/room_card.dart';

class HotelDetailScreen extends StatefulWidget {
  const HotelDetailScreen({super.key, required this.hotel});

  final Hotel hotel;

  @override
  State<HotelDetailScreen> createState() => _HotelDetailScreenState();
}

class _HotelDetailScreenState extends State<HotelDetailScreen> {
  final HotelService _service = HotelService();

  late Future<List<Room>> _roomsFuture;
  late Future<List<AttractionPhoto>> _attractionsFuture;

  @override
  void initState() {
    super.initState();
    _roomsFuture = _service.fetchRoomsByHotel(widget.hotel.id);
    _attractionsFuture = _service.fetchCityAttractions(widget.hotel.city);
  }

  @override
  Widget build(BuildContext context) {
    final hotel = widget.hotel;
    return Scaffold(
      appBar: AppBar(title: Text(hotel.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.pushNamed(context, '/review', arguments: hotel),
        icon: const Icon(Icons.rate_review),
        label: const Text('Đánh giá'),
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 180,
            child: hotel.imageUrl.isEmpty
                ? Container(color: Colors.grey.shade200)
                : Image.network(hotel.imageUrl, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.place, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text(hotel.address)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Danh sách phòng',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          FutureBuilder<List<AttractionPhoto>>(
            future: _attractionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox.shrink();
              }
              final photos = snapshot.data ?? [];
              if (photos.isEmpty || snapshot.hasError) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      'Điểm đến nổi bật gần đây',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 140,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final photo = photos[index];
                          return SizedBox(
                            width: 200,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    photo.imageUrl,
                                    fit: BoxFit.cover,
                                  ),
                                  Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black87,
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          photo.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          photo.source,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemCount: photos.length,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Room>>(
            future: _roomsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent),
                      const SizedBox(height: 8),
                      Text(
                        'Không thể tải danh sách phòng cho khách sạn (ID = ${hotel.id}).',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _roomsFuture = _service.fetchRoomsByHotel(hotel.id);
                          });
                        },
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                );
              }

              final rooms = snapshot.data ?? [];
              if (rooms.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Hiện chưa có phòng khả dụng cho khách sạn này.',
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _roomsFuture = _service.fetchRoomsByHotel(hotel.id);
                          });
                        },
                        child: const Text('Tải lại'),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: rooms
                    .map(
                      (room) => RoomCard(
                        room: room,
                        onBook: () => Navigator.pushNamed(
                          context,
                          '/booking',
                          arguments: room,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
