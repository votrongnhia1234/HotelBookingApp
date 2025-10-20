import 'package:flutter/material.dart';
import '../models/hotel.dart';
import '../models/review.dart';
import '../services/review_service.dart';

class ReviewScreen extends StatefulWidget {
  final Hotel hotel;
  const ReviewScreen({super.key, required this.hotel});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _service = ReviewService();
  late Future<List<Review>> _reviewsFuture;

  int _rating = 5;
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = _service.getByHotel(widget.hotel.id);
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập nội dung đánh giá.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await _service.create(
        hotelId: widget.hotel.id,
        userId: 1,            // TODO: thay user thực sau khi có đăng nhập
        rating: _rating,
        comment: text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gửi đánh giá thành công')));
      setState(() {
        _controller.clear();
        _rating = 5;
        _reviewsFuture = _service.getByHotel(widget.hotel.id); // reload
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gửi đánh giá thất bại: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hotel = widget.hotel;
    return Scaffold(
      appBar: AppBar(title: Text('Đánh giá • ${hotel.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<List<Review>>(
            future: _reviewsFuture,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final reviews = snap.data ?? [];
              if (reviews.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('Chưa có đánh giá. Hãy là người đầu tiên!'),
                );
              }
              return Column(
                children: reviews.map((r) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Row(
                      children: [
                        ...List.generate(5, (i) => Icon(
                          i < r.rating ? Icons.star : Icons.star_border,
                          color: Colors.amber, size: 18,
                        )),
                        const SizedBox(width: 6),
                        Text('${r.rating}/5', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    subtitle: Text(r.comment),
                    trailing: Text(r.createdAt.split('T').first),
                  ),
                )).toList(),
              );
            },
          ),
          const Divider(),
          const Text('Viết đánh giá', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              ...List.generate(5, (i) {
                final idx = i + 1;
                final filled = idx <= _rating;
                return IconButton(
                  onPressed: () => setState(() => _rating = idx),
                  icon: Icon(filled ? Icons.star : Icons.star_border, color: Colors.amber),
                );
              }),
              const Spacer(),
              Text('$_rating/5', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          TextField(controller: _controller, maxLines: 3, decoration: const InputDecoration(hintText: 'Cảm nhận của bạn...')),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Gửi đánh giá'),
            ),
          ),
        ],
      ),
    );
  }
}
