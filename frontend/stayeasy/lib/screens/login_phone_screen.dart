import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/custom_button.dart';

enum LoginStep { phone, otp }

class LoginPhoneScreen extends StatefulWidget {
  const LoginPhoneScreen({super.key});

  @override
  State<LoginPhoneScreen> createState() => _LoginPhoneScreenState();
}

class _LoginPhoneScreenState extends State<LoginPhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _authService = AuthService();

  LoginStep _step = LoginStep.phone;
  String? _verificationId;
  int? _resendToken;
  bool _loading = false;
  bool _googleLoading = false;
  String _phone = '';
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final phone = value?.replaceAll(' ', '') ?? '';
    if (phone.isEmpty) return 'Vui lòng nhập số điện thoại';
    if (!phone.startsWith('+')) return 'Nhập cả mã quốc gia, ví dụ +84...';
    if (phone.length < 10) return 'Số điện thoại chưa hợp lệ';
    return null;
  }

  void _showError(String message) {
    setState(() {
      _error = message;
      _loading = false;
      _googleLoading = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Lỗi: $message')));
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _phoneController.text.replaceAll(' ', '');
    setState(() {
      _loading = true;
      _error = null;
    });

    await _authService.sendOtp(
      phone: phone,
      onCodeSent: (verificationId, resendToken) {
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _phone = phone;
          _step = LoginStep.otp;
          _loading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Đã gửi mã OTP tới $phone')));
      },
      onError: _showError,
      onAutoVerified: () {
        if (!mounted) return;
        setState(() => _loading = false);
        Navigator.pop(context, true);
      },
    );
  }

  Future<void> _confirmOtp() async {
    final otp = _otpController.text.trim();
    if (_verificationId == null || otp.length < 6) {
      _showError('Nhập mã OTP gồm 6 chữ số.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.confirmOtp(verificationId: _verificationId!, otp: otp);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đăng nhập thành công')));
      Navigator.pop(context, true);
    } catch (e) {
      _showError('$e');
    }
  }

  Future<void> _resendOtp() async {
    if (_phone.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    await _authService.sendOtp(
      phone: _phone,
      onCodeSent: (verificationId, resendToken) {
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _loading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã gửi lại OTP')));
      },
      onError: _showError,
      onAutoVerified: () {
        if (!mounted) return;
        setState(() => _loading = false);
        Navigator.pop(context, true);
      },
      resendToken: _resendToken,
    );
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      final user = await _authService.loginWithGoogle();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đăng nhập thành công')));
      // If user email isn't verified (some flows may send verification), inform user
      Navigator.pop(context, true);
    } catch (e) {
      _showError('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final headline = _step == LoginStep.phone
        ? 'Nhập số điện thoại để nhận mã OTP.'
        : 'Nhập mã gồm 6 chữ số đã gửi tới $_phone.';

    final helper = _step == LoginStep.phone
        ? 'Gợi ý: với môi trường thử nghiệm, hãy cấu hình số điện thoại test trong Firebase Authentication. '
              'Nếu dùng số thật, bạn cần bật thanh toán (Blaze) cho Phone Auth.'
        : 'Nếu chưa nhận được mã, hãy bấm "Gửi lại mã" sau khoảng 60 giây.';

    return Scaffold(
      appBar: AppBar(
        title: Text(_step == LoginStep.phone ? 'Đăng nhập' : 'Nhập mã OTP'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(headline, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(helper, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            if (_step == LoginStep.phone) ...[
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại (+84...)',
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: _validatePhone,
              ),
              const SizedBox(height: 24),
              CustomButton(
                label: 'Gửi mã OTP',
                icon: Icons.sms,
                loading: _loading,
                onPressed: _loading ? null : _sendOtp,
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Hoặc'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              CustomButton(
                label: 'Đăng nhập với Google',
                icon: Icons.g_mobiledata,
                loading: _googleLoading,
                onPressed: _googleLoading ? null : _loginWithGoogle,
              ),
            ] else ...[
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Mã OTP',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : _resendOtp,
                child: const Text('Gửi lại mã'),
              ),
              const SizedBox(height: 16),
              CustomButton(
                label: 'Xác nhận',
                icon: Icons.verified_user,
                loading: _loading,
                onPressed: _loading ? null : _confirmOtp,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
    );
  }
}
