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
        title: const Text('StayEasy', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          AnimatedBuilder(
            animation: AuthState.I,
            builder: (_, __) {
              final user = AuthState.I.currentUser;
              if (user == null) {
                return TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text(
                    'Đăng nhập',
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
                    const SizedBox(width: 6),
                    Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700)),
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
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.star_border_rounded), activeIcon: Icon(Icons.star_rounded), label: 'Đề xuất'),
          BottomNavigationBarItem(icon: Icon(Icons.event_available_outlined), activeIcon: Icon(Icons.event_available), label: 'Phòng đã đặt'),
          BottomNavigationBarItem(icon: Icon(Icons.card_giftcard_outlined), activeIcon: Icon(Icons.card_giftcard), label: 'Ưu đãi'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Tài khoản'),
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
            decoration: const InputDecoration(
              hintText: 'Tìm khách sạn, địa điểm...',
              prefixIcon: Icon(Icons.search),
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
              isError: false,
              onRetry: _loadLocation,
              loading: _requestingLocation,
            ),
          )
        else if (_requestingLocation)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _LocationInfoBanner(
              message: 'Đang xác định vị trí...',
              isError: false,
              loading: true,
            ),
          ),
        Expanded(
          child: FutureBuilder<List<Hotel>>(
            future: _hotelsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              var hotels = snapshot.data ?? [];
              if (_query.isNotEmpty) {
                final q = _query.toLowerCase();
                hotels = hotels
                    .where((hotel) =>
                        hotel.name.toLowerCase().contains(q) ||
                        hotel.address.toLowerCase().contains(q))
                    .toList();
              }
              if (hotels.isEmpty) {
                return const Center(child: Text('Không tìm thấy khách sạn phù hợp'));
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: hotels.length,
                itemBuilder: (_, index) => HotelCard(
                  hotel: hotels[index],
                  distanceKm: _locationService.distanceKm(
                    latitude: hotels[index].latitude,
                    longitude: hotels[index].longitude,
                    from: _currentPosition,
                  ),
                  heroTag: 'home-',
                  onTap: () => Navigator.pushNamed(context, '/hotel', arguments: hotels[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendations(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Đề xuất cho bạn',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text('Những khách sạn được đánh giá cao, phù hợp với hành trình sắp tới.'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: AnimatedBuilder(
            animation: AuthState.I,
            builder: (_, __) {
              if (AuthState.I.currentUser == null) {
                return _RecommendationLoginCard(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Hotel>>(
            future: _hotelsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final hotels = (snapshot.data ?? []).where((h) => h.rating >= 4.5).toList();
              if (hotels.isEmpty) {
                return const Center(child: Text('Chưa có dữ liệu gợi ý. Vui lòng thử lại sau!'));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                itemCount: hotels.length,
                itemBuilder: (_, index) => HotelCard(
                  hotel: hotels[index],
                  distanceKm: _locationService.distanceKm(
                    latitude: hotels[index].latitude,
                    longitude: hotels[index].longitude,
                    from: _currentPosition,
                  ),
                  heroTag: 'rec-',
                  onTap: () => Navigator.pushNamed(context, '/hotel', arguments: hotels[index]),
                ),
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
          Icon(isError ? Icons.error_outline : Icons.my_location, color: iconColor),
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
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
          else if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text(isError ? 'Thử lại' : 'Cập nhật')),
        ],
      ),
    );
  }
}

class _RecommendationLoginCard extends StatelessWidget {
  const _RecommendationLoginCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF64B5F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Đăng nhập để nhận gợi ý riêng',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 6),
          const Text(
            'StayEasy sẽ dựa trên lịch sử và sở thích của bạn để gợi ý khách sạn phù hợp.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E88E5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.login),
              label: const Text('Đăng nhập ngay'),
            ),
          ),
        ],
      ),
    );
  }
}
