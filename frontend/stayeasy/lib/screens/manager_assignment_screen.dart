import 'package:flutter/material.dart';
import 'package:stayeasy/models/hotel.dart';
import 'package:stayeasy/models/user.dart';
import 'package:stayeasy/services/admin_service.dart';

class ManagerAssignmentScreen extends StatefulWidget {
  const ManagerAssignmentScreen({super.key});

  @override
  State<ManagerAssignmentScreen> createState() => _ManagerAssignmentScreenState();
}

class _ManagerAssignmentScreenState extends State<ManagerAssignmentScreen> {
  final _admin = AdminService();
  late Future<List<User>> _usersFuture;
  User? _selectedManager;
  bool _loadingAssignments = false;
  String? _error;
  List<Hotel> _assigned = [];
  List<Hotel> _unassigned = [];

  @override
  void initState() {
    super.initState();
    _usersFuture = _admin.listUsers();
  }

  Future<void> _loadAssignments(User manager) async {
    setState(() {
      _loadingAssignments = true;
      _error = null;
      _assigned = [];
      _unassigned = [];
    });
    try {
      final data = await _admin.listHotelsForManager(manager.id);
      if (!mounted) return;
      setState(() {
        _selectedManager = data.manager;
        _assigned = data.assigned;
        _unassigned = data.unassigned;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingAssignments = false;
      });
    }
  }

  Future<void> _assign(Hotel hotel) async {
    final mgr = _selectedManager;
    if (mgr == null) return;
    try {
      await _admin.assignHotelManager(hotelId: hotel.id, userId: mgr.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã gán ${mgr.name.isNotEmpty ? mgr.name : 'Quản lý #${mgr.id}'} cho "${hotel.name}"')),
      );
      await _loadAssignments(mgr);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gán thất bại: $e')),
      );
    }
  }

  Future<void> _unassign(Hotel hotel) async {
    final mgr = _selectedManager;
    if (mgr == null) return;
    try {
      await _admin.removeHotelManager(hotelId: hotel.id, userId: mgr.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã huỷ gán quản lý khỏi "${hotel.name}"')),
      );
      await _loadAssignments(mgr);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Huỷ gán thất bại: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gán quản lý cho khách sạn'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_selectedManager != null) _loadAssignments(_selectedManager!);
            },
          ),
        ],
      ),
      body: FutureBuilder<List<User>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Không thể tải người dùng: ${snapshot.error}'));
          }
          final users = (snapshot.data ?? const <User>[]) 
              .where((u) => u.role.toLowerCase() == 'hotel_manager')
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Text('Quản lý: '),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<User>(
                        value: _selectedManager,
                        items: users.map((u) {
                          return DropdownMenuItem(
                            value: u,
                            child: Text(u.name.isNotEmpty ? u.name : 'QL #${u.id}'),
                          );
                        }).toList(),
                        onChanged: (u) {
                          if (u == null) return;
                          _loadAssignments(u);
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Chọn quản lý',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_selectedManager == null)
                const Expanded(
                  child: Center(
                    child: Text('Chọn quản lý để xem danh sách khách sạn.'),
                  ),
                )
              else if (_loadingAssignments)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Expanded(
                  child: Center(child: Text('Lỗi tải dữ liệu: ${_error}')),
                )
              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Text(
                        'Đã gán cho ${_selectedManager!.name.isNotEmpty ? _selectedManager!.name : 'QL #${_selectedManager!.id}'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (_assigned.isEmpty)
                        const Text('Chưa có khách sạn nào được gán.')
                      else
                        ..._assigned.map((h) => Card(
                              child: ListTile(
                                title: Text(h.name),
                                subtitle: Text([
                                  h.city,
                                  h.address,
                                ].where((e) => (e ?? '').isNotEmpty).join(' • ')),
                                trailing: TextButton.icon(
                                  onPressed: () => _unassign(h),
                                  icon: const Icon(Icons.link_off),
                                  label: const Text('Huỷ gán'),
                                ),
                              ),
                            )),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text('Khách sạn chưa được gán quản lý', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      if (_unassigned.isEmpty)
                        const Text('Không có khách sạn chưa gán.')
                      else
                        ..._unassigned.map((h) => Card(
                              child: ListTile(
                                title: Text(h.name),
                                subtitle: Text([
                                  h.city,
                                  h.address,
                                ].where((e) => (e ?? '').isNotEmpty).join(' • ')),
                                trailing: ElevatedButton.icon(
                                  onPressed: () => _assign(h),
                                  icon: const Icon(Icons.person_add_alt_1),
                                  label: const Text('Gán'),
                                ),
                              ),
                            )),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

