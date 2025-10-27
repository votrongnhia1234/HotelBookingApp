import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../models/hotel.dart';

class HotelCard extends StatelessWidget {
  const HotelCard({
    super.key,
    required this.hotel,
    this.onTap,
    this.heroTag,
    this.distanceKm,
  });

  final Hotel hotel;
  final VoidCallback? onTap;
  final String? heroTag;
  final double? distanceKm;

  bool get _hasLocation => hotel.latitude != null && hotel.longitude != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(16);
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Column(
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: Hero(
                    // ensure each hotel's hero tag is unique when not provided
                    tag: heroTag ?? 'hotel-image-${hotel.id}',
                    child: hotel.imageUrl.isEmpty
                        ? Container(color: Colors.grey.shade200)
                        : Image.network(
                            hotel.imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(color: Colors.grey.shade200);
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(color: Colors.grey.shade200);
                            },
                          ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          const Color.fromRGBO(0, 0, 0, 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  right: 12,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          hotel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RatingPill(rating: hotel.rating),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.place, size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hotel.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                      if (_hasLocation)
                        IconButton(
                          icon: Icon(
                            Icons.map_outlined,
                            color: cs.primary,
                          ),
                          tooltip: 'Xem trên bản đồ',
                          onPressed: () => _openMap(context),
                        ),
                    ],
                  ),
                  if (hotel.minPrice != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.attach_money, size: 16, color: cs.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Giá từ ${currency.format(hotel.minPrice)}',
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (distanceKm != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.near_me,
                          size: 16,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${distanceKm!.toStringAsFixed(1)} km',
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMap(BuildContext context) async {
    if (!_hasLocation) return;
    final lat = hotel.latitude!.toStringAsFixed(6);
    final lng = hotel.longitude!.toStringAsFixed(6);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Không mở được bản đồ.')));
      }
    }
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.95),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: Colors.amber, size: 16),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}