import 'package:flutter/material.dart';

class VoucherScreen extends StatelessWidget {
  const VoucherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vouchers = [
      {'code': 'WELCOME10', 'desc': 'Giảm 10% cho đơn đầu tiên'},
      {'code': 'WEEKEND15', 'desc': 'Giảm 15% cuối tuần'},
      {'code': 'STAY3NIGHTS', 'desc': 'Ở 3 đêm giảm 20%'},
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Ưu đãi')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: vouchers.map((v) => _voucherCard(v)).toList(),
      ),
    );
  }

  Widget _voucherCard(Map<String, String> v) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: const Color(0xFFFFF4E8), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.local_offer, color: Color(0xFFFF8A00)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v['code']!, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(v['desc']!, style: const TextStyle(color: Colors.black54)),
              ]),
            ),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: () {}, child: const Text('Áp dụng')),
          ],
        ),
      ),
    );
  }
}
