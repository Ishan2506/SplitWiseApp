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
  final String description;
  final double amount;
  final DateTime date;
  final String paidById;
  final SplitType splitType;
  final Map<String, double> splits; // memberId -> split value (amount/percent)
  final String? groupId; // null if individual expense

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.paidById,
    required this.splitType,
    required this.splits,
    this.groupId,
  });
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
