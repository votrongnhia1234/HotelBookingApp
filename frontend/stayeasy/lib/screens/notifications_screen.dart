import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  static const _kPromoKey = 'pref_notify_promos';
  static const _kTxnKey = 'pref_notify_transactions';
  static const _kSystemKey = 'pref_notify_system';
  static const _kEmailKey = 'pref_notify_email';

  bool _promos = true;
  bool _transactions = true;
  bool _system = true;
  bool _email = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _promos = sp.getBool(_kPromoKey) ?? true;
      _transactions = sp.getBool(_kTxnKey) ?? true;
      _system = sp.getBool(_kSystemKey) ?? true;
      _email = sp.getBool(_kEmailKey) ?? false;
      _loading = false;
    });
  }

  Future<void> _save(String key, bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(key, value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu thiết lập thông báo')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        title: const Text('Khuyến mãi & ưu đãi'),
                        subtitle: const Text('Nhận thông báo về voucher và giá tốt'),
                        value: _promos,
                        onChanged: (v) async {
                          setState(() => _promos = v);
                          await _save(_kPromoKey, v);
                        },
                      ),
                      const Divider(height: 0),
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        title: const Text('Giao dịch & đơn đặt'),
                        subtitle: const Text('Xác nhận thanh toán, trạng thái đơn'),
                        value: _transactions,
                        onChanged: (v) async {
                          setState(() => _transactions = v);
                          await _save(_kTxnKey, v);
                        },
                      ),
                      const Divider(height: 0),
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        title: const Text('Hệ thống & bảo mật'),
                        subtitle: const Text('Đăng nhập mới, thay đổi mật khẩu'),
                        value: _system,
                        onChanged: (v) async {
                          setState(() => _system = v);
                          await _save(_kSystemKey, v);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: const Text('Nhận email'),
                    subtitle: const Text('Gửi email bên cạnh thông báo trong ứng dụng'),
                    value: _email,
                    onChanged: (v) async {
                      setState(() => _email = v);
                      await _save(_kEmailKey, v);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}