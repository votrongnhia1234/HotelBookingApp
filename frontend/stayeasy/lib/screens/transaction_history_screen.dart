import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../services/user_service.dart';
import '../state/auth_state.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final _userService = UserService();
  late Future<List<Booking>> _future;

  @override
  void initState() {
    super.initState();
    final user = AuthState.I.currentUser;
    if (user == null) {
      _future = Future.error('Bạn cần đăng nhập để xem lịch sử giao dịch.');
    } else {
      _future = _userService.fetchTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử giao dịch'),
      ),
      body: FutureBuilder<List<Booking>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Không thể tải lịch sử giao dịch.'),
                    const SizedBox(height: 8),
                    Text(snapshot.error.toString(),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }
          final bookings = snapshot.data ?? [];
          if (bookings.isEmpty) {
            return const Center(
              child: Text('Bạn chưa có giao dịch nào.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final hotelName =
                  booking.hotelName.isNotEmpty ? booking.hotelName : 'Khách sạn';
              final roomLabel = booking.roomNumber.isNotEmpty
                  ? booking.roomNumber
                  : booking.roomId.toString();
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  title: Text('$hotelName - Phòng $roomLabel'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Thời gian: ${booking.checkIn} → ${booking.checkOut}'),
                      const SizedBox(height: 4),
                      Text(
                        'Trạng thái: ${booking.status}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                  trailing: Text(
                    _formatCurrency(booking.totalPrice),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatCurrency(num amount) {
    return '${amount.toStringAsFixed(0)} đ';
  }
}
