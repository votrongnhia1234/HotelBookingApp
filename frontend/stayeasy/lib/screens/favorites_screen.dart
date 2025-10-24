import 'package:flutter/material.dart';
import '../services/favorites_service.dart';
import '../services/api_service.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _loading = true);
    final ids = await FavoritesService.I.load();
    // Fetch public room details for each id
    final items = <dynamic>[];
    for (final id in ids) {
      try {
        final resp = await _api.get('/rooms/public/$id');
        final data = resp['data'] ?? resp;
        items.add(data);
      } catch (e) {
        // ignore missing or forbidden items
      }
    }
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách yêu thích')),
      body: RefreshIndicator(
        onRefresh: _loadFavorites,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 40),
                  Center(child: Text('Bạn chưa có mục yêu thích nào')),
                ],
              )
            : ListView.builder(
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final item = _items[i] as Map<String, dynamic>;
                  final title =
                      (item['name'] ?? item['title'] ?? item['type'] ?? 'Phòng')
                          .toString();
                  final hotel =
                      (item['hotelName'] ??
                              item['hotel'] ??
                              item['hotel_name'] ??
                              item['address'] ??
                              '')
                          .toString();
                  final id = item['id']?.toString() ?? '';
                  final price =
                      item['pricePerNight'] ?? item['price'] ?? item['amount'];
                  final imgUrl = () {
                    // Prefer images list; support entries that are String or Map
                    final imgs = item['images'];
                    if (imgs is List && imgs.isNotEmpty) {
                      final first = imgs.first;
                      if (first is String) return first;
                      if (first is Map) {
                        return (first['url'] ??
                                first['src'] ??
                                first['path'] ??
                                '')
                            .toString();
                      }
                      return first.toString();
                    }
                    final v =
                        item['imageUrl'] ??
                        item['image_url'] ??
                        item['thumbnail'] ??
                        '';
                    if (v is Map) {
                      return (v['url'] ?? v['src'] ?? v['path'] ?? '')
                          .toString();
                    }
                    return v?.toString() ?? '';
                  }();

                  Widget leading;
                  if (imgUrl.isNotEmpty) {
                    leading = ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imgUrl,
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          width: 76,
                          height: 76,
                          child: Icon(Icons.room),
                        ),
                      ),
                    );
                  } else {
                    leading = const SizedBox(
                      width: 76,
                      height: 76,
                      child: Icon(Icons.room),
                    );
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: leading,
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(hotel),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          price != null ? price.toString() : '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await FavoritesService.I.toggle(id);
                            await _loadFavorites();
                          },
                        ),
                      ],
                    ),
                    onTap: () {},
                  );
                },
              ),
      ),
    );
  }
}
