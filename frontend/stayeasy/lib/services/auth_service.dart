import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart' as gs;

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
          if (candidate.isNotEmpty) return candidate;
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
    // Sign out Firebase
    await _firebase.signOut();
    // Also sign out Google account if present to avoid cached sessions
    try {
      final googleSignIn = gs.GoogleSignIn();
      await googleSignIn.disconnect();
    } catch (_) {}
    await AuthState.I.logout();
  }

  /// Sign in using Google account and exchange Firebase idToken with backend.
  Future<User> loginWithGoogle() async {
    try {
      fb.UserCredential userCred;

      if (kIsWeb) {
        // Web: use Firebase popup directly to avoid People API dependency
        final provider = fb.GoogleAuthProvider();
        try {
          userCred = await _firebase.signInWithPopup(provider);
        } on fb.FirebaseAuthException catch (e) {
          // Fallback when popup is blocked/closed or environment unsupported
          final code = e.code.toLowerCase();
          if (code.contains('popup') ||
              code == 'operation-not-supported-in-this-environment') {
            await _firebase.signInWithRedirect(provider);
            final redirectResult = await _firebase.getRedirectResult();
            if (redirectResult.user == null) {
              throw Exception('Đăng nhập Google không thành công (redirect).');
            }
            userCred = redirectResult;
          } else {
            rethrow;
          }
        }
      } else {
        // Mobile: keep google_sign_in flow
        final googleSignIn = gs.GoogleSignIn();
        final account = await googleSignIn.signIn();
        if (account == null) {
          throw Exception('Người dùng đã hủy đăng nhập Google.');
        }

        final googleAuth = await account.authentication;
        final idToken = googleAuth.idToken;
        final accessToken = googleAuth.accessToken;
        if (idToken == null || idToken.isEmpty) {
          throw Exception('Không lấy được idToken từ Google Sign-In.');
        }

        // Sign in to Firebase with the Google credentials
        final credential = fb.GoogleAuthProvider.credential(
          idToken: idToken,
          accessToken: accessToken,
        );
        userCred = await _firebase.signInWithCredential(credential);
      }

      // If user's email is not verified (rare for Google), attempt to send verification
      try {
        final fb.User? fu = userCred.user;
        if (fu != null && !(fu.emailVerified)) {
          await fu.sendEmailVerification();
        }
      } catch (_) {
        // ignore send email errors
      }

      // Exchange Firebase idToken with backend to create/get application session
      final token = await userCred.user?.getIdToken(true);
      if (token == null || token.isEmpty) {
        throw Exception('Không lấy được token từ Firebase');
      }

      final response = await _api.post('/auth/firebase', {'idToken': token});
      final parsed = ApiDataParser.map(response);
      final payload = parsed['data'] ?? parsed;

      Map<String, dynamic> toMap(dynamic node) {
        if (node is Map<String, dynamic>) {
          return Map<String, dynamic>.from(node);
        }
        if (node is Map) {
          final converted = <String, dynamic>{};
          node.forEach((key, value) {
            converted[key.toString()] = value;
          });
          return converted;
        }
        return {};
      }

      Map<String, dynamic> findToken(dynamic node) {
        if (node is Map || node is Map<String, dynamic>) {
          final map = toMap(node);
          for (final key in const ['token', 'accessToken', 'jwt']) {
            final v = map[key];
            if (v != null && v.toString().isNotEmpty) return {'value': v.toString()};
          }
          for (final value in map.values) {
            final candidate = findToken(value);
            if (candidate.isNotEmpty) return candidate;
          }
        } else if (node is List) {
          for (final value in node) {
            final candidate = findToken(value);
            if (candidate.isNotEmpty) return candidate;
          }
        }
        return {};
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

      final foundToken = findToken(payload);
      final userMap = findUser(payload);
      final tokenValue = foundToken['value']?.toString() ?? '';
      if (tokenValue.isEmpty || userMap.isEmpty) {
        throw Exception(
          'Không lấy được thông tin đăng nhập hợp lệ từ máy chủ.',
        );
      }

      final appUser = User.fromJson(userMap);
      await AuthState.I.setSession(user: appUser, jwt: tokenValue);
      return appUser;
    } on fb.FirebaseAuthException catch (e) {
      if (e.code.toLowerCase() == 'app-not-authorized' ||
          e.message?.contains('ApiException: 10') == true) {
        throw Exception(
          'Lỗi cấu hình Google Sign-In (ApiException: 10). Kiểm tra SHA-1/SHA-256 trong Firebase console và OAuth client id.',
        );
      }
      if (e.code.toLowerCase() == 'operation-not-allowed') {
        throw Exception('Bạn cần bật nhà cung cấp Google trong Firebase Authentication.');
      }
      if (e.code.toLowerCase() == 'unauthorized-domain' ||
          (e.message?.toLowerCase().contains('not authorized for oauth operations') ?? false)) {
        throw Exception(
          'Domain hiện tại chưa được phép dùng OAuth trên Firebase. Vào Firebase Console → Authentication → Settings → Authorized domains và thêm domain đang chạy (vd: localhost, 127.0.0.1, hoặc domain preview).',
        );
      }
      throw Exception(e.message ?? 'Lỗi khi đăng nhập bằng Google.');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('ApiException: 10') || msg.contains('sign_in_failed')) {
        throw Exception(
          'Lỗi cấu hình Google Sign-In (ApiException: 10). Thêm SHA fingerprints và cấu hình OAuth client, sau đó thay google-services.json và rebuild ứng dụng.',
        );
      }
      throw Exception('Lỗi khi đăng nhập bằng Google: $e');
    }
  }

  /// If the app has a firebase-signed-in user but no app JWT saved,
  /// exchange the firebase idToken with backend to restore session.
  Future<void> restoreSessionIfNeeded() async {
    try {
      final fb.User? fu = _firebase.currentUser;
      if (fu == null) return;
      if (AuthState.I.token != null && AuthState.I.token!.isNotEmpty) return;

      final idToken = await fu.getIdToken(true);
      if (idToken == null || idToken.isEmpty) return;

      final response = await _api.post('/auth/firebase', {'idToken': idToken});
      final parsed = ApiDataParser.map(response);
      final payload = parsed['data'] ?? parsed;

      Map<String, dynamic> toMap(dynamic node) {
        if (node is Map<String, dynamic>) {
          return Map<String, dynamic>.from(node);
        }
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
            if (candidate.isNotEmpty) return candidate;
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

      final foundToken = findToken(payload);
      final userMap = findUser(payload);
      if (foundToken.isEmpty || userMap.isEmpty) return;

      final appUser = User.fromJson(userMap);
      await AuthState.I.setSession(user: appUser, jwt: foundToken);
    } catch (_) {
      // ignore failures here; restore is best-effort
    }
  }
}

/// Convenience top-level wrapper so callers can restore session without
/// referencing the AuthService instance type directly (helps analyzer
/// in certain import/resolution edge-cases).
Future<void> restoreSessionIfNeededFromFirebase() async {
  return await AuthService().restoreSessionIfNeeded();
}
