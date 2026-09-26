enum SplitType { equal, exact, percentage }

class Member {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;

  Member({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
  });

  String get initials {
    if (name.isEmpty) return "?";
    final parts = name.trim().split(" ");
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}

class Group {
  final String id;
  final String name;
  final String description;
  final List<String> memberIds;
  final String category; // e.g. "Trip", "Home", "Dining", "Other"

  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.memberIds,
    required this.category,
  });
}

class Expense {
  final String id;

  /// What this expense was for, specifically — "Tea", "Cab to airport". Free
  /// text the user types, distinct from [category].
  final String description;

  /// The broad kind of spend this falls under — "Food & drink", "Travel".
  final String category;
  final double amount;
  final DateTime date;

  /// The primary payer — whoever fronted the most, or the sole payer for the
  /// common single-payer case. Kept for every call site that only needs one
  /// "paid by" name; the real breakdown is [payers].
  final String paidById;

  /// Who actually paid, and how much of the total each of them fronted.
  /// Always has at least one entry. More than one means this was split
  /// between multiple payers (e.g. two cards covered one restaurant bill).
  final Map<String, double> payers;
  final SplitType splitType;
  final Map<String, double> splits; // memberId -> split value (amount/percent)
  final String? groupId; // null if individual expense
  final String? notes;

  /// Set only when this expense was entered in a currency other than the
  /// group's own — [amount] is always the converted, group-currency figure;
  /// these two are what was actually typed, kept purely for display.
  final double? originalAmount;
  final String? originalCurrency;

  /// The bill/receipt photo attached to this expense, if any — an absolute
  /// URL, same shape as a user's avatar. Empty when none was attached.
  final String receiptUrl;

  bool get hasMultiplePayers => payers.length > 1;
  bool get wasConverted => originalCurrency != null;
  bool get hasReceipt => receiptUrl.isNotEmpty;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.paidById,
    required this.splitType,
    required this.splits,
    Map<String, double>? payers,
    this.category = 'Other',
    this.groupId,
    this.notes,
    this.originalAmount,
    this.originalCurrency,
    this.receiptUrl = '',
  }) : payers = payers ?? {paidById: amount};

  /// Builds an expense from the server payload.
  ///
  /// The API returns `splits` as a list of `{user, amount}` where `user` may be
  /// a populated object or a bare id, and where `amount` is always the member's
  /// resolved share in rupees regardless of the split type.
  factory Expense.fromJson(Map<String, dynamic> json) {
    String idOf(dynamic value) {
      if (value is Map) return (value['_id'] ?? value['id'] ?? '').toString();
      return (value ?? '').toString();
    }

    final splits = <String, double>{};
    for (final raw in (json['splits'] as List? ?? [])) {
      if (raw is! Map) continue;
      final memberId = idOf(raw['user']);
      if (memberId.isEmpty) continue;
      splits[memberId] = (raw['amount'] as num?)?.toDouble() ?? 0.0;
    }

    final amount = (json['amount'] as num?)?.toDouble() ?? 0.0;
    final paidById = idOf(json['paidBy']);

    final payers = <String, double>{};
    for (final raw in (json['payers'] as List? ?? [])) {
      if (raw is! Map) continue;
      final uid = idOf(raw['user']);
      if (uid.isEmpty) continue;
      payers[uid] = (raw['amount'] as num?)?.toDouble() ?? 0.0;
    }
    // Older records (saved before multi-payer support) have no `payers`
    // array — fall back to the single payer/amount they do have.
    if (payers.isEmpty && paidById.isNotEmpty) {
      payers[paidById] = amount;
    }

    return Expense(
      id: idOf(json['_id'] ?? json['id']),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] as String?)?.isEmpty ?? true
          ? 'Other'
          : json['category'] as String,
      amount: amount,
      date: DateTime.tryParse((json['date'] ?? '').toString())?.toLocal() ??
          DateTime.now(),
      paidById: paidById,
      payers: payers,
      splitType: _splitTypeFrom(json['splitType']),
      splits: splits,
      groupId: idOf(json['group']).isEmpty ? null : idOf(json['group']),
      notes: (json['notes'] as String?)?.isEmpty ?? true
          ? null
          : json['notes'] as String,
      originalAmount: (json['originalAmount'] as num?)?.toDouble(),
      originalCurrency: (json['originalCurrency'] as String?)?.isEmpty ?? true
          ? null
          : json['originalCurrency'] as String,
      receiptUrl: (json['receiptUrl'] ?? '').toString(),
    );
  }

  static SplitType _splitTypeFrom(dynamic value) {
    switch ((value ?? '').toString()) {
      case 'exact':
        return SplitType.exact;
      case 'percentage':
        return SplitType.percentage;
      default:
        return SplitType.equal;
    }
  }

  /// Wire value the API expects for this split type.
  static String splitTypeToApi(SplitType type) {
    switch (type) {
      case SplitType.exact:
        return 'exact';
      case SplitType.percentage:
        return 'percentage';
      case SplitType.equal:
        return 'equal';
    }
  }
}

