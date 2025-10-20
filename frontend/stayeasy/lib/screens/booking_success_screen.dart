import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stayeasy/models/booking.dart';

class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({
    super.key,
    required this.booking,
    required this.payAmount,
    required this.payMethod,
    this.voucher,
  });

  final Booking booking;
  final double payAmount;
  final String payMethod;
  final String? voucher;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    final statusInfo = _statusPresentation(booking.status);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Đặt phòng thành công'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const Icon(Icons.check_circle, color: Colors.green, size: 72),
            const SizedBox(height: 12),
            Text(
              'Cảm ơn bạn đã lựa chọn StayEasy!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Mã đơn', '#${booking.id}'),
                    const SizedBox(height: 8),
                    if (booking.hotelName.isNotEmpty)
                      _infoRow('Khách sạn', booking.hotelName),
                    if (booking.roomNumber.isNotEmpty)
                      _infoRow('Phòng', booking.roomNumber),
                    if (booking.roomType.isNotEmpty)
                      _infoRow('Loại phòng', booking.roomType),
                    const SizedBox(height: 8),
                    _infoRow('Thời gian', _stayRange()),
                    _infoRow('Thanh toán', _paymentDescription(currency)),
                    if (voucher != null && voucher!.isNotEmpty)
                      _infoRow('Voucher', voucher!),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusInfo.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusInfo.label,
                            style: TextStyle(color: statusInfo.color, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Tổng: ${currency.format(payAmount)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/trips',
                (route) => route.settings.name == '/home',
              ),
              icon: const Icon(Icons.event_available),
              label: const Text('Xem phòng đã đặt'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false),
              child: const Text('Về trang chủ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _stayRange() {
    final inDate = _formatDate(booking.checkIn);
    final outDate = _formatDate(booking.checkOut);
    final nights = _calcNights();
    final nightsText = nights > 0 ? ' ($nights đêm)' : '';
    return '$inDate → $outDate$nightsText';
  }

  String _paymentDescription(NumberFormat currency) {
    final methodText = payMethod == 'online' ? 'Trực tuyến' : 'Thanh toán tại khách sạn';
    return '$methodText • ${currency.format(payAmount)}';
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
      return DateFormat('dd/MM/yyyy').format(parsed);
    }
    return raw;
  }

  _StatusPresentation _statusPresentation(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return const _StatusPresentation('Đã xác nhận', Color(0xFF1D4ED8));
      case 'completed':
        return const _StatusPresentation('Hoàn tất', Color(0xFF15803D));
      case 'cancelled':
        return const _StatusPresentation('Đã hủy', Color(0xFFB91C1C));
      default:
        return const _StatusPresentation('Đang xử lý', Color(0xFFF59E0B));
    }
  }
}

class _StatusPresentation {
  const _StatusPresentation(this.label, this.color);

  final String label;
  final Color color;
}
