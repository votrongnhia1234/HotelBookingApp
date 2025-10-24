import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static final FavoritesService I = FavoritesService._();
  FavoritesService._();

  static const _kKey = 'favorites_rooms';

  Future<List<String>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = List<String>.from(jsonDecode(raw) as List);
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<String> ids) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kKey, jsonEncode(ids));
  }

  Future<void> toggle(String id) async {
    final ids = await load();
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);
    }
    await save(ids);
  }

  Future<bool> contains(String id) async {
    final ids = await load();
    return ids.contains(id);
  }
}
