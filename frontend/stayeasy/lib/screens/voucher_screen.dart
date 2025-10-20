import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stayeasy/models/voucher.dart';
import 'package:stayeasy/services/voucher_service.dart';
import 'package:stayeasy/state/auth_state.dart';

class VoucherScreen extends StatefulWidget {
  const VoucherScreen({super.key});

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  final VoucherService _service = VoucherService();
  late Future<List<Voucher>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Voucher>> _load() async {
    if (!AuthState.I.isLoggedIn) {
      throw const _AuthRequiredException();
    }
    return _service.listForCurrentUser();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ưu đãi của bạn')),
      body: FutureBuilder<List<Voucher>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final err = snapshot.error;
            if (err is _AuthRequiredException) {
              return _buildAuthPrompt(context);
            }
            return Center(child: Text('Không thể tải ưu đãi: $err'));
          }
          final vouchers = snapshot.data ?? [];
          if (vouchers.isEmpty) {
            return const Center(child: Text('Hiện chưa có ưu đãi nào cho tài khoản của bạn.'));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: vouchers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) => _VoucherCard(voucher: vouchers[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAuthPrompt(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Đăng nhập để xem ưu đãi dành riêng cho bạn.'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            icon: const Icon(Icons.login),
            label: const Text('Đăng nhập'),
          ),
        ],
      ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({required this.voucher});

  final Voucher voucher;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    final valueText = voucher.discountType == 'percent'
        ? '${voucher.value}%'
        : currency.format(voucher.value);
    final conditions = <String>[
      if (voucher.minOrder != null) 'Đơn tối thiểu ${currency.format(voucher.minOrder)}',
      if (voucher.onlineOnly) 'Chỉ áp dụng thanh toán online',
      if (voucher.expiry != null) 'HSD: ${DateFormat('dd/MM/yyyy').format(voucher.expiry!)}',
    ].join(' • ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voucher.code,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        voucher.title,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    valueText,
                    style: const TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(voucher.description, style: theme.textTheme.bodySmall),
            if (conditions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                conditions,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
            ],
            if (voucher.recommended) ...[
              const SizedBox(height: 8),
              _RecommendedBadge(),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/home'),
                  child: const Text('Khám phá khách sạn'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthRequiredException implements Exception {
  const _AuthRequiredException();
}

class _RecommendedBadge extends StatelessWidget {
  const _RecommendedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F0FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars, color: Color(0xFF1D4ED8), size: 16),
          SizedBox(width: 6),
          Text(
            'Đề xuất cho bạn',
            style: TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