enum RecurringFrequency { weekly, fortnightly, monthly, yearly }

extension RecurringFrequencyLabel on RecurringFrequency {
  String get label => switch (this) {
        RecurringFrequency.weekly => 'Weekly',
        RecurringFrequency.fortnightly => 'Fortnightly',
        RecurringFrequency.monthly => 'Monthly',
        RecurringFrequency.yearly => 'Yearly',
      };

  String get api => switch (this) {
        RecurringFrequency.weekly => 'weekly',
        RecurringFrequency.fortnightly => 'fortnightly',
        RecurringFrequency.monthly => 'monthly',
        RecurringFrequency.yearly => 'yearly',
      };

  static RecurringFrequency fromApi(dynamic value) {
    switch ((value ?? '').toString()) {
      case 'fortnightly':
        return RecurringFrequency.fortnightly;
      case 'monthly':
        return RecurringFrequency.monthly;
      case 'yearly':
        return RecurringFrequency.yearly;
      default:
        return RecurringFrequency.weekly;
    }
  }
}

/// A template for an expense that repeats on a schedule — rent, a shared
/// subscription. The server turns a due one into a real [Expense]
/// automatically; this is just the recurring plan itself.
class RecurringExpense {
  final String id;
  final String groupId;
  final String description;
  final String category;
  final double amount;
  final String paidById;
  final Map<String, double> payers;
  final SplitType splitType;
  final Map<String, double> splits;
  final RecurringFrequency frequency;
  final DateTime nextRunDate;
  final bool active;
  final DateTime? lastRunAt;

  RecurringExpense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.paidById,
    required this.splitType,
    required this.splits,
    required this.frequency,
    required this.nextRunDate,
    this.category = 'Other',
    Map<String, double>? payers,
    this.active = true,
    this.lastRunAt,
  }) : payers = payers ?? {paidById: amount};

  factory RecurringExpense.fromJson(Map<String, dynamic> json) {
    String idOf(dynamic value) {
      if (value is Map) return (value['_id'] ?? value['id'] ?? '').toString();
      return (value ?? '').toString();
    }

    final splits = <String, double>{};
    for (final raw in (json['splits'] as List? ?? [])) {
      if (raw is! Map) continue;
      final memberId = idOf(raw['user']);
      if (memberId.isEmpty) continue;
      splits[memberId] = (raw['amount'] as num?)?.toDouble() ?? 0.0;
    }

    final payers = <String, double>{};
    for (final raw in (json['payers'] as List? ?? [])) {
      if (raw is! Map) continue;
      final uid = idOf(raw['user']);
      if (uid.isEmpty) continue;
      payers[uid] = (raw['amount'] as num?)?.toDouble() ?? 0.0;
    }

    return RecurringExpense(
      id: idOf(json['_id'] ?? json['id']),
      groupId: idOf(json['group']),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] as String?)?.isEmpty ?? true
          ? 'Other'
          : json['category'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paidById: idOf(json['paidBy']),
      payers: payers,
      splitType: Expense._splitTypeFrom(json['splitType']),
      splits: splits,
      frequency: RecurringFrequencyLabel.fromApi(json['frequency']),
      nextRunDate:
          DateTime.tryParse((json['nextRunDate'] ?? '').toString())?.toLocal() ??
              DateTime.now(),
      active: json['active'] as bool? ?? true,
      lastRunAt: json['lastRunAt'] == null
          ? null
          : DateTime.tryParse(json['lastRunAt'].toString())?.toLocal(),
    );
  }
}

/// One message in an expense's discussion thread.
class ExpenseComment {
  final String id;
  final String expenseId;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;

  ExpenseComment({
    required this.id,
    required this.expenseId,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  factory ExpenseComment.fromJson(Map<String, dynamic> json, {String? expenseId}) {
    String idOf(dynamic value) {
      if (value is Map) return (value['_id'] ?? value['id'] ?? '').toString();
      return (value ?? '').toString();
    }

    final author = json['author'];
    return ExpenseComment(
      id: idOf(json['_id'] ?? json['id']),
      expenseId: expenseId ?? idOf(json['expense']),
      authorId: idOf(author),
      authorName: author is Map ? (author['name'] ?? 'Someone').toString() : 'Someone',
      text: (json['text'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString())?.toLocal() ??
              DateTime.now(),
    );
  }
}

class Payment {
  final String id;
  final String fromMemberId;
  final String toMemberId;
  final double amount;
  final DateTime date;
  final String? groupId;

  Payment({
    required this.id,
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
    required this.date,
    this.groupId,
  });
}
