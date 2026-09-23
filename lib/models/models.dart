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
  final String paidById;
  final SplitType splitType;
  final Map<String, double> splits; // memberId -> split value (amount/percent)
  final String? groupId; // null if individual expense
  final String? notes;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.paidById,
    required this.splitType,
    required this.splits,
    this.category = 'Other',
    this.groupId,
    this.notes,
  });

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

    return Expense(
      id: idOf(json['_id'] ?? json['id']),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] as String?)?.isEmpty ?? true
          ? 'Other'
          : json['category'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.tryParse((json['date'] ?? '').toString())?.toLocal() ??
          DateTime.now(),
      paidById: idOf(json['paidBy']),
      splitType: _splitTypeFrom(json['splitType']),
      splits: splits,
      groupId: idOf(json['group']).isEmpty ? null : idOf(json['group']),
      notes: (json['notes'] as String?)?.isEmpty ?? true
          ? null
          : json['notes'] as String,
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
