import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/hotel.dart';
import '../services/hotel_service.dart';
import '../services/location_service.dart';
import '../state/auth_state.dart';
import '../widgets/hotel_card.dart';
import 'profile_screen.dart';
import 'my_trips_screen.dart';
import 'voucher_screen.dart';
import '../widgets/ai_chat_sheet.dart';
import 'ai_chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  bool _initialIndexApplied = false;
  final _hotelService = HotelService();
  final _locationService = LocationService();
  // Pagination & state
  final ScrollController _scrollCtl = ScrollController();
  final int _limit = 20;
  int _page = 1;
  bool _loading = false;
  bool _initialLoaded = false;
  bool _hasMore = true;
  List<Hotel> _hotels = [];

  String _query = '';
  Position? _currentPosition;
  String? _locationError;
  bool _requestingLocation = false;
  double _minRating = 0;
  double? _maxDistanceKm;
  bool _chatSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _loadInitialHotels();
    _scrollCtl.addListener(_onScroll);
    AuthState.I.addListener(_handleAuthChange);
    // Tránh auto yêu cầu quyền vị trí trên web để không hiện lỗi ngay khi mở trang
    if (!kIsWeb) {
      _loadLocation();
    }
  }

  @override
  void dispose() {
    _scrollCtl.removeListener(_onScroll);
    _scrollCtl.dispose();
    AuthState.I.removeListener(_handleAuthChange);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialIndexApplied) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final dynamic tabArg = args['tab'];
      final dynamic initialIdx = args['initialIndex'];
      int? wanted;
      if (initialIdx is int) {
        wanted = initialIdx;
      } else if (tabArg is String) {
        switch (tabArg) {
          case 'home':
            wanted = 0;
            break;
          case 'recommendations':
            wanted = 1;
            break;
          case 'trips':
          case 'bookings':
          case 'orders':
            wanted = 2;
            break;
          case 'vouchers':
          case 'deals':
            wanted = 3;
            break;
          case 'profile':
          case 'account':
            wanted = 4;
            break;
        }
      }
      if (wanted != null) {
        setState(() => _index = wanted!.clamp(0, 4));
      }
    }
    _initialIndexApplied = true;
  }

  void _onScroll() {
    if (!_hasMore || _loading) return;
    if (_scrollCtl.position.pixels >=
        _scrollCtl.position.maxScrollExtent - 200) {
      _loadMoreHotels();
    }
  }

  Future<void> _loadInitialHotels() async {
    setState(() {
      _loading = true;
      _initialLoaded = false;
      _page = 1;
      _hasMore = true;
      _hotels = [];
    });
    try {
      final list = await _hotelService.fetchHotels(page: _page, limit: _limit);
      if (!mounted) return;
      setState(() {
        _hotels = list;
        _initialLoaded = true;
        _hasMore = list.length >= _limit;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initialLoaded = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải khách sạn: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadMoreHotels() async {
    if (_loading) return;
    setState(() {
      _loading = true;
    });
    try {
      final nextPage = _page + 1;
      final list = await _hotelService.fetchHotels(page: nextPage, limit: _limit);
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _hotels.addAll(list);
        _hasMore = list.length >= _limit;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải thêm: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _refreshHotels() async {
    await _loadInitialHotels();
  }

  void _handleAuthChange() {
    if (!mounted) return;
    if (AuthState.I.isLoggedIn && _index == 0) setState(() => _index = 4);
  }

  void _onNavTap(int value) {
    // switch tabs instead of pushing new routes so bottom navigation stays visible
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
                      value: ((tempDistance ?? 50).clamp(0, 50)).toDouble(),
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
      // embed trips and vouchers so the bottom nav remains visible like in Recommendations
      const MyTripsScreen(embedded: true),
      const VoucherScreen(embedded: true),
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
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Khám phá trên bản đồ',
            onPressed: () => Navigator.pushNamed(context, '/explore'),
          ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _chatSheetOpen ? null : _openAiChatSheet,
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Chat'),
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
                    label: Text(
                      'Đánh giá từ  ${_minRating.toStringAsFixed(1)}',
                    ),
                    onDeleted: () => setState(() => _minRating = 0),
                  ),
                if (_maxDistanceKm != null)
                  Chip(
                    label: Text('${_maxDistanceKm!.toStringAsFixed(0)} km'),
                    onDeleted: () => setState(() => _maxDistanceKm = null),
                  ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshHotels,
            child: Builder(
              builder: (context) {
                if (!_initialLoaded) {
                  return const Center(child: CircularProgressIndicator());
                }
                final hotels = _filterHotels(_hotels);
                if (hotels.isEmpty) {
                  return ListView(
                    controller: _scrollCtl,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                    children: const [
                      SizedBox(height: 40),
                      Center(child: Text('Không tìm thấy khách sạn phù hợp.')),
                    ],
                  );
                }
                return ListView.builder(
                  controller: _scrollCtl,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  itemCount: hotels.length + 1,
                  itemBuilder: (_, index) {
                    if (index == hotels.length) {
                      if (_loading) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (!_hasMore) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: Text('Đã hiển thị tất cả')),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: OutlinedButton.icon(
                            onPressed: _loadMoreHotels,
                            icon: const Icon(Icons.expand_more),
                            label: const Text('Tải thêm'),
                          ),
                        ),
                      );
                    }
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
          child: Builder(
            builder: (context) {
              if (!_initialLoaded) {
                return const Center(child: CircularProgressIndicator());
              }
              final hotels = _hotels.where((h) => h.rating >= 4.5).toList();
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
                    heroTag: 'rec-${hotel.id}',
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

  Future<void> _openAiChatSheet() async {
    if (!kIsWeb) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AiChatScreen()),
      );
      return;
    }
    if (_chatSheetOpen) return;
    setState(() => _chatSheetOpen = true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      isDismissible: false,
      enableDrag: false,
      barrierColor: Colors.transparent,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        final h = MediaQuery.of(sheetContext).size.height;
        return SizedBox(height: h * 0.92, child: const AiChatSheet());
      },
    ).whenComplete(() {
      if (mounted) setState(() => _chatSheetOpen = false);
    });
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
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'StayEasy dựa trên lịch sử và sở thích của bạn để đề xuất khách sạn phù hợp.',
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.login),
              label: const Text('Đăng nhập để sử dụng ngay'),
            ),
          ),
        ],
      ),
    );
  }
}



// Open AI Chat (method within state)
void _openAiChatSheet() {
  // No-op duplicate; logic moved inside _HomeScreenState.
}