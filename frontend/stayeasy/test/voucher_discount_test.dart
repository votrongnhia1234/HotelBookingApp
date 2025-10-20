import 'package:flutter_test/flutter_test.dart';
import 'package:stayeasy/models/voucher.dart';

void main() {
  group('Voucher.discountFor', () {
    test('returns percentage discount when conditions met', () {
      final voucher = Voucher(
        id: 1,
        code: 'WEEKEND',
        title: 'Giảm 10%',
        description: '',
        discountType: 'percent',
        value: 10,
        minOrder: 300000,
      );

      final discount = voucher.discountFor(total: 500000, payMethod: 'cod');
      expect(discount, 50000);
    });

    test('ignores percent voucher when min order not reached', () {
      final voucher = Voucher(
        id: 2,
        code: 'SMALL',
        title: 'Giảm 20%',
        description: '',
        discountType: 'percent',
        value: 20,
        minOrder: 600000,
      );

      final discount = voucher.discountFor(total: 500000, payMethod: 'cod');
      expect(discount, 0);
    });

    test('amount voucher requires online payment when flagged', () {
      final voucher = Voucher(
        id: 3,
        code: 'ONLINE',
        title: 'Giảm 50k',
        description: '',
        discountType: 'amount',
        value: 50000,
        onlineOnly: true,
      );

      expect(voucher.discountFor(total: 400000, payMethod: 'cod'), 0);
      expect(voucher.discountFor(total: 400000, payMethod: 'online'), 50000);
    });
  });
}
