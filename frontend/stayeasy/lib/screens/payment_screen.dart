import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:intl/intl.dart';
import 'package:stayeasy/models/booking.dart';
import 'package:stayeasy/models/voucher.dart';
import 'package:stayeasy/services/api_service.dart';
import 'package:stayeasy/services/payment_service.dart';
import 'package:stayeasy/services/voucher_service.dart';
import 'package:stayeasy/state/auth_state.dart';
import 'package:stayeasy/widgets/custom_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stayeasy/models/user.dart';
import 'package:stayeasy/config/stripe_config.dart';

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
  stripe.CardFieldInputDetails? _card;
  bool _applePayEnabled = true;
  bool _googlePayEnabled = true;

  Booking get _booking => widget.booking;
  double get _grossAmount => _booking.totalPrice;
  double get _netAmount => (_grossAmount - _discount).clamp(0, double.infinity);

  @override
  void initState() {
    super.initState();
    _initVouchers();
    _loadDefaultPaymentMethod();
  }

  Future<void> _loadDefaultPaymentMethod() async {
    try {
      final sp = await SharedPreferences.getInstance();
      // Load toggles for ví điện tử dù người dùng có chọn hỏi mỗi lần hay không
      final apEnabled = sp.getBool('pref_applepay_enabled') ?? true;
      final gpEnabled = sp.getBool('pref_gpay_enabled') ?? true;
      if (mounted) {
        setState(() {
          _applePayEnabled = apEnabled;
          _googlePayEnabled = gpEnabled;
        });
      }
      final askEveryTime = sp.getBool('pref_ask_every_time') ?? true;
      if (!askEveryTime) {
        final def = sp.getString('pref_default_payment_method');
        if (def == 'online' || def == 'cod' || def == 'bank') {
          if (mounted) {
            setState(() => _method = def!);
            _recalculateDiscount();
          }
        }
      }
    } catch (_) {
      // ignore prefs errors silently
    }
  }

  Future<void> _initVouchers() async {
    setState(() => _loadingVouchers = true);
    try {
      final all = await _voucherService.listForCurrentUser();
      final nights = _nightsFromRange();
      final total = _grossAmount.toInt();
      final list = all.where((v) {
        if (v.nightsRequired != null && nights < v.nightsRequired!)
          return false;
        if (v.minOrder != null && total < v.minOrder!) return false;
        return true;
      }).toList();
      if (mounted) {
        setState(() {
          _vouchers = list;
          _recalculateDiscount();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _vouchers = []);
    } finally {
      if (mounted) setState(() => _loadingVouchers = false);
    }
  }

  Future<void> _handleStripePayment() async {
    final result = await _paymentService.createPayment(
      bookingId: _booking.id,
      amount: _netAmount,
      method: 'online',
      currency: 'vnd',
    );

    final clientSecret = result.clientSecret;
    if (clientSecret == null || clientSecret.isEmpty) {
      throw Exception('Không thể khởi tạo phiên thanh toán Stripe.');
    }

    try {
      // Chỉ bật ví điện tử khi phù hợp với nền tảng và cấu hình
      final isAndroid =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
      final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

      // Đảm bảo merchantIdentifier được set trước khi bật Apple Pay
      final hasMerchantId = StripeConfig.merchantIdentifier.isNotEmpty;
      if (hasMerchantId) {
        try {
          stripe.Stripe.merchantIdentifier = StripeConfig.merchantIdentifier;
        } catch (_) {
          // bỏ qua nếu nền tảng không hỗ trợ
        }
      }

      final canUseGooglePay = _googlePayEnabled && isAndroid;
      final canUseApplePay = _applePayEnabled && isIOS && hasMerchantId;

      stripe.PaymentSheetGooglePay? gpay;
      if (canUseGooglePay) {
        gpay = stripe.PaymentSheetGooglePay(
          merchantCountryCode: StripeConfig.merchantCountryCode,
          currencyCode: StripeConfig.currencyCode,
          testEnv: StripeConfig.googlePayTestEnv,
        );
      }

      stripe.PaymentSheetApplePay? apay;
      if (canUseApplePay) {
        apay = stripe.PaymentSheetApplePay(
          merchantCountryCode: StripeConfig.merchantCountryCode,
        );
      }

      await stripe.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: stripe.SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'StayEasy',
          style: ThemeMode.system,
          googlePay: gpay,
          applePay: apay,
        ),
      );

      await stripe.Stripe.instance.presentPaymentSheet();
    } on stripe.StripeException catch (_) {
      // Fallback: hiển thị UI nhập thẻ và xác nhận thủ công (web/không hỗ trợ).
      final ok = await _showStripeCardEntry(clientSecret);
      if (!ok) {
        throw PlatformException(
          code: 'canceled',
          message: 'Thanh toán bị hủy.',
        );
      }
    }

    // Chỉ xác nhận backend khi thanh toán đã hoàn tất thành công.
    await _paymentService.confirmDemo(
      bookingId: _booking.id,
      amount: _netAmount,
      currency: 'vnd',
    );

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
        'payMethod': 'online',
        'voucher': _selectedVoucher?.code,
      },
    );
  }

  Future<void> _handleOfflinePayment({required String method}) async {
    final result = await _paymentService.createPayment(
      bookingId: _booking.id,
      amount: _netAmount,
      method: method,
      currency: 'vnd',
    );

    if (!mounted) return;
    final updatedBooking = _booking.copyWith(
      status: result.status ?? (method == 'cod' ? 'confirmed' : 'pending'),
      totalAmount: result.amount ?? _netAmount,
    );
    Navigator.pushReplacementNamed(
      context,
      '/success',
      arguments: {
        'booking': updatedBooking,
        'payAmount': _netAmount,
        'payMethod': method,
        'voucher': _selectedVoucher?.code,
      },
    );
  }

  Future<bool> _showPayerForm() async {
    final user = AuthState.I.currentUser;
    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final emailCtrl = TextEditingController(text: user?.email ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');
    final formKey = GlobalKey<FormState>();

    bool? ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thông tin người thanh toán',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập họ tên'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'Vui lòng nhập email';
                    if (!s.contains('@')) return 'Email không hợp lệ';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                  ],
                  validator: (v) => (v == null || v.trim().length < 8)
                      ? 'Số điện thoại chưa đúng'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Tiếp tục thanh toán'),
                        onPressed: () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          // Lưu lại vào phiên để dùng về sau (cục bộ)
                          if (user != null) {
                            final updated = User(
                              id: user.id,
                              name: nameCtrl.text.trim(),
                              email: emailCtrl.text.trim(),
                              phone: phoneCtrl.text.trim(),
                              role: user.role,
                            );
                            await AuthState.I.updateUser(updated);
                          }
                          // Đóng sheet, tiếp tục thanh toán
                          if (ctx.mounted) Navigator.of(ctx).pop(true);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return ok == true;
  }

  Future<void> _makePayment() async {
    setState(() => _processing = true);
    try {
      if (_method == 'online') {
        // Thu thập thông tin người thanh toán trước khi thực hiện online
        final ok = await _showPayerForm();
        if (!ok) {
          if (mounted) setState(() => _processing = false);
          return;
        }
        await _handleStripePayment();
      } else {
        await _handleOfflinePayment(method: _method);
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

  String _formatCurrency(num value) => _currencyFormat.format(value);

  Widget _amountRow(
    String label,
    String value, {
    bool bold = false,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: highlight ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _booking.hotelName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_booking.roomType} • Phòng ${_booking.roomNumber}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                      Chip(
                        label: Text(_formatCurrency(_grossAmount)),
                        backgroundColor: colorScheme.primaryContainer,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _optionTile(
                  value: 'online',
                  title: 'Thanh toán online',
                  subtitle: 'Thẻ/Ví điện tử qua Stripe, Apple/Google Pay.',
                ),
                const Divider(height: 0),
                _optionTile(
                  value: 'cod',
                  title: 'Thanh toán tại khách sạn',
                  subtitle: 'Trả tiền khi nhận phòng.',
                ),
                const Divider(height: 0),
                _optionTile(
                  value: 'bank',
                  title: 'Chuyển khoản ngân hàng',
                  subtitle: 'Thực hiện chuyển khoản theo hướng dẫn.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_method == 'bank') _buildBankTransferCard(),
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
                      'Ưu đãi khả dụng',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _vouchers.map((v) {
                        final selected = _selectedVoucher?.id == v.id;
                        return ChoiceChip(
                          selected: selected,
                          label: Text('${v.title} (${v.code})'),
                          onSelected: (_) {
                            setState(
                              () => _selectedVoucher = selected ? null : v,
                            );
                            _recalculateDiscount();
                          },
                        );
                      }).toList(),
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
                    'Thanh toán',
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
              label: _method == 'online'
                  ? 'Thanh toán'
                  : (_method == 'bank' ? 'Tạo yêu cầu' : 'Hoàn tất'),
              onPressed: _makePayment,
              icon: _method == 'online'
                  ? Icons.lock
                  : (_method == 'bank'
                        ? Icons.account_balance
                        : Icons.check_circle_outline),
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

  Widget _buildBankTransferCard() {
    final bankAccount = '0123456789';
    final bankName = 'Vietcombank';
    final ownerName = 'CTY TNHH STAYEASY';
    final content = 'PAY ${_booking.id} USER ${_booking.userId}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin chuyển khoản',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _infoRowInline('Ngân hàng', bankName),
            _infoRowInline('Số tài khoản', bankAccount),
            _infoRowInline('Chủ tài khoản', ownerName),
            _infoRowInline('Nội dung', content),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text: '$bankName\n$bankAccount\n$ownerName\n$content',
                      ),
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã sao chép thông tin ngân hàng'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Sao chép'),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Sau khi chuyển khoản, nhấn “Tạo yêu cầu” để hệ thống ghi nhận và chờ xác nhận.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRowInline(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // Bottom-sheet nhập thẻ Stripe cho web/unsupported platforms.
  Future<bool> _showStripeCardEntry(String clientSecret) async {
    final user = AuthState.I.currentUser;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thông tin thẻ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              stripe.CardField(
                autofocus: true,
                onCardChanged: (details) {
                  _card = details;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Xác nhận thanh toán'),
                      onPressed: () async {
                        try {
                          final billing = stripe.BillingDetails(
                            name: user?.name,
                            email: user?.email,
                            phone: user?.phone,
                            address: const stripe.Address(
                              country: 'VN',
                              state: 'Ho Chi Minh',
                              postalCode: '700000',
                              line1: 'N/A',
                              line2: '',
                              city: 'Ho Chi Minh',
                            ),
                          );
                          await stripe.Stripe.instance.confirmPayment(
                            paymentIntentClientSecret: clientSecret,
                            data: stripe.PaymentMethodParams.card(
                              paymentMethodData: stripe.PaymentMethodData(
                                billingDetails: billing,
                              ),
                            ),
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop(true);
                        } on stripe.StripeException catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                e.error.localizedMessage ??
                                    'Thanh toán bị hủy.',
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Thanh toán thất bại: ${e.toString()}',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    return ok == true;
  }

  int _nightsFromRange() {
    final start = DateTime.tryParse(_booking.checkIn);
    final end = DateTime.tryParse(_booking.checkOut);
    if (start == null || end == null) return 1;
    final diff = end.difference(start).inDays;
    return diff > 0 ? diff : 1;
  }

  void _recalculateDiscount() {
    final v = _selectedVoucher;
    int amount = 0;
    if (v != null) {
      amount = v.discountFor(total: _grossAmount.toInt(), payMethod: _method);
    }
    setState(() => _discount = amount.toDouble());
  }
}
