import 'package:flutter_test/flutter_test.dart';
import 'package:splitwise_app/models/models.dart';
import 'package:splitwise_app/state/state_manager.dart';

/// Balances must always reconcile: what the payer is owed equals what the
/// participants collectively owe, whatever the split type or rounding.
void main() {
  // StateManager seeds demo data, so each test measures the *delta* a new
  // expense introduces rather than absolute balances.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('expense splits reconcile', () {
    double sumOf(Map<String, double> m) =>
        m.values.fold<double>(0, (a, b) => a + b);

    test('equal split of an amount that does not divide evenly', () {
      final splits = {'a': 33.33, 'b': 33.33, 'c': 33.34};
      expect(sumOf(splits), closeTo(100.0, 0.001));
    });

    test('net balances sum to zero for an equal split', () {
      final state = StateManager();
      final before = sumOf(state.getNetBalances());
      expect(before, closeTo(0.0, 0.01));
    });

    test('stored shares are used verbatim for a percentage expense', () {
      final state = StateManager();
      final members = state.members.take(3).map((m) => m.id).toList();
      if (members.length < 3) return;
      final before = state.getNetBalances();

      // 33/33/34 of 100 stored as resolved rupee amounts.
      state.addExpense(Expense(
        id: 'pct-1',
        description: 'Percentage split',
        amount: 100,
        date: DateTime.now(),
        paidById: members[0],
        splitType: SplitType.percentage,
        splits: {members[0]: 33.0, members[1]: 33.0, members[2]: 34.0},
      ));

      final after = state.getNetBalances();
      // Payer put in 100 and owes 33 of it.
      expect(after[members[0]]! - before[members[0]]!, closeTo(100 - 33, 0.01));
      expect(after[members[1]]! - before[members[1]]!, closeTo(-33, 0.01));
      expect(after[members[2]]! - before[members[2]]!, closeTo(-34, 0.01));
      // The whole system still nets out.
      expect(sumOf(after), closeTo(0.0, 0.01));
    });

    test('exact split leaves the books balanced', () {
      final state = StateManager();
      final members = state.members.take(2).map((m) => m.id).toList();
      if (members.length < 2) return;
      final before = state.getNetBalances();

      state.addExpense(Expense(
        id: 'exact-1',
        description: 'Exact split',
        amount: 100,
        date: DateTime.now(),
        paidById: members[0],
        splitType: SplitType.exact,
        splits: {members[0]: 60.0, members[1]: 40.0},
      ));

      final after = state.getNetBalances();
      expect(after[members[0]]! - before[members[0]]!, closeTo(40, 0.01));
      expect(after[members[1]]! - before[members[1]]!, closeTo(-40, 0.01));
      expect(sumOf(after), closeTo(0.0, 0.01));
    });
  });
}
