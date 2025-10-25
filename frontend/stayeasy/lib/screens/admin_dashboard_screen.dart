import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stayeasy/models/user.dart';
import 'package:stayeasy/models/booking.dart';
import 'package:stayeasy/models/dashboard_stats.dart';
import 'package:stayeasy/widgets/booking_card.dart';
import 'package:stayeasy/services/admin_service.dart';
import 'package:stayeasy/services/hotel_service.dart';
import 'package:stayeasy/services/booking_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _service = AdminService();
  final HotelService _hotelService = HotelService();
  final BookingService _bookingService = BookingService();
  late Future<List<User>> _usersFuture;
  late Future<List<Booking>> _bookingsFuture;
  late Future<DashboardStats> _statsFuture;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _usersFuture = _service.listUsers();
    _bookingsFuture = _service.listBookings();
    _statsFuture = _service.fetchDashboard();
  }

  Future<void> _exportSummary() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await _service.exportRevenueSummaryXlsx();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang tải tệp Excel doanh thu...')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Xuất Excel thất bại: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _openExportDatasetDialog() async {
    DateTime? from = DateTime.now().subtract(const Duration(days: 30));
    DateTime? to = DateTime.now();
    String group = 'day';

    String fmt(DateTime? d) =>
        d == null ? 'Chưa chọn' : DateFormat('yyyy-MM-dd').format(d);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            Future<void> pickFrom() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: from ?? DateTime.now(),
                firstDate: DateTime(2020, 1, 1),
                lastDate: DateTime.now(),
              );
              if (picked != null) setInnerState(() => from = picked);
            }

            Future<void> pickTo() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: to ?? DateTime.now(),
                firstDate: DateTime(2020, 1, 1),
                lastDate: DateTime.now(),
              );
              if (picked != null) setInnerState(() => to = picked);
            }

            return AlertDialog(
              title: const Text('Xuất dataset doanh thu'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Từ ngày'),
                    subtitle: Text(fmt(from)),
                    trailing: TextButton(
                      onPressed: pickFrom,
                      child: const Text('Chọn'),
                    ),
                  ),
                  ListTile(
                    title: const Text('Đến ngày'),
                    subtitle: Text(fmt(to)),
                    trailing: TextButton(
                      onPressed: pickTo,
                      child: const Text('Chọn'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: group,
                    items: const [
                      DropdownMenuItem(value: 'day', child: Text('Theo ngày')),
                      DropdownMenuItem(
                        value: 'month',
                        child: Text('Theo tháng'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setInnerState(() => group = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Nhóm dữ liệu',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Xuất'),
                  onPressed: (from == null || to == null || _exporting)
                      ? null
                      : () async {
                          Navigator.pop(context);
                          setState(() => _exporting = true);
                          try {
                            await _service.exportRevenueXlsx(
                              from: from!,
                              to: to!,
                              group: group,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Đang tải tệp Excel dataset...',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Xuất dataset thất bại: $e'),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _exporting = false);
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _changeUserRole(User u) async {
    final roles = const ['customer', 'hotel_manager', 'admin'];
    String selected = u.role.isNotEmpty ? u.role : 'customer';
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                'Đổi vai trò cho ${u.name.isNotEmpty ? u.name : 'User #${u.id}'}',
              ),
              content: DropdownButtonFormField<String>(
                initialValue: selected,
                items: roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) =>
                    setStateDialog(() => selected = v ?? selected),
                decoration: const InputDecoration(labelText: 'Vai trò'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _service.changeUserRole(
                        userId: u.id,
                        role: selected,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cập nhật vai trò thành công'),
                          ),
                        );
                        // Tránh callback setState trả về Future, cập nhật trực tiếp
                        final fresh = _service.listUsers();
                        setState(() {
                          _usersFuture = fresh;
                        });
                        // Không await trong setState để tránh cảnh báo
                        await fresh;
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi đổi vai trò: $e')),
                        );
                      }
                    } finally {
                      if (Navigator.canPop(context)) Navigator.pop(context);
                    }
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _assignManagerToHotel(User u) async {
    try {
      final hotels = await _hotelService.fetchHotels();
      if (!mounted) return;
      final Set<int> selected = {};
      await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                title: Text(
                  'Gán quản lý cho ${u.name.isNotEmpty ? u.name : 'User #${u.id}'}',
                ),
                content: SizedBox(
                  width: 420,
                  child: hotels.isEmpty
                      ? const Text('Chưa có khách sạn nào.')
                      : SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: hotels.map((h) {
                              final checked = selected.contains(h.id);
                              // Không vô hiệu hóa theo managerCount; cho phép gán nhiều quản lý.
                              final disabled = false;
                              final subtitleText = [
                                [
                                  h.city,
                                  h.address,
                                ].where((e) => e.isNotEmpty).join(' • '),
                                if (h.managerCount > 0)
                                  'Số QL: ${h.managerCount}',
                              ].where((e) => e.isNotEmpty).join(' • ');
                              return CheckboxListTile(
                                value: checked,
                                title: Text(h.name),
                                subtitle: Text(subtitleText),
                                secondary: disabled
                                    ? const Icon(
                                        Icons.lock_outline,
                                        color: Colors.black45,
                                      )
                                    : null,
                                onChanged: disabled
                                    ? null
                                    : (v) {
                                        setStateDialog(() {
                                          if (v == true) {
                                            selected.add(h.id);
                                          } else {
                                            selected.remove(h.id);
                                          }
                                        });
                                      },
                              );
                            }).toList(),
                          ),
                        ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                  ElevatedButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () async {
                            try {
                              int ok = 0, skipped = 0, failed = 0;
                              for (final hid in selected) {
                                try {
                                  await _service.assignHotelManager(
                                    hotelId: hid,
                                    userId: u.id,
                                  );
                                  ok++;
                                } catch (e) {
                                  final msg = e.toString().toLowerCase();
                                  if (msg.contains('already manages')) {
                                    skipped++;
                                  } else {
                                    failed++;
                                  }
                                }
                              }
                              if (mounted) {
                                final message =
                                    'Gán thành công: $ok, Trùng lặp: $skipped, Lỗi: $failed';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(message)),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Lỗi gán quản lý: $e'),
                                  ),
                                );
                              }
                            } finally {
                              if (Navigator.canPop(context))
                                Navigator.pop(context);
                            }
                          },
                    child: const Text('Gán'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải danh sách khách sạn: $e')),
        );
      }
    }
  }

  Future<void> _refreshUsers() async {
    final fresh = _service.listUsers();
    setState(() {
      _usersFuture = fresh;
    });
    await fresh;
  }

  Future<void> _refreshBookings() async {
    final fresh = _service.listBookings();
    setState(() {
      _bookingsFuture = fresh;
    });
    await fresh;
  }

  bool _canConfirm(Booking b) {
    return (b.status.toLowerCase() == 'pending');
  }

  bool _canCancel(Booking b) {
    final s = b.status.toLowerCase();
    return s == 'pending' || s == 'confirmed' || s == 'completed';
  }

  bool _canComplete(Booking b) {
    final s = b.status.toLowerCase();
    return s == 'pending' || s == 'confirmed';
  }

  Future<void> _updateStatus(Booking b, String status) async {
    try {
      await _bookingService.updateStatus(b.id, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã cập nhật trạng thái: $status')),
        );
        await _refreshBookings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cập nhật trạng thái thất bại: $e')),
        );
      }
    }
  }

  Future<void> _complete(Booking b) async {
    try {
      await _bookingService.complete(b.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã đánh dấu hoàn tất')));
        await _refreshBookings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đánh dấu hoàn tất thất bại: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bảng điều khiển quản trị'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Tổng quan'),
              Tab(icon: Icon(Icons.people_alt), text: 'Người dùng'),
              Tab(icon: Icon(Icons.event_available), text: 'Đơn đặt'),
            ],
          ),
          actions: [
            // Thay nút lớn thành menu để luôn hiển thị trên màn hình nhỏ
            PopupMenuButton<String>(
              tooltip: 'Xuất dữ liệu',
              onSelected: (value) {
                switch (value) {
                  case 'export-summary':
                    _exportSummary();
                    break;
                  case 'export-dataset':
                    _openExportDatasetDialog();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'export-summary',
                  child: Row(
                    children: const [
                      Icon(Icons.file_present_outlined),
                      SizedBox(width: 8),
                      Text('Xuất Excel doanh thu'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'export-dataset',
                  child: Row(
                    children: const [
                      Icon(Icons.dataset_outlined),
                      SizedBox(width: 8),
                      Text('Xuất dataset'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // ===== Overview metrics =====
            FutureBuilder<DashboardStats>(
              future: _statsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return ListView(
                    children: const [
                      SizedBox(height: 200),
                      Center(child: CircularProgressIndicator()),
                    ],
                  );
                }
                if (snapshot.hasError) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('Không thể tải dữ liệu: ${snapshot.error}'),
                    ],
                  );
                }
                final s = snapshot.data!;
                final currency = NumberFormat.currency(
                  locale: 'vi_VN',
                  symbol: '₫',
                  decimalDigits: 0,
                );
                final theme = Theme.of(context);
                Widget tile(IconData icon, String label, String value) {
                  final width = math
                      .max(MediaQuery.of(context).size.width / 2 - 24, 160)
                      .toDouble();
                  return SizedBox(
                    width: width,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, color: theme.colorScheme.primary),
                            const SizedBox(height: 12),
                            Text(
                              value,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              label,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Cập nhật đến ${s.asOf}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        tile(
                          Icons.people_alt,
                          'Người dùng',
                          s.users.toString(),
                        ),
                        tile(Icons.apartment, 'Khách sạn', s.hotels.toString()),
                        tile(
                          Icons.meeting_room_outlined,
                          'Phòng',
                          s.rooms.toString(),
                        ),
                        tile(
                          Icons.event_available_outlined,
                          'Đơn đặt',
                          s.bookings.toString(),
                        ),
                        tile(
                          Icons.waves_outlined,
                          'Doanh thu (tổng)',
                          currency.format(s.revenueAll),
                        ),
                        tile(
                          Icons.calendar_month_outlined,
                          'Doanh thu hôm nay',
                          currency.format(s.revenueToday),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),

            // ===== Users list =====
            RefreshIndicator(
              onRefresh: _refreshUsers,
              child: FutureBuilder<List<User>>(
                future: _usersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return ListView(
                      children: const [
                        SizedBox(height: 200),
                        Center(child: CircularProgressIndicator()),
                      ],
                    );
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text('Không thể tải người dùng: ${snapshot.error}'),
                      ],
                    );
                  }
                  final users = snapshot.data ?? const <User>[];
                  if (users.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: const [Text('Chưa có người dùng nào.')],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final u = users[i];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            (u.name.isNotEmpty ? u.name[0] : '#').toUpperCase(),
                          ),
                        ),
                        title: Text(
                          u.name.isNotEmpty ? u.name : 'Người dùng #${u.id}',
                        ),
                        subtitle: Text(
                          [
                            u.email,
                            u.phone,
                          ].where((e) => e.isNotEmpty).join(' • '),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              u.role.isNotEmpty ? u.role : 'customer',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              tooltip: 'Thao tác',
                              onSelected: (value) {
                                switch (value) {
                                  case 'change-role':
                                    _changeUserRole(u);
                                    break;
                                  case 'assign-manager':
                                    _assignManagerToHotel(u);
                                    break;
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'change-role',
                                  child: Text('Đổi vai trò'),
                                ),
                                PopupMenuItem(
                                  value: 'assign-manager',
                                  child: Text('Gán quản lý KS'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // ===== Bookings list =====
            RefreshIndicator(
              onRefresh: _refreshBookings,
              child: FutureBuilder<List<Booking>>(
                future: _bookingsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return ListView(
                      children: const [
                        SizedBox(height: 200),
                        Center(child: CircularProgressIndicator()),
                      ],
                    );
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text('Không thể tải đơn đặt: ${snapshot.error}'),
                      ],
                    );
                  }
                  final bookings = snapshot.data ?? const <Booking>[];
                  if (bookings.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: const [Text('Chưa có đơn đặt nào.')],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: bookings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final b = bookings[i];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          BookingCard(booking: b),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: b.status.toLowerCase(),
                                  items: [
                                    if (b.status.toLowerCase() ==
                                        'pending') ...const [
                                      DropdownMenuItem(
                                        value: 'pending',
                                        child: Text('Đang xử lý'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'confirmed',
                                        child: Text('Đã xác nhận'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'completed',
                                        child: Text('Hoàn tất'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'cancelled',
                                        child: Text('Đã hủy'),
                                      ),
                                    ] else if (b.status.toLowerCase() ==
                                        'confirmed') ...const [
                                      DropdownMenuItem(
                                        value: 'confirmed',
                                        child: Text('Đã xác nhận'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'completed',
                                        child: Text('Hoàn tất'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'cancelled',
                                        child: Text('Đã hủy'),
                                      ),
                                    ] else if (b.status.toLowerCase() ==
                                        'completed') ...const [
                                      DropdownMenuItem(
                                        value: 'completed',
                                        child: Text('Hoàn tất'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'cancelled',
                                        child: Text('Đã hủy'),
                                      ),
                                    ] else ...const [
                                      DropdownMenuItem(
                                        value: 'cancelled',
                                        child: Text('Đã hủy'),
                                      ),
                                    ],
                                  ],
                                  onChanged:
                                      (b.status.toLowerCase() == 'cancelled')
                                      ? null
                                      : (v) {
                                          if (v == null ||
                                              v == b.status.toLowerCase())
                                            return;
                                          if (v == 'completed') {
                                            _complete(b);
                                          } else {
                                            _updateStatus(b, v);
                                          }
                                        },
                                ),
                              ),
                              if (_canConfirm(b))
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _updateStatus(b, 'confirmed'),
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Xác nhận'),
                                ),
                              if (_canComplete(b))
                                ElevatedButton.icon(
                                  onPressed: () => _complete(b),
                                  icon: const Icon(Icons.done_all),
                                  label: const Text('Hoàn tất'),
                                ),
                              if (_canCancel(b))
                                TextButton.icon(
                                  onPressed: () =>
                                      _updateStatus(b, 'cancelled'),
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: const Text('Hủy'),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
