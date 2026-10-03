import 'package:flutter_test/flutter_test.dart';
import 'package:splitwise_app/model/group_model.dart';
import 'package:splitwise_app/utils/payment_links.dart';

void main() {
  group('PaymentLinks.upi', () {
    test('pre-fills payee, amount, currency and note', () {
      final uri = PaymentLinks.upi(
        upiId: 'alex@okaxis',
        payeeName: 'Alex Kumar',
        amount: 300,
        note: 'PaisaSplit · Flatmates',
      );
      final s = uri.toString();
      expect(s, startsWith('upi://pay?'));
      // The @ stays literal — some UPI apps reject %40.
      expect(s, contains('pa=alex@okaxis'));
      // Spaces are %20, never +.
      expect(s, contains('pn=Alex%20Kumar'));
      expect(s, isNot(contains('+')));
      expect(s, contains('am=300.00'));
      expect(s, contains('cu=INR'));
      expect(uri.queryParameters['tn'], 'PaisaSplit · Flatmates');
    });

    test('omits an empty note and truncates a long one', () {
      expect(
        PaymentLinks.upi(upiId: 'a@ybl', payeeName: 'A', amount: 1).toString(),
        isNot(contains('tn=')),
      );
      final long = PaymentLinks.upi(
        upiId: 'a@ybl',
        payeeName: 'A',
        amount: 1,
        note: 'x' * 100,
      );
      expect(long.queryParameters['tn']!.length, 40);
    });

    test('only offered for rupees', () {
      expect(PaymentLinks.supportsUpi('INR'), isTrue);
      expect(PaymentLinks.supportsUpi('inr '), isTrue);
      expect(PaymentLinks.supportsUpi('USD'), isFalse);
    });
  });

  test('PaymentLinks.paypal puts amount and currency in the path', () {
    final uri = PaymentLinks.paypal(
      username: 'alexk',
      amount: 12.5,
      currency: 'usd',
    );
    expect(uri.toString(), 'https://paypal.me/alexk/12.50USD');
  });

  group('NetBalances.fromJson', () {
    Map<String, dynamic> person(String id, Map<String, num> byCurrency,
            List<Map<String, dynamic>> groups, {num? net}) =>
        {
          'user': {'id': id, 'name': id, 'upiId': '$id@ybl'},
          'net': net,
          'netByCurrency': byCurrency,
          'groups': groups,
        };

    test('nets across groups and drops people who are square', () {
      final nb = NetBalances.fromJson({
        'currency': 'INR',
        'totals': {'owed': 300, 'owe': 0},
        'people': [
          person('alex', {'INR': 300}, [
            {'groupId': 'g1', 'groupName': 'Flatmates', 'currency': 'INR', 'amount': 500},
            {'groupId': 'g2', 'groupName': 'Trip', 'currency': 'INR', 'amount': -200},
          ], net: 300),
          person('sam', {'INR': 0}, [], net: 0),
        ],
      });

      expect(nb.people, hasLength(1));
      final alex = nb.forPerson('alex')!;
      expect(alex.theyOweYou, isTrue);
      expect(alex.spansGroups, isTrue);
      expect(alex.isSingleCurrency, isTrue);
      expect(alex.settleAmount, 300);
      expect(alex.settleCurrency, 'INR');
      expect(alex.person.upiId, 'alex@ybl');
    });

    test('mixed currencies cannot be settled with one payment', () {
      final nb = NetBalances.fromJson({
        'currency': 'INR',
        'people': [
          person('sam', {'INR': 500, 'USD': -10}, [
            {'groupId': 'g1', 'groupName': 'Flat', 'currency': 'INR', 'amount': 500},
            {'groupId': 'g3', 'groupName': 'NYC', 'currency': 'USD', 'amount': -10},
          ]),
        ],
      });
      final sam = nb.people.single;
      expect(sam.net, isNull);
      expect(sam.isSingleCurrency, isFalse);
      expect(sam.settleAmount, isNull);
    });
  });

  test('BudgetStatus thresholds match the push alerts', () {
    BudgetStatus at(double percent) => BudgetStatus(
        category: 'Food & drink', amount: 100, spent: percent, percent: percent);
    expect(at(79).isNearLimit, isFalse);
    expect(at(80).isNearLimit, isTrue);
    expect(at(99).isExceeded, isFalse);
    expect(at(100).isExceeded, isTrue);
    expect(
      const BudgetStatus(category: kAllCategoriesBudget, amount: 1, spent: 0, percent: 0).label,
      'All spending',
    );
  });
}
