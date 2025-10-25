import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stayeasy/models/booking.dart';

class BookingCard extends StatelessWidget {
  BookingCard({super.key, required this.booking})
    : _currencyFormat = NumberFormat.currency(
        locale: 'vi_VN',
        symbol: '₫',
        decimalDigits: 0,
      ),
      _dateFormat = DateFormat('dd/MM/yyyy');

  final Booking booking;
  final NumberFormat _currencyFormat;
  final DateFormat _dateFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(booking.status);
    final totalText = _currencyFormat.format(booking.totalPrice);
    final pricePerNight = booking.pricePerNight > 0
        ? _currencyFormat.format(booking.pricePerNight)
        : null;
    final hotelName = booking.hotelName.isNotEmpty
        ? booking.hotelName
        : 'Đơn #${booking.id}';
    final roomLabel = _roomLabel();
    final roomType = booking.roomType.isNotEmpty ? booking.roomType : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                height: 64,
                child: booking.imageUrl.isNotEmpty
                    ? Image.network(
                        booking.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: theme.colorScheme.primaryContainer,
                            child: const Icon(Icons.meeting_room_rounded, size: 28),
                          );
                        },
                      )
                    : Container(
                        color: theme.colorScheme.primaryContainer,
                        child: const Icon(Icons.meeting_room_rounded, size: 28),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hotelName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (roomLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Phòng: $roomLabel',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  if (roomType != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Loại phòng: $roomType',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black87,
                      ),
                    ),
                  ],
                  if (pricePerNight != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Giá/đêm: $pricePerNight',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Thời gian: ${_stayDates()}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tổng tiền',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            totalText,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: statusColor.background,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          statusColor.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _roomLabel() {
    if (booking.roomNumber.isNotEmpty) return booking.roomNumber;
    if (booking.roomId != 0) return '#${booking.roomId}';
    return null;
  }

  String _stayDates() {
    final checkIn = _formatDate(booking.checkIn);
    final checkOut = _formatDate(booking.checkOut);
    final nights = _calcNights();
    final nightsText = nights > 0 ? ' ($nights đêm)' : '';
    return '$checkIn → $checkOut$nightsText';
  }

  int _calcNights() {
    final start = DateTime.tryParse(booking.checkIn);
    final end = DateTime.tryParse(booking.checkOut);
    if (start == null || end == null) return 0;
    final diff = end.difference(start).inDays;
    return diff > 0 ? diff : 0;
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      return _dateFormat.format(parsed);
    }
    return raw;
  }

  _StatusPresentation _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return const _StatusPresentation(Color(0xFF1D4ED8), 'Đã xác nhận');
      case 'completed':
        return const _StatusPresentation(Color(0xFF15803D), 'Hoàn tất');
      case 'cancelled':
        return const _StatusPresentation(Color(0xFFB91C1C), 'Đã hủy');
      default:
        return const _StatusPresentation(Color(0xFFF59E0B), 'Đang xử lý');
    }
  }
}

class _StatusPresentation {
  const _StatusPresentation(this.background, this.label);

  final Color background;
  final String label;
}
