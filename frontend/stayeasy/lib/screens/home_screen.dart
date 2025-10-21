import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/hotel.dart';
import '../services/hotel_service.dart';
import '../services/location_service.dart';
import '../state/auth_state.dart';
import '../widgets/hotel_card.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  final _hotelService = HotelService();
  final _locationService = LocationService();
  late Future<List<Hotel>> _hotelsFuture;
  String _query = '';
  Position? _currentPosition;
  String? _locationError;
  bool _requestingLocation = false;
  double _minRating = 0;
  double? _maxDistanceKm;

  @override
  void initState() {
    super.initState();
    _hotelsFuture = _hotelService.fetchHotels();
    AuthState.I.addListener(_handleAuthChange);
    _loadLocation();
  }

  @override
  void dispose() {
    AuthState.I.removeListener(_handleAuthChange);
    super.dispose();
  }

  void _handleAuthChange() {
    if (!mounted) return;
    if (AuthState.I.isLoggedIn) setState(() => _index = 4);
  }

  void _onNavTap(int value) {
    if (value == 2) {
      Navigator.pushNamed(context, '/trips');
      return;
    }
    if (value == 3) {
      Navigator.pushNamed(context, '/voucher');
      return;
    }
    setState(() => _index = value);
  }

  Future<void> _loadLocation() async {
    setState(() {
      _requestingLocation = true;
      _locationError = null;
    });
    final result = await _locationService.determinePosition();
    if (!mounted) return;
    setState(() {
      _requestingLocation = false;
      _currentPosition = result.position;
      _locationError = result.error;
    });
  }

  Future<void> _openFilters() async {
    double tempRating = _minRating;
    double? tempDistance = _maxDistanceKm;
    final hasLocation = _currentPosition != null;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Bộ lọc',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempRating = 0;
                            tempDistance = null;
                          });
                        },
                        child: const Text('Xóa lọc'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Đánh giá tối thiểu'),
                  Slider(
                    value: tempRating,
                    min: 0,
                    max: 5,
                    divisions: 10,
                    label: tempRating.toStringAsFixed(1),
                    onChanged: (value) =>
                        setModalState(() => tempRating = value),
                  ),
                  if (hasLocation) ...[
                    const SizedBox(height: 12),
                    const Text('Khoảng cách tối đa (km)'),
                    Slider(
                      value: (tempDistance ?? 50).clamp(0, 50),
                      min: 1,
                      max: 50,
                      divisions: 49,
                      label: tempDistance == null
                          ? 'Không giới hạn'
                          : tempDistance!.toStringAsFixed(0),
                      onChanged: (value) =>
                          setModalState(() => tempDistance = value),
                      onChangeEnd: (value) =>
                          setModalState(() => tempDistance = value),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () =>
                              setModalState(() => tempDistance = null),
                          child: const Text('Bỏ giới hạn'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pop<Map<String, dynamic>>(context, {
                            'rating': tempRating,
                            'distance': hasLocation ? tempDistance : null,
                          }),
                      child: const Text('Áp dụng'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null) return;
    setState(() {
      _minRating = result['rating'] as double? ?? 0;
      _maxDistanceKm = result['distance'] as double?;
    });
  }

  double? _distanceOf(Hotel hotel) {
    return _locationService.distanceKm(
      latitude: hotel.latitude,
      longitude: hotel.longitude,
      from: _currentPosition,
    );
  }

  List<Hotel> _filterHotels(List<Hotel> hotels) {
    return hotels.where((hotel) {
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final target = '${hotel.name} ${hotel.address} ${hotel.city}'
            .toLowerCase();
        if (!target.contains(q)) return false;
      }
      if (_minRating > 0 && hotel.rating < _minRating) return false;
      if (_maxDistanceKm != null) {
        final distance = _distanceOf(hotel);
        if (distance == null || distance > _maxDistanceKm!) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildHotels(context),
      _buildRecommendations(context),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'StayEasy',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Bộ lọc',
            onPressed: _openFilters,
          ),
          AnimatedBuilder(
            animation: AuthState.I,
            builder: (_, __) {
              final user = AuthState.I.currentUser;
              if (user == null) {
                return TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text(
                    'Đăng nhập',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 14,
                      child: Icon(Icons.person, size: 16),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_border_rounded),
            activeIcon: Icon(Icons.star_rounded),
            label: 'Đề xuất',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_available_outlined),
            activeIcon: Icon(Icons.event_available),
            label: 'Đã đặt',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_giftcard_outlined),
            activeIcon: Icon(Icons.card_giftcard),
            label: 'Ưu đãi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }

  Widget _buildHotels(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Tìm khách sạn, địa điểm...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: _openFilters,
                icon: const Icon(Icons.tune),
              ),
            ),
          ),
        ),
        if (_locationError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _LocationInfoBanner(
              message: _locationError!,
              isError: true,
              onRetry: _loadLocation,
            ),
          )
        else if (_currentPosition != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _LocationInfoBanner(
              message: 'Đang hiển thị theo vị trí hiện tại của bạn.',
              onRetry: _loadLocation,
              loading: _requestingLocation,
            ),
          )
        else if (_requestingLocation)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _LocationInfoBanner(
              message: 'Đang xác định vị trí...',
              loading: true,
            ),
          ),
        if (_minRating > 0 || _maxDistanceKm != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: [
                if (_minRating > 0)
                  Chip(
                    label: Text('Đánh giá từ ${_minRating.toStringAsFixed(1)}'),
                    onDeleted: () => setState(() => _minRating = 0),
                  ),
                if (_maxDistanceKm != null)
                  Chip(
                    label: Text('≤ ${_maxDistanceKm!.toStringAsFixed(0)} km'),
                    onDeleted: () => setState(() => _maxDistanceKm = null),
                  ),
              ],
            ),
          ),
        Expanded(
          child: FutureBuilder<List<Hotel>>(
            future: _hotelsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Không th? t?i danh sách khách s?n.'),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => setState(
                          () => _hotelsFuture = _hotelService.fetchHotels(),
                        ),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                );
              }

              final hotels = _filterHotels(snapshot.data ?? []);
              if (hotels.isEmpty) {
                return const Center(
                  child: Text('Không tìm th?y khách s?n phù h?p.'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                itemCount: hotels.length,
                itemBuilder: (_, index) {
                  final hotel = hotels[index];
                  final distance = _distanceOf(hotel);
                  return HotelCard(
                    hotel: hotel,
                    distanceKm: distance,
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/hotel',
                      arguments: hotel,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendations(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gợi ý cho bạn',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Những khách sạn được đánh giá cao nhất trong hệ thống StayEasy.',
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Hotel>>(
            future: _hotelsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final hotels = (snapshot.data ?? [])
                  .where((h) => h.rating >= 4.5)
                  .toList();
              if (hotels.isEmpty) {
                return const Center(
                  child: Text('Chưa có dữ liệu gợi ý. Vui lòng thử lại sau!'),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                itemCount: hotels.length,
                itemBuilder: (_, index) {
                  final hotel = hotels[index];
                  final distance = _distanceOf(hotel);
                  return HotelCard(
                    hotel: hotel,
                    distanceKm: distance,
                    heroTag: 'rec-',
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/hotel',
                      arguments: hotel,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LocationInfoBanner extends StatelessWidget {
  const _LocationInfoBanner({
    required this.message,
    this.isError = false,
    this.onRetry,
    this.loading = false,
  });

  final String message;
  final bool isError;
  final VoidCallback? onRetry;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.red.shade50 : const Color(0xFFE3F2FD);
    final iconColor = isError ? Colors.red : const Color(0xFF1E88E5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.my_location,
            color: iconColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: isError ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          if (loading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(isError ? 'Thử lại' : 'Cập nhật'),
            ),
        ],
      ),
    );
  }
}
