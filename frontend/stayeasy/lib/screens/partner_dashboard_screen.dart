import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stayeasy/models/booking_summary.dart';
import 'package:stayeasy/services/booking_service.dart';
import 'package:stayeasy/services/hotel_service.dart';
import 'package:stayeasy/models/booking.dart';
import 'package:stayeasy/widgets/booking_card.dart';

class PartnerDashboardScreen extends StatefulWidget {
  const PartnerDashboardScreen({super.key});

  @override
  State<PartnerDashboardScreen> createState() => _PartnerDashboardScreenState();
}

class _PartnerDashboardScreenState extends State<PartnerDashboardScreen> {
  final BookingService _service = BookingService();
  final HotelService _hotelService = HotelService();
  late Future<({String role, BookingSummary summary})> _future;
  late Future<int> _totalRoomsFuture;
  late Future<List<Booking>> _bookingsFuture;
  bool _exporting = false;
  bool _loadingAction = false;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchSummary();
    _totalRoomsFuture = _computeTotalRooms();
    _bookingsFuture = _service.fetchAllBookings();
  }

  Future<void> _pickFrom(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _to = picked);
  }

  String? _fmtDate(DateTime? d) {
    if (d == null) return null;
    return DateFormat('yyyy-MM-dd').format(d);
  }

  Future<int> _computeTotalRooms() async {
    try {
      final hotels = await _hotelService.fetchManagedHotels();
      if (hotels.isEmpty) return 0;
      final counts = await Future.wait(hotels.map((h) async {
        final rooms = await _hotelService.fetchRoomsByHotel(h.id);
        return rooms.length;
      }));
      return counts.fold<int>(0, (sum, c) => sum + c);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _exportExcel() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await _service.exportSummaryXlsx(from: _fmtDate(_from), to: _fmtDate(_to));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang tải tệp Excel...')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xuất Excel thất bại: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportCsv() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await _service.exportSummaryCsv(from: _fmtDate(_from), to: _fmtDate(_to));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang tải tệp CSV...')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xuất CSV thất bại: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ===== Actions on bookings =====
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

  Future<void> _updateStatus(Booking booking, String status) async {
    if (_loadingAction) return;
    setState(() => _loadingAction = true);
    try {
      await _service.updateStatus(booking.id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật trạng thái: $status')),
      );
      await _refreshBookings();
      // refresh summary too
      final freshSummary = _service.fetchSummary();
      setState(() { _future = freshSummary; });
      await freshSummary;
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
      await _refreshBookings();
      // refresh summary too
      final freshSummary = _service.fetchSummary();
      setState(() { _future = freshSummary; });
      await freshSummary;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể hoàn tất: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  // ===== Revenue calculations =====
  double _calcRevenueToday(List<Booking> bookings) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    double sum = 0;
    for (final b in bookings) {
      if (b.status.toLowerCase() != 'completed') continue;
      final co = b.checkOut.split('T').first;
      if (co == today) sum += b.totalPrice;
    }
    return sum;
  }

  Map<String, double> _revenueByDay(List<Booking> bookings, {DateTime? from, DateTime? to}) {
    final Map<String, double> map = {};
    final start = (from ?? DateTime.now().subtract(const Duration(days: 6))).toLocal();
    final end = (to ?? DateTime.now()).toLocal();
    for (final b in bookings) {
      if (b.status.toLowerCase() != 'completed') continue;
      DateTime? out;
      try {
        out = DateTime.parse(b.checkOut).toLocal();
      } catch (_) {
        continue;
      }
      if (out.isBefore(start) || out.isAfter(end)) continue;
      final key = DateFormat('yyyy-MM-dd').format(out);
      map[key] = (map[key] ?? 0) + b.totalPrice;
    }
    return map;
  }

  Future<void> _refreshBookings() async {
    final fresh = _service.fetchAllBookings();
    setState(() { _bookingsFuture = fresh; });
    await fresh;
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Số liệu đối tác')),
      body: FutureBuilder<({String role, BookingSummary summary})>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Không thể tải dữ liệu: ${snapshot.error}'));
          }
          final response = snapshot.data!;
          final summary = response.summary;

          final items = [
            _PartnerMetric(
              icon: Icons.pending_actions_outlined,
              label: 'Đang chờ',
              value: summary.pending.toString(),
            ),
            _PartnerMetric(
              icon: Icons.verified_outlined,
              label: 'Đã xác nhận',
              value: summary.confirmed.toString(),
            ),
            _PartnerMetric(
              icon: Icons.check_circle_outline,
              label: 'Hoàn tất',
              value: summary.completed.toString(),
            ),
            _PartnerMetric(
              icon: Icons.cancel_outlined,
              label: 'Đã hủy',
              value: summary.cancelled.toString(),
            ),
          ];

          return RefreshIndicator(
            onRefresh: () async {
              final fresh = _service.fetchSummary();
              setState(() => _future = fresh);
              await fresh;
              final roomsFuture = _computeTotalRooms();
              setState(() => _totalRoomsFuture = roomsFuture);
              await roomsFuture;
              await _refreshBookings();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tổng quan', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Text('Tổng số đơn: ${summary.total}'),
                        const SizedBox(height: 4),
                        FutureBuilder<int>(
                          future: _totalRoomsFuture,
                          builder: (context, snap) {
                            if (snap.connectionState != ConnectionState.done) {
                              return const Text('Đang tính tổng số phòng...');
                            }
                            final totalRooms = snap.data ?? 0;
                            return Text('Tổng số phòng: $totalRooms');
                          },
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Xuất dữ liệu', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.date_range),
                              label: Text(_from == null
                                  ? 'Từ ngày'
                                  : DateFormat('dd/MM/yyyy').format(_from!)),
                              onPressed: _exporting ? null : () => _pickFrom(context),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.event_outlined),
                              label: Text(_to == null
                                  ? 'Đến ngày'
                                  : DateFormat('dd/MM/yyyy').format(_to!)),
                              onPressed: _exporting ? null : () => _pickTo(context),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.file_present_outlined),
                              label: const Text('Xuất Excel'),
                              onPressed: _exporting ? null : _exportExcel,
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.table_chart_outlined),
                              label: const Text('Xuất CSV'),
                              onPressed: _exporting ? null : _exportCsv,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Giá trị pipeline: ${currency.format(summary.valuePipeline)}'),
                        const SizedBox(height: 4),
                        Text('Doanh thu đã hoàn tất: ${currency.format(summary.valueCompleted)}'),
                        const SizedBox(height: 4),
                        FutureBuilder<List<Booking>>(
                          future: _bookingsFuture,
                          builder: (context, snap) {
                            if (snap.connectionState != ConnectionState.done) {
                              return const Text('Đang tính doanh thu hôm nay...');
                            }
                            final todayRevenue = _calcRevenueToday(snap.data ?? const []);
                            return Text('Doanh thu hôm nay: ${currency.format(todayRevenue)}');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: items.map((e) => e.buildCard(context)).toList(),
                ),
                const SizedBox(height: 16),
                // ===== Revenue by day =====
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Doanh thu theo ngày', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        FutureBuilder<List<Booking>>(
                          future: _bookingsFuture,
                          builder: (context, snap) {
                            if (snap.connectionState != ConnectionState.done) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snap.hasError) {
                              return Text('Không thể tính doanh thu: ${snap.error}');
                            }
                            final bookings = snap.data ?? const <Booking>[];
                            final map = _revenueByDay(bookings, from: _from, to: _to);
                            if (map.isEmpty) {
                              return const Text('Chưa có doanh thu trong phạm vi chọn.');
                            }
                            final keys = map.keys.toList()..sort();
                            return Column(
                              children: keys
                                  .map((k) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: Row(
                                          children: [
                                            Expanded(child: Text(k)),
                                            Text(currency.format(map[k]!)),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Danh sách đặt phòng', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        FutureBuilder<List<Booking>>(
                          future: _bookingsFuture,
                          builder: (context, snap) {
                            if (snap.connectionState != ConnectionState.done) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snap.hasError) {
                              return Text('Không thể tải đơn đặt: ${snap.error}');
                            }
                            final bookings = snap.data ?? const <Booking>[];
                            if (bookings.isEmpty) {
                              return const Text('Chưa có đơn đặt nào.');
                            }
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: bookings.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PartnerMetric {
  const _PartnerMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  Widget buildCard(BuildContext context) {
    final theme = Theme.of(context);
    final width = math.max(MediaQuery.of(context).size.width / 2 - 24, 160).toDouble();
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}
