import 'package:flutter/material.dart';

import '../models/room.dart';
import '../services/favorites_service.dart';

class RoomCard extends StatefulWidget {
  const RoomCard({
    super.key,
    required this.room,
    this.onBook,
    this.onFavoriteChanged,
  });

  final Room room;
  final VoidCallback? onBook;
  final VoidCallback? onFavoriteChanged;

  @override
  State<RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends State<RoomCard> {
  bool _fav = false;

  @override
  void initState() {
    super.initState();
    _initFav();
  }

  Future<void> _initFav() async {
    final has = await FavoritesService.I.contains(widget.room.id.toString());
    if (mounted) setState(() => _fav = has);
  }

  Future<void> _toggleFav() async {
    await FavoritesService.I.toggle(widget.room.id.toString());
    final has = await FavoritesService.I.contains(widget.room.id.toString());
    if (mounted) setState(() => _fav = has);
    if (widget.onFavoriteChanged != null) widget.onFavoriteChanged!();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
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

      // room.imageUrl is a non-nullable string; treat empty string as missing
      final raw = room.imageUrl;
      final url = raw.isNotEmpty ? raw.toString() : null;
      if (url == null || url.isEmpty) return placeholder();

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                            (progress.expectedTotalBytes ?? 1)
                      : null,
                ),
              ),
            );
          },
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
                        text: room.status == 'available'
                            ? 'Còn phòng'
                            : 'Hết phòng',
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
            Column(
              children: [
                IconButton(
                  icon: Icon(
                    _fav ? Icons.favorite : Icons.favorite_border,
                    color: _fav ? Colors.redAccent : null,
                  ),
                  onPressed: _toggleFav,
                ),
                const SizedBox(height: 4),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: widget.onBook,
                  child: const Text('Đặt'),
                ),
              ],
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
