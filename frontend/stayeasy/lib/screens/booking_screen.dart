import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stayeasy/models/booking.dart';
import 'package:stayeasy/models/room.dart';
import 'package:stayeasy/services/booking_service.dart';
import 'package:stayeasy/state/auth_state.dart';
import 'package:stayeasy/widgets/custom_button.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.room});

  final Room room;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final BookingService _service = BookingService();
  final DateFormat _displayDate = DateFormat('dd/MM/yyyy');
  final NumberFormat _currencyFormat = NumberFormat.decimalPattern('vi_VN');

  DateTime _checkIn = DateTime.now();
  DateTime _checkOut = DateTime.now().add(const Duration(days: 1));
  bool _loading = false;

  int get _nights {
    final nights = _checkOut.difference(_checkIn).inDays;
    return nights <= 0 ? 1 : nights;
  }

  int get _total => _nights * widget.room.pricePerNight;

  String _formatForApi(DateTime value) =>
      value.toIso8601String().substring(0, 10);

  String _formatDisplay(DateTime value) => _displayDate.format(value);

  String get _stayPeriodText {
    final nightsSuffix = _nights > 1 ? 'đêm' : 'đêm';
    return '${_formatDisplay(_checkIn)} → ${_formatDisplay(_checkOut)} ($_nights $nightsSuffix)';
  }

  String _priceText(num value) => '${_currencyFormat.format(value)} ₫';

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _checkIn, end: _checkOut),
    );
    if (picked != null) {
      setState(() {
        _checkIn = picked.start;
        _checkOut = picked.end;
      });
    }
  }

  Future<void> _confirm() async {
    if (!AuthState.I.isLoggedIn) {
      await Navigator.pushNamed(context, '/login');
      if (!mounted) return;
      if (!AuthState.I.isLoggedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập để tiếp tục đặt phòng.'),
          ),
        );
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final Booking created = await _service.createBooking(
        roomId: widget.room.id,
        checkIn: _formatForApi(_checkIn),
        checkOut: _formatForApi(_checkOut),
      );
      final bookingForPayment = created.totalPrice == 0
          ? created.copyWith(totalAmount: _total.toDouble())
          : created;
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/payment',
        arguments: bookingForPayment,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đặt phòng thất bại: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final roomTitle = room.type.isNotEmpty
        ? room.type
        : 'Phòng ${room.roomNumber}';

    return Scaffold(
      appBar: AppBar(title: const Text('Đặt phòng')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: (room.thumbnailUrl != null && room.thumbnailUrl!.isNotEmpty)
                          ? Image.network(
                              room.thumbnailUrl!,
                              height: 56,
                              width: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 56,
                                width: 56,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.bed, color: Colors.black54),
                              ),
                            )
                          : Container(
                              height: 56,
                              width: 56,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.bed, color: Colors.black54),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            roomTitle,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Giá/đêm: ${_priceText(room.pricePerNight)}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Thời gian lưu trú',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(_stayPeriodText),
              trailing: const Icon(Icons.calendar_month),
              onTap: _pickRange,
            ),
            const Divider(),
            const Text(
              'Chi tiết thanh toán',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _row('Giá/đêm', _priceText(room.pricePerNight)),
            _row('Số đêm', _nights.toString()),
            _row('Thuế/phí', _priceText(0)),
            const SizedBox(height: 8),
            _row('Tổng tiền', _priceText(_total), bold: true),
            const Spacer(),
            CustomButton(
              label: 'Xác nhận & thanh toán',
              onPressed: _confirm,
              loading: _loading,
              icon: Icons.lock,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
