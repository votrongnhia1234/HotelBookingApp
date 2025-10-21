import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stayeasy/models/dashboard_stats.dart';
import 'package:stayeasy/services/admin_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _service = AdminService();
  late Future<DashboardStats> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Bảng điều khiển quản trị')),
      body: FutureBuilder<DashboardStats>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Không thể tải dữ liệu: ${snapshot.error}'));
          }
          final stats = snapshot.data!;
          final tiles = <_MetricTile>[
            _MetricTile(label: 'Người dùng', value: stats.users.toString(), icon: Icons.people_alt),
            _MetricTile(label: 'Khách sạn', value: stats.hotels.toString(), icon: Icons.apartment),
            _MetricTile(label: 'Phòng', value: stats.rooms.toString(), icon: Icons.meeting_room_outlined),
            _MetricTile(label: 'Đơn đặt', value: stats.bookings.toString(), icon: Icons.event_available),
            _MetricTile(
              label: 'Doanh thu (tổng)',
              value: currency.format(stats.revenueAll),
              icon: Icons.ssid_chart,
            ),
            _MetricTile(
              label: 'Doanh thu hôm nay',
              value: currency.format(stats.revenueToday),
              icon: Icons.today,
            ),
          ];

          return RefreshIndicator(
            onRefresh: () async {
              final fresh = _service.fetchDashboard();
              setState(() => _future = fresh);
              await fresh;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Cập nhật đến ${stats.asOf}', style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: tiles.map((tile) => tile.buildCard(context)).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricTile {
  const _MetricTile({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

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
