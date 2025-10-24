import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stayeasy/models/booking.dart';
import 'package:stayeasy/services/booking_service.dart';
import 'package:stayeasy/widgets/booking_card.dart';

class PartnerBookingsScreen extends StatefulWidget {
  const PartnerBookingsScreen({super.key});

  @override
  State<PartnerBookingsScreen> createState() => _PartnerBookingsScreenState();
}

class _PartnerBookingsScreenState extends State<PartnerBookingsScreen> {
  final BookingService _service = BookingService();
  late Future<List<Booking>> _future;
  String _filter = 'all';
  bool _loadingAction = false;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchAllBookings();
  }

  Future<void> _refresh() async {
    final fresh = _service.fetchAllBookings();
    setState(() { _future = fresh; });
    await fresh;
  }

  List<Booking> _applyFilter(List<Booking> bookings) {
    if (_filter == 'all') return bookings;
    final target = _filter.toLowerCase();
    return bookings.where((b) => b.status.toLowerCase() == target).toList();
  }

  Future<void> _updateStatus(Booking booking, String status) async {
    if (_loadingAction) return;
    setState(() => _loadingAction = true);
    try {
      await _service.updateStatus(booking.id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật trạng thái: $status')),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật trạng thái: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  Future<void> _complete(Booking booking) async {
    if (_loadingAction) return;
    setState(() => _loadingAction = true);
    try {
      await _service.complete(booking.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đánh dấu hoàn tất')),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể hoàn tất: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  bool _canConfirm(Booking b) {
    final s = b.status.toLowerCase();
    return s == 'pending';
  }

  bool _canCancel(Booking b) {
    final s = b.status.toLowerCase();
    return s == 'pending' || s == 'confirmed' || s == 'completed';
  }

  bool _canComplete(Booking b) {
    final s = b.status.toLowerCase();
    return s == 'pending' || s == 'confirmed';
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý đơn đặt phòng'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                DropdownMenuItem(value: 'pending', child: Text('Chờ xác nhận')),
                DropdownMenuItem(value: 'confirmed', child: Text('Đã xác nhận')),
                DropdownMenuItem(value: 'completed', child: Text('Hoàn tất')),
                DropdownMenuItem(value: 'cancelled', child: Text('Đã hủy')),
              ],
              onChanged: (v) => setState(() => _filter = v ?? 'all'),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<Booking>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Không thể tải dữ liệu: ${snapshot.error}'));
          }
          final bookings = _applyFilter(snapshot.data ?? []);
          if (bookings.isEmpty) {
            return const Center(child: Text('Không có đơn đặt nào theo bộ lọc.'));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              itemCount: bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final b = bookings[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BookingCard(booking: b),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Row(
                        children: [
                          if (_canConfirm(b))
                            OutlinedButton.icon(
                              icon: const Icon(Icons.verified_outlined),
                              onPressed: _loadingAction ? null : () => _updateStatus(b, 'confirmed'),
                              label: const Text('Xác nhận'),
                            ),
                          const SizedBox(width: 8),
                          if (_canComplete(b))
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle_outline),
                              onPressed: _loadingAction ? null : () => _complete(b),
                              label: const Text('Hoàn tất'),
                            ),
                          const SizedBox(width: 8),
                          if (_canCancel(b))
                            TextButton.icon(
                              icon: const Icon(Icons.cancel_outlined),
                              onPressed: _loadingAction ? null : () => _updateStatus(b, 'cancelled'),
                              label: const Text('Hủy'),
                            ),
                          const Spacer(),
                          Text(currency.format(b.totalPrice)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}