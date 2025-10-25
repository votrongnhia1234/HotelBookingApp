import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  static const _kDefaultKey = 'pref_default_payment_method';
  static const _kAskEveryTimeKey = 'pref_ask_every_time';
  static const _kApplePayKey = 'pref_applepay_enabled';
  static const _kGooglePayKey = 'pref_gpay_enabled';

  String _defaultMethod = 'online';
  bool _askEveryTime = true;
  bool _applePay = true;
  bool _googlePay = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    final def = sp.getString(_kDefaultKey);
    final ask = sp.getBool(_kAskEveryTimeKey);
    final ap = sp.getBool(_kApplePayKey);
    final gp = sp.getBool(_kGooglePayKey);
    setState(() {
      _defaultMethod = (def == 'online' || def == 'cod' || def == 'bank') ? def! : 'online';
      _askEveryTime = ask ?? true;
      _applePay = ap ?? true;
      _googlePay = gp ?? true;
      _loading = false;
    });
  }

  Future<void> _saveDefault(String value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kDefaultKey, value);
    setState(() => _defaultMethod = value);
    _showSaved();
  }

  Future<void> _saveBool(String key, bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(key, value);
    _showSaved();
  }

  void _showSaved() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu thiết lập thanh toán')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phương thức thanh toán')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Phương thức mặc định', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _radioItem('online', 'Thanh toán online', 'Thẻ/Ví điện tử qua Stripe, Apple/Google Pay'),
                        const Divider(height: 0),
                        _radioItem('cod', 'Thanh toán tại khách sạn', 'Trả tiền khi nhận phòng'),
                        const Divider(height: 0),
                        _radioItem('bank', 'Chuyển khoản ngân hàng', 'Thực hiện chuyển khoản theo hướng dẫn'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        title: const Text('Bật Apple Pay'),
                        subtitle: const Text('Hiển thị trong màn thanh toán khi khả dụng'),
                        value: _applePay,
                        onChanged: (v) => setState(() => _applePay = v),
                        onFocusChange: (_) {},
                      ),
                      const Divider(height: 0),
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        title: const Text('Bật Google Pay'),
                        subtitle: const Text('Hiển thị trong màn thanh toán khi khả dụng'),
                        value: _googlePay,
                        onChanged: (v) => setState(() => _googlePay = v),
                      ),
                      ButtonBar(
                        children: [
                          TextButton(
                            onPressed: () async {
                              await _saveBool(_kApplePayKey, _applePay);
                              await _saveBool(_kGooglePayKey, _googlePay);
                            },
                            child: const Text('Lưu ví điện tử'),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: const Text('Hỏi mỗi lần thanh toán'),
                    subtitle: const Text('Luôn hiển thị lựa chọn thay vì dùng mặc định'),
                    value: _askEveryTime,
                    onChanged: (v) async {
                      setState(() => _askEveryTime = v);
                      await _saveBool(_kAskEveryTimeKey, v);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _radioItem(String value, String title, String subtitle) {
    final selected = _defaultMethod == value;
    return InkWell(
      onTap: () => _saveDefault(value),
      child: ListTile(
        leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? Theme.of(context).colorScheme.primary : Colors.grey),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: selected
            ? const Chip(label: Text('Mặc định'))
            : null,
      ),
    );
  }
}