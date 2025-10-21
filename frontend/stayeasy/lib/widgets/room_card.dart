import 'package:flutter/material.dart';

import '../models/room.dart';

class RoomCard extends StatelessWidget {
  const RoomCard({super.key, required this.room, this.onBook});

  final Room room;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    Widget buildImage() {
      Widget placeholder() {
        return Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.bed, size: 28, color: Colors.black54),
        );
      }

      if (room.imageUrl.isEmpty) {
        return placeholder();
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          room.imageUrl,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder(),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            buildImage(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${room.type} - ${room.roomNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _StatusChip(
                        text: room.status == 'available' ? 'Còn phòng' : 'Hết phòng',
                        positive: room.status == 'available',
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Giá/đêm: ${room.pricePerNight}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onBook,
              child: const Text('Đặt'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text, required this.positive});

  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final bg = positive ? const Color(0xFFE8F7EF) : const Color(0xFFFDEEEE);
    final fg = positive ? const Color(0xFF1F8B4C) : const Color(0xFFD64545);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
