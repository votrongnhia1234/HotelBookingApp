import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:intl/intl.dart';
import 'package:stayeasy/models/booking.dart';
import 'package:stayeasy/services/api_service.dart';
import 'package:stayeasy/services/payment_service.dart';
import 'package:stayeasy/state/auth_state.dart';
import 'package:stayeasy/widgets/custom_button.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.booking});

  final Booking booking;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentService _paymentService = PaymentService(ApiService());
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  String _method = 'online';
  bool _processing = false;

  Booking get _booking => widget.booking;

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      return DateFormat('dd/MM/yyyy').format(parsed);
    }
    final parts = raw.split(' ');
    return parts.first;
  }

  String _formatCurrency(num value) => _currencyFormat.format(value);

  Future<void> _handleOfflinePayment() async {
    final result = await _paymentService.createPayment(
      bookingId: _booking.id,
      amount: _booking.totalPrice,
      method: 'cod',
      currency: 'vnd',
    );

    if (!mounted) return;
    final updatedBooking = _booking.copyWith(
      status: result.status ?? 'confirmed',
      totalAmount: result.amount ?? _booking.totalAmount,
    );
    Navigator.pushReplacementNamed(
      context,
      '/success',
      arguments: {
        'booking': updatedBooking,
        'payAmount': updatedBooking.totalPrice,
        'payMethod': 'cod',
        'voucher': null,
      },
    );
  }

  Future<void> _handleStripePayment() async {
    final result = await _paymentService.createPayment(
      bookingId: _booking.id,
      amount: _booking.totalPrice,
      method: 'online',
      currency: 'vnd',
    );

    final clientSecret = result.clientSecret;
    if (clientSecret == null) {
      throw Exception('Không nhận được client secret từ máy chủ.');
    }

    await stripe.Stripe.instance.initPaymentSheet(
      paymentSheetParameters: stripe.SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'StayEasy',
        style: ThemeMode.system,
        googlePay: const stripe.PaymentSheetGooglePay(
          merchantCountryCode: 'US',
          currencyCode: 'VND',
          testEnv: true,
        ),
        // Apple Pay yêu cầu merchant identifier, tạm thời tắt để tránh crash khi chưa cấu hình.
        applePay: null,
      ),
    );

    await stripe.Stripe.instance.presentPaymentSheet();

    if (!mounted) return;
    final updatedBooking = _booking.copyWith(status: 'completed');
    Navigator.pushReplacementNamed(
      context,
      '/success',
      arguments: {
        'booking': updatedBooking,
        'payAmount': _booking.totalPrice,
        'payMethod': 'stripe',
        'voucher': null,
      },
    );
  }

  Future<void> _makePayment() async {
    setState(() => _processing = true);
    try {
      if (_method == 'online') {
        await _handleStripePayment();
      } else {
        await _handleOfflinePayment();
      }
    } on stripe.StripeException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.error.localizedMessage ?? 'Thanh toán bị hủy.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thanh toán thất bại: $e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthState.I.currentUser;
    final customerName = (user?.name ?? '').trim();
    final customerPhone = (user?.phone ?? '').trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.meeting_room),
              title: Text('Đơn đặt phòng #${_booking.id}'),
              subtitle: Text(
                '${_formatDate(_booking.checkIn)} → ${_formatDate(_booking.checkOut)}',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text('Khách: ${customerName.isEmpty ? 'Chưa cập nhật' : customerName}'),
              subtitle: Text(
                'Số điện thoại: ${customerPhone.isEmpty ? 'Chưa cập nhật' : customerPhone}',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _optionTile(
                  value: 'online',
                  title: 'Thanh toán trực tuyến',
                  subtitle: 'Thẻ Visa/Master, Apple Pay, Google Pay…',
                ),
                const Divider(height: 0),
                _optionTile(
                  value: 'cod',
                  title: 'Thanh toán tại khách sạn',
                  subtitle: 'Trả tiền khi nhận phòng',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng tiền',
                    style: TextStyle(color: Colors.black54, fontSize: 16),
                  ),
                  Text(
                    _formatCurrency(_booking.totalPrice),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_processing)
            const Center(child: CircularProgressIndicator())
          else
            CustomButton(
              label: _method == 'online' ? 'Thanh toán' : 'Hoàn tất',
              onPressed: _makePayment,
              icon: _method == 'online' ? Icons.lock : Icons.check_circle_outline,
            ),
        ],
      ),
    );
  }

  Widget _optionTile({
    required String value,
    required String title,
    required String subtitle,
  }) {
    final selected = _method == value;
    final color = selected ? Theme.of(context).colorScheme.primary : Colors.grey;
    return InkWell(
      onTap: () => setState(() => _method = value),
      child: ListTile(
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: color,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
