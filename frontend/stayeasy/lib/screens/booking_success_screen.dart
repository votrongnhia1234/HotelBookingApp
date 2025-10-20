import 'package:flutter/material.dart';

import '../models/booking.dart';

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
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Đặt phòng thành công')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 8),
            const Text('Đặt phòng thành công!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mã đơn: #', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Thời gian:  → '),
                    const SizedBox(height: 6),
                    Text('Thanh toán:  ()'),
                    if (voucher != null) Text('Voucher: '),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/trips',
                  (route) => route.settings.name == '/home',
                ),
                icon: const Icon(Icons.event_available),
                label: const Text('Xem chuyến đi của tôi'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false),
              child: const Text('Về Trang chủ'),
            ),
          ],
        ),
      ),
    );
  }
}

