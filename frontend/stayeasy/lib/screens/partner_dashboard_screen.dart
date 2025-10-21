import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stayeasy/models/booking_summary.dart';
import 'package:stayeasy/services/booking_service.dart';

class PartnerDashboardScreen extends StatefulWidget {
  const PartnerDashboardScreen({super.key});

  @override
  State<PartnerDashboardScreen> createState() => _PartnerDashboardScreenState();
}

class _PartnerDashboardScreenState extends State<PartnerDashboardScreen> {
  final BookingService _service = BookingService();
  late Future<({String role, BookingSummary summary})> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchSummary();
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
                        const SizedBox(height: 8),
                        Text('Giá trị pipeline: ${currency.format(summary.valuePipeline)}'),
                        const SizedBox(height: 4),
                        Text('Doanh thu đã hoàn tất: ${currency.format(summary.valueCompleted)}'),
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
