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

  String _formatCurrency(num value) {
    final format = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return format.format(value);
  }

  String _paymentDescription(String method) {
    switch (method) {
      case 'online':
        return 'Thanh toán trực tuyến';
      case 'cod':
        return 'Thanh toán tại khách sạn';
      case 'bank':
        return 'Chuyển khoản ngân hàng';
      default:
        return 'Khác';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đặt phòng thành công')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 12),
            const Text(
              'Cảm ơn bạn! Đặt phòng của bạn đã được xác nhận.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Khách sạn: ${booking.hotelName}'),
                    Text('Phòng: ${booking.roomNumber}'),
                    Text('Ngày nhận phòng: ${booking.checkIn}'),
                    Text('Ngày trả phòng: ${booking.checkOut}'),
                    const Divider(),
                    Text('Phương thức: ${_paymentDescription(payMethod)}'),
                    Text('Số tiền: ${_formatCurrency(payAmount)}'),
                    if (voucher != null) Text('Voucher: $voucher'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/home',
                        (_) => false,
                        arguments: {'initialIndex': 2},
                      );
                    },
                    icon: const Icon(Icons.meeting_room),
                    label: const Text('Xem phòng đã đặt'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Về trang chủ'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
