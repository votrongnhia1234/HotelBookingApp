import 'package:flutter/material.dart';

import '../models/user.dart';
import '../state/auth_state.dart';
import '../widgets/custom_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthState.I,
      builder: (_, __) {
        final user = AuthState.I.currentUser;
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FB),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => AuthState.I.loadFromStorage(),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _Header(user: user),
                  const SizedBox(height: 16),
                  if (user == null)
                    const _GuestSections()
                  else
                    _MemberSections(user: user),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final isGuest = user == null;
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFF2EC),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: Row(
        children: [
          Container(
            height: 72,
            width: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFFFD9C7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGuest ? Icons.person_outline : Icons.emoji_people,
              size: 36,
              color: const Color(0xFFB85A35),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGuest ? 'Đăng nhập/ Đăng ký' : user!.name,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  isGuest
                      ? 'Giữ lịch sử đặt phòng và nhận ưu đãi dành riêng cho bạn.'
                      : user!.phone,
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                ),
                if (!isGuest && user!.role.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _roleLabel(user!.role),
                      style: const TextStyle(
                        color: Color(0xFF1E88E5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (isGuest) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: CustomButton(
                      label: 'Đăng nhập ngay',
                      icon: Icons.login,
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                    ),
                  ),
                ],
              ],
            ),
          )
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Quản trị viên';
      case 'hotel_manager':
        return 'Đối tác khách sạn';
      default:
        return 'Khách hàng';
    }
  }
}

class _GuestSections extends StatelessWidget {
  const _GuestSections();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: const [
          _GuestBenefitCard(),
          SizedBox(height: 16),
          _SettingsGroup(
            title: 'Cài đặt',
            items: [
              _SettingsItem(icon: Icons.notifications_none, label: 'Thông báo'),
              _SettingsItem(icon: Icons.translate, label: 'Ngôn ngữ', value: 'Tiếng Việt'),
              _SettingsItem(icon: Icons.place_outlined, label: 'Khu vực', value: 'TP.HCM'),
            ],
          ),
          SizedBox(height: 16),
          _SettingsGroup(
            title: 'Thông tin',
            items: [
              _SettingsItem(icon: Icons.help_outline, label: 'Hỏi đáp'),
              _SettingsItem(icon: Icons.privacy_tip_outlined, label: 'Điều khoản & Chính sách'),
              _SettingsItem(icon: Icons.phone_in_talk_outlined, label: 'Liên hệ'),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuestBenefitCard extends StatelessWidget {
  const _GuestBenefitCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Lợi ích khi đăng nhập', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            SizedBox(height: 12),
            _BenefitRow(text: 'Quản lý chuyến đi và giữ lịch sử đặt phòng.'),
            _BenefitRow(text: 'Nhận ưu đãi độc quyền, voucher dành riêng cho bạn.'),
            _BenefitRow(text: 'Lưu thông tin khách để đặt phòng nhanh hơn.'),
          ],
        ),
      ),
    );
  }
}

class _MemberSections extends StatelessWidget {
  const _MemberSections({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: const [
                _SettingsItem(icon: Icons.person_outline, label: 'Thông tin cá nhân'),
                Divider(height: 0),
                _SettingsItem(icon: Icons.payment, label: 'Phương thức thanh toán'),
                Divider(height: 0),
                _SettingsItem(icon: Icons.favorite_outline, label: 'Danh sách yêu thích'),
                Divider(height: 0),
                _SettingsItem(icon: Icons.receipt_long_outlined, label: 'Lịch sử giao dịch'),
              ],
            ),
          ),
          if (AuthState.I.isAdmin || AuthState.I.isHotelManager) ...[
            _SettingsGroup(
              title: 'Bảng điều khiển',
              items: [
                if (AuthState.I.isAdmin)
                  _SettingsItem(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Dashboard quản trị',
                    onTap: () => Navigator.pushNamed(context, '/admin-dashboard'),
                  ),
                if (AuthState.I.isHotelManager)
                  _SettingsItem(
                    icon: Icons.analytics_outlined,
                    label: 'Số liệu đối tác',
                    onTap: () => Navigator.pushNamed(context, '/partner-dashboard'),
                  ),
                _SettingsItem(
                  icon: Icons.meeting_room_outlined,
                  label: 'Quan ly phong',
                  onTap: () => Navigator.pushNamed(context, '/manage-rooms'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const _SettingsGroup(
            title: 'Cài đặt',
            items: [
              _SettingsItem(icon: Icons.notifications_none, label: 'Thông báo'),
              _SettingsItem(icon: Icons.translate, label: 'Ngôn ngữ', value: 'Tiếng Việt'),
              _SettingsItem(icon: Icons.place_outlined, label: 'Khu vực', value: 'TP.HCM'),
            ],
          ),
          const SizedBox(height: 16),
          const _SettingsGroup(
            title: 'Hỗ trợ',
            items: [
              _SettingsItem(icon: Icons.help_outline, label: 'Hỏi đáp'),
              _SettingsItem(icon: Icons.privacy_tip_outlined, label: 'Điều khoản & Chính sách'),
              _SettingsItem(icon: Icons.phone_in_talk_outlined, label: 'Liên hệ'),
            ],
          ),
          const SizedBox(height: 20),
          CustomButton(
            label: 'Đăng xuất',
            icon: Icons.logout,
            onPressed: () async {
              await AuthState.I.logout();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bạn đã đăng xuất.')),
                );
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF1E88E5), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.items});

  final String title;
  final List<_SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                items[i],
                if (i != items.length - 1) const Divider(height: 0),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({required this.icon, required this.label, this.value, this.onTap});

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: value != null
          ? Text(value!, style: const TextStyle(color: Colors.black45))
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
