import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../state/auth_state.dart';
import '../utils/api_data_parser.dart';
import 'api_service.dart';

typedef OtpSentCallback =
    void Function(String verificationId, int? resendToken);

class AuthService {
  AuthService() : _firebase = fb.FirebaseAuth.instance;

  final ApiService _api = ApiService();
  final fb.FirebaseAuth _firebase;

  String _describeFirebaseError(fb.FirebaseAuthException e) {
    switch (e.code.toLowerCase()) {
      case 'invalid-phone-number':
        return 'Số điện thoại không hợp lệ. Nhập đúng định dạng có mã quốc gia (vd: +84...).';
      case 'quota-exceeded':
        return 'Dự án đã vượt hạn mức gửi OTP. Hãy thử lại sau hoặc dùng số thử nghiệm trong Firebase.';
      case 'too-many-requests':
        return 'Bạn đã gửi quá nhiều yêu cầu. Vui lòng thử lại sau ít phút.';
      case 'network-request-failed':
        return 'Không thể kết nối tới máy chủ. Kiểm tra lại Internet.';
      case 'billing-not-enabled':
        return 'Phone Auth cần bật thanh toán trên Firebase để dùng số thật. Hãy dùng “Test phone number” hoặc nâng gói Billing.';
      case 'app-not-authorized':
        return 'Ứng dụng chưa cấu hình đúng SHA-1/SHA-256 trong Firebase console.';
      default:
        return e.message ?? 'Không thể gửi OTP. Vui lòng thử lại.';
    }
  }

  Future<User> loginPhone({
    required String phone,
    required String password,
  }) async {
    final attempts =
        <({String path, Map<String, dynamic> body, String tokenKey})>[
          (
            path: '/auth/login-phone',
            body: {'phone': phone, 'password': password},
            tokenKey: 'token',
          ),
          (
            path: '/auth/login',
            body: {'phone': phone, 'password': password},
            tokenKey: 'token',
          ),
          (
            path: '/login',
            body: {'phone': phone, 'password': password},
            tokenKey: 'token',
          ),
        ];

    Object? lastErr;
    for (final attempt in attempts) {
      try {
        final raw = await _api.post(attempt.path, attempt.body);
        final parsed = ApiDataParser.map(raw);
        final data = Map<String, dynamic>.from(parsed['data'] ?? parsed);

        final token =
            (data[attempt.tokenKey] ?? data['accessToken'] ?? data['jwt'] ?? '')
                .toString();
        final userMap = Map<String, dynamic>.from(
          data['user'] ?? data['profile'] ?? data,
        );
        final user = User.fromJson(userMap);

        await AuthState.I.setSession(user: user, jwt: token);
        return user;
      } catch (e) {
        lastErr = e;
      }
    }
    throw lastErr ?? Exception('Không thể đăng nhập');
  }

  Future<void> sendOtp({
    required String phone,
    required OtpSentCallback onCodeSent,
    required void Function(String message) onError,
    required VoidCallback onAutoVerified,
    int? resendToken,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    await _firebase.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: timeout,
      forceResendingToken: resendToken,
      verificationCompleted: (fb.PhoneAuthCredential credential) async {
        await _firebase.signInWithCredential(credential);
        onAutoVerified();
      },
      verificationFailed: (fb.FirebaseAuthException e) {
        onError(_describeFirebaseError(e));
      },
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<User> confirmOtp({
    required String verificationId,
    required String otp,
  }) async {
    fb.UserCredential userCred;
    try {
      final credential = fb.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      userCred = await _firebase.signInWithCredential(credential);
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(_describeFirebaseError(e));
    }

    final idToken = await userCred.user?.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Không lấy được token từ Firebase');
    }

    final response = await _api.post('/auth/firebase', {'idToken': idToken});
    final parsed = ApiDataParser.map(response);
    final payload = parsed['data'] ?? parsed;

    Map<String, dynamic> toMap(dynamic node) {
      if (node is Map<String, dynamic>) return Map<String, dynamic>.from(node);
      if (node is Map) {
        final converted = <String, dynamic>{};
        node.forEach((key, value) {
          converted[key.toString()] = value;
        });
        return converted;
      }
      return {};
    }

    String findToken(dynamic node) {
      if (node is Map || node is Map<String, dynamic>) {
        final map = toMap(node);
        for (final key in const [
          'token',
          'jwt',
          'accessToken',
          'access_token',
        ]) {
          final value = map[key];
          if (value != null && value.toString().isNotEmpty) {
            return value.toString();
          }
        }
        for (final value in map.values) {
          final candidate = findToken(value);
          if (candidate.isNotEmpty) {
            return candidate;
          }
        }
      } else if (node is List) {
        for (final value in node) {
          final candidate = findToken(value);
          if (candidate.isNotEmpty) return candidate;
        }
      }
      return '';
    }

    Map<String, dynamic> findUser(dynamic node) {
      if (node is Map || node is Map<String, dynamic>) {
        final map = toMap(node);
        final loweredKeys = map.keys.map((e) => e.toLowerCase()).toSet();
        if (loweredKeys.contains('id') &&
            (loweredKeys.contains('name') ||
                loweredKeys.contains('fullname') ||
                loweredKeys.contains('username')) &&
            (loweredKeys.contains('phone') ||
                loweredKeys.contains('phonenumber') ||
                loweredKeys.contains('email'))) {
          return map;
        }
        for (final key in const ['user', 'profile', 'customer', 'account']) {
          final candidate = findUser(map[key]);
          if (candidate.isNotEmpty) return candidate;
        }
        for (final value in map.values) {
          final candidate = findUser(value);
          if (candidate.isNotEmpty) return candidate;
        }
      } else if (node is List) {
        for (final value in node) {
          final candidate = findUser(value);
          if (candidate.isNotEmpty) return candidate;
        }
      }
      return {};
    }

    final token = findToken(payload);
    final userMap = findUser(payload);

    if (token.isEmpty || userMap.isEmpty) {
      throw Exception('Không lấy được thông tin đăng nhập hợp lệ từ máy chủ.');
    }

    final appUser = User.fromJson(userMap);
    await AuthState.I.setSession(user: appUser, jwt: token);
    return appUser;
  }

  Future<void> signOut() async {
    await _firebase.signOut();
    await AuthState.I.logout();
  }
}
