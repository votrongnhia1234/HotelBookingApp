import 'package:flutter/material.dart';
import 'package:stayeasy/models/booking.dart';
import 'package:stayeasy/services/booking_service.dart';
import 'package:stayeasy/state/auth_state.dart';
import 'package:stayeasy/widgets/booking_card.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  final BookingService _service = BookingService();
  late Future<List<Booking>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadBookings();
  }

  Future<List<Booking>> _loadBookings() async {
    final user = AuthState.I.currentUser;
    if (user == null) {
      throw const _AuthRequiredException();
    }
    return _service.fetchBookingsForUser(user.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadBookings();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phòng đã đặt')),
      body: FutureBuilder<List<Booking>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            if (error is _AuthRequiredException) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Vui lòng đăng nhập để xem đơn đặt phòng.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                      child: const Text('Đăng nhập'),
                    ),
                  ],
                ),
              );
            }
            return Center(child: Text('Không thể tải dữ liệu: $error'));
          }
          final bookings = snapshot.data ?? [];
          if (bookings.isEmpty) {
            return const Center(child: Text('Bạn chưa có đơn đặt phòng nào.'));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: bookings.length,
              itemBuilder: (_, index) => BookingCard(booking: bookings[index]),
            ),
          );
        },
      ),
    );
  }
}

class _AuthRequiredException implements Exception {
  const _AuthRequiredException();
}
