import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:intl/intl.dart';
import 'package:stayeasy/models/booking.dart';
import 'package:stayeasy/models/voucher.dart';
import 'package:stayeasy/services/api_service.dart';
import 'package:stayeasy/services/payment_service.dart';
import 'package:stayeasy/services/voucher_service.dart';
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
  final VoucherService _voucherService = VoucherService();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  String _method = 'online';
  bool _processing = false;
  bool _loadingVouchers = false;
  List<Voucher> _vouchers = [];
  Voucher? _selectedVoucher;
  double _discount = 0;

  Booking get _booking => widget.booking;
  double get _grossAmount => _booking.totalPrice;
  double get _netAmount => (_grossAmount - _discount).clamp(0, double.infinity);

  @override
  void initState() {
    super.initState();
    _initVouchers();
  }

  Future<void> _initVouchers() async {
    if (!AuthState.I.isLoggedIn) return;
    setState(() => _loadingVouchers = true);
    try {
      final vouchers = await _voucherService.listForCurrentUser();
      Voucher? initial;
      if (vouchers.isNotEmpty) {
        initial = vouchers.firstWhere(
          (v) => v.recommended,
          orElse: () => vouchers.first,
        );
      }
      setState(() {
        _vouchers = vouchers;
        _selectedVoucher = initial;
      });
      _recalculateDiscount();
    } catch (_) {
      setState(() {
        _vouchers = [];
        _selectedVoucher = null;
        _discount = 0;
      });
    } finally {
      if (mounted) setState(() => _loadingVouchers = false);
    }
  }



  String _formatCurrency(num value) => _currencyFormat.format(value);

  Future<void> _handleOfflinePayment() async {
    final result = await _paymentService.createPayment(
      bookingId: _booking.id,
      amount: _netAmount,
      method: 'cod',
      currency: 'vnd',
    );

    if (!mounted) return;
    final updatedBooking = _booking.copyWith(
      status: result.status ?? 'confirmed',
      totalAmount: result.amount ?? _netAmount,
    );
    Navigator.pushReplacementNamed(
      context,
      '/success',
      arguments: {
        'booking': updatedBooking,
        'payAmount': _netAmount,
        'payMethod': 'cod',
        'voucher': _selectedVoucher?.code,
      },
    );
  }

  Future<void> _handleStripePayment() async {
    final result = await _paymentService.createPayment(
      bookingId: _booking.id,
      amount: _netAmount,
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
        applePay: null,
      ),
    );

    await stripe.Stripe.instance.presentPaymentSheet();

    if (!mounted) return;
    final updatedBooking = _booking.copyWith(
      status: 'completed',
      totalAmount: _netAmount,
    );
    Navigator.pushReplacementNamed(
      context,
      '/success',
      arguments: {
        'booking': updatedBooking,
        'payAmount': _netAmount,
        'payMethod': 'stripe',
        'voucher': _selectedVoucher?.code,
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
        SnackBar(
          content: Text(e.error.localizedMessage ?? 'Thanh toán bị hủy.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thanh toán thất bại: ${e.toString()}')),
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
      appBar: AppBar(title: const Text('Thanh to�n')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.meeting_room),
              title: Text('Đơn đặt phòng #${_booking.id}'),
              subtitle: Text(
                '${_booking.hotelName} • Phòng ${_booking.roomNumber}',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(
                'Khách: ${customerName.isNotEmpty ? customerName : 'Khách vãng lai'}',
              ),
              subtitle: Text(
                'Sđt: ${customerPhone.isNotEmpty ? customerPhone : '-'}',
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
                  subtitle: 'Thẻ Visa/Master, Google Pay.',
                ),
                const Divider(height: 0),
                _optionTile(
                  value: 'cod',
                  title: 'Thanh toán tại khách sạn',
                  subtitle: 'Trả tiền khi nhận phòng.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_loadingVouchers)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Expanded(child: Text('Đang tải ưu đãi cho bạn...')),
                  ],
                ),
              ),
            )
          else if (_vouchers.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chọn voucher',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Voucher?>(
                      initialValue: _selectedVoucher,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Voucher khả dụng',
                      ),
                      items: [
                        const DropdownMenuItem<Voucher?>(
                          value: null,
                          child: Text('Không sử dụng voucher'),
                        ),
                        ..._vouchers.map(
                          (voucher) => DropdownMenuItem<Voucher?>(
                            value: voucher,
                            child: Text(
                              voucher.code,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedVoucher = value);
                        _recalculateDiscount();
                      },
                    ),
                    if (_selectedVoucher != null && _discount <= 0)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Voucher không đáp ứng điều kiện cho phương thức thực hiện hiện tại.',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _amountRow('Tổng tiền', _formatCurrency(_grossAmount)),
                  _amountRow(
                    'Giảm giá',
                    _discount > 0
                        ? '- ${_formatCurrency(_discount)}'
                        : _formatCurrency(0),
                    highlight: _discount > 0,
                  ),
                  const Divider(),
                  _amountRow(
                    'Thanh to�n',
                    _formatCurrency(_netAmount),
                    bold: true,
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
              icon: _method == 'online'
                  ? Icons.lock
                  : Icons.check_circle_outline,
            ),
        ],
      ),
    );
  }

  void _recalculateDiscount() {
    final voucher = _selectedVoucher;
    if (voucher == null) {
      setState(() => _discount = 0);
      return;
    }
    final raw = voucher.discountFor(
      total: _grossAmount.toInt(),
      payMethod: _method,
    );
    setState(() {
      _discount = raw.toDouble().clamp(0, _grossAmount);
    });
  }

  Widget _optionTile({
    required String value,
    required String title,
    required String subtitle,
  }) {
    final selected = _method == value;
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Colors.grey;
    return InkWell(
      onTap: () {
        setState(() => _method = value);
        _recalculateDiscount();
      },
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

  Widget _amountRow(
    String label,
    String value, {
    bool bold = false,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: highlight ? Colors.green : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
