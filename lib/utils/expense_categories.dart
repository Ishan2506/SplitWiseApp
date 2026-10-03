import 'package:flutter/material.dart';

/// The categories an expense can be filed under, with the icon each shows.
/// The names are the values stored on the server (Expense.category), so
/// budgets and charts key off exactly these strings.
const Map<String, IconData> kExpenseCategories = {
  'Food & drink': Icons.restaurant_rounded,
  'Travel': Icons.flight_takeoff_rounded,
  'Accommodation': Icons.hotel_rounded,
  'Entertainment': Icons.movie_rounded,
  'Other': Icons.category_rounded,
};

/// The icon for [category], falling back to the generic one for a custom or
/// legacy value.
IconData iconForCategory(String category) =>
    kExpenseCategories[category] ?? Icons.category_rounded;
