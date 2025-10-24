import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthState extends ChangeNotifier {
  static final AuthState I = AuthState._();
  AuthState._();

  User? currentUser;
  String? token;

  bool get isLoggedIn => currentUser != null && (token ?? '').isNotEmpty;
  bool get isAdmin => currentUser?.role == 'admin';
  bool get isHotelManager => currentUser?.role == 'hotel_manager';

  Future<void> loadFromStorage() async {
    final sp = await SharedPreferences.getInstance();
    token = sp.getString('auth_token');
    final su = sp.getString('auth_user');
    if (su != null) {
      currentUser = User.fromJson(jsonDecode(su) as Map<String, dynamic>);
    }
    notifyListeners();
  }

  Future<void> setSession({required User user, required String jwt}) async {
    currentUser = user;
    token = jwt;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('auth_token', jwt);
    await sp.setString('auth_user', jsonEncode(user.toJson())); // cần toJson()
    notifyListeners();
  }

  Future<void> logout() async {
    currentUser = null;
    token = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove('auth_token');
    await sp.remove('auth_user');
    notifyListeners();
  }

  Future<void> updateUser(User user) async {
    currentUser = user;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('auth_user', jsonEncode(user.toJson()));
    notifyListeners();
  }
}
