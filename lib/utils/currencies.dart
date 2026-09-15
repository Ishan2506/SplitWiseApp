/// The currencies the app offers, in one place so the profile picker, the
/// currency screen and any group-level choice all agree on the same list.
class AppCurrency {
  final String code;
  final String symbol;
  final String name;

  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.name,
  });
}

/// Ordered for an India-first audience, then the currencies people here are
/// most likely to split in while travelling or paying for software.
const List<AppCurrency> kCurrencies = [
  AppCurrency(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
  AppCurrency(code: 'USD', symbol: '\$', name: 'US Dollar'),
  AppCurrency(code: 'EUR', symbol: '€', name: 'Euro'),
  AppCurrency(code: 'GBP', symbol: '£', name: 'British Pound'),
  AppCurrency(code: 'AED', symbol: 'د.إ', name: 'UAE Dirham'),
  AppCurrency(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar'),
  AppCurrency(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar'),
  AppCurrency(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar'),
  AppCurrency(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
  AppCurrency(code: 'CHF', symbol: 'CHF', name: 'Swiss Franc'),
];

/// The default used when a user has no preference stored.
const String kDefaultCurrencyCode = 'INR';

/// Looks up a currency by code, falling back to the default rather than
/// returning null — callers always have something to render.
AppCurrency currencyFor(String? code) {
  final wanted = (code ?? '').toUpperCase().trim();
  for (final c in kCurrencies) {
    if (c.code == wanted) return c;
  }
  return kCurrencies.first;
}

/// The symbol for a code. Unknown codes render as the code itself with a
/// trailing space, matching how group amounts already behave.
String currencySymbolFor(String? code) {
  final wanted = (code ?? '').toUpperCase().trim();
  for (final c in kCurrencies) {
    if (c.code == wanted) return c.symbol;
  }
  return wanted.isEmpty ? kCurrencies.first.symbol : '$wanted ';
}
