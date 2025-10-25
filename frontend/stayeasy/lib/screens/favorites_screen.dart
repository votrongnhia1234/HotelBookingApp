import 'package:flutter/material.dart';
import '../services/favorites_service.dart';
import '../services/api_service.dart';
import '../config/api_constants.dart';

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
    final cs = Theme.of(context).colorScheme;
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
                  final resolvedImgUrl = ApiConstants.resolveFileUrl(imgUrl);

                  Widget leading;
                  if (resolvedImgUrl.isNotEmpty) {
                    leading = ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        resolvedImgUrl,
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          width: 76,
                          height: 76,
                          child: Icon(Icons.meeting_room_outlined),
                        ),
                      ),
                    );
                  } else {
                    leading = const SizedBox(
                      width: 76,
                      height: 76,
                      child: Icon(Icons.meeting_room_outlined),
                    );
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          leading,
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hotel,
                                  style: const TextStyle(color: Colors.black54),
                                ),
                                if (price != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    price.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 112,
                            height: 76,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 32),
                                  ),
                                  onPressed: () async {
                                    await FavoritesService.I.toggle(id);
                                    await _loadFavorites();
                                  },
                                  icon: Icon(
                                    Icons.favorite_border,
                                    color: cs.error,
                                  ),
                                  label: Text(
                                    'Bỏ yêu thích',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
