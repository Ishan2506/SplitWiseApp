import 'package:flutter/material.dart';

import '../utils/currencies.dart';

/// The kinds of group the app offers. The wire values match the backend's
/// `GROUP_TYPES` enum exactly — keep the two in step.
enum GroupType { family, friends, couple, trip, office, other }

extension GroupTypeInfo on GroupType {
  /// The value sent to and received from the API.
  String get wireValue => name;

  String get label {
    switch (this) {
      case GroupType.family:
        return 'Family';
      case GroupType.friends:
        return 'Friends';
      case GroupType.couple:
        return 'Couple';
      case GroupType.trip:
        return 'Trip';
      case GroupType.office:
        return 'Office';
      case GroupType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case GroupType.family:
        return Icons.family_restroom;
      case GroupType.friends:
        return Icons.groups;
      case GroupType.couple:
        return Icons.favorite;
      case GroupType.trip:
        return Icons.flight_takeoff;
      case GroupType.office:
        return Icons.business_center;
      case GroupType.other:
        return Icons.category;
    }
  }

  Color get color {
    switch (this) {
      case GroupType.family:
        return const Color(0xFFF59E0B);
      case GroupType.friends:
        return const Color(0xFF14B8A6);
      case GroupType.couple:
        return const Color(0xFFEC4899);
      case GroupType.trip:
        return const Color(0xFF3B82F6);
      case GroupType.office:
        return const Color(0xFF8B5CF6);
      case GroupType.other:
        return const Color(0xFF94A3B8);
    }
  }

  /// A short line shown under the type in the picker.
  String get hint {
    switch (this) {
      case GroupType.family:
        return 'Household bills and shared costs';
      case GroupType.friends:
        return 'Nights out, plans and hangouts';
      case GroupType.couple:
        return 'Just the two of you';
      case GroupType.trip:
        return 'Travel, stays and getting around';
      case GroupType.office:
        return 'Team lunches and work expenses';
      case GroupType.other:
        return 'Anything else';
    }
  }

  static GroupType fromWire(String? value) {
    return GroupType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => GroupType.other,
    );
  }
}

/// A person in a group, as returned by the API.
class GroupMember {
  final String id;
  final String name;
  final String? email;
  final String? mobileNumber;
  final String avatarUrl;

  /// Where this member wants to be paid — empty when they have not set one.
  final String upiId;
  final String paypalMe;

  const GroupMember({
    required this.id,
    required this.name,
    this.email,
    this.mobileNumber,
    this.avatarUrl = '',
    this.upiId = '',
    this.paypalMe = '',
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: json['name'] ?? '',
      email: json['email'],
      mobileNumber: json['mobileNumber'],
      avatarUrl: json['avatarUrl'] ?? '',
      upiId: json['upiId'] ?? '',
      paypalMe: json['paypalMe'] ?? '',
    );
  }

  String get initials {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}

/// An invitation sent to someone who is not on the app yet.
class PendingInvite {
  final String id;
  final String? email;
  final String? mobileNumber;
  final DateTime? invitedAt;

  const PendingInvite({
    required this.id,
    this.email,
    this.mobileNumber,
    this.invitedAt,
  });

  factory PendingInvite.fromJson(Map<String, dynamic> json) {
    return PendingInvite(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      email: json['email'],
      mobileNumber: json['mobileNumber'],
      invitedAt:
          json['invitedAt'] != null ? DateTime.tryParse(json['invitedAt']) : null,
    );
  }

  /// Whichever contact detail the invite was addressed to.
  String get contact => email ?? mobileNumber ?? 'Unknown';
}

/// The shareable join artefacts for a group: the code itself, the https link
/// people can tap, and the payload encoded into the QR image.
class GroupInvite {
  final String code;
  final String link;
  final String deepLink;
  final String qrPayload;
  final bool enabled;
  final DateTime? expiresAt;

  const GroupInvite({
    required this.code,
    required this.link,
    required this.deepLink,
    required this.qrPayload,
    required this.enabled,
    this.expiresAt,
  });

  factory GroupInvite.fromJson(Map<String, dynamic> json) {
    return GroupInvite(
      code: json['code'] ?? '',
      link: json['link'] ?? '',
      deepLink: json['deepLink'] ?? '',
      qrPayload: json['qrPayload'] ?? json['link'] ?? '',
      enabled: json['enabled'] ?? true,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'])
          : null,
    );
  }

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  /// Whether the code can be redeemed right now.
  bool get isActive => enabled && !isExpired;
}

/// A group as the API models it.
class GroupModel {
  final String id;
  final String name;
  final String description;
  final GroupType type;
  final String photoUrl;

  /// Per-member spending guard. 0 means no limit.
  final double balanceLimit;
  final String currency;
  final String createdById;
  final String createdByName;
  final List<GroupMember> members;
  final List<PendingInvite> pendingInvites;
  final GroupInvite? invite;
  final DateTime? updatedAt;

  /// A remembered split ratio (userId -> percentage, summing to 100), so a
  /// new expense in this group can start from it instead of an even split.
  /// Null means no default is set.
  final Map<String, double>? defaultSplit;

  const GroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.photoUrl,
    required this.balanceLimit,
    required this.currency,
    required this.createdById,
    required this.createdByName,
    required this.members,
    this.pendingInvites = const [],
    this.invite,
    this.updatedAt,
    this.defaultSplit,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    // `createdBy` arrives populated on most endpoints but can be a bare id.
    final createdBy = json['createdBy'];
    String createdById = '';
    String createdByName = '';
    if (createdBy is Map) {
      createdById = (createdBy['_id'] ?? createdBy['id'] ?? '').toString();
      createdByName = createdBy['name'] ?? '';
    } else if (createdBy != null) {
      createdById = createdBy.toString();
    }

    return GroupModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      type: GroupTypeInfo.fromWire(json['type']),
      photoUrl: json['photoUrl'] ?? '',
      balanceLimit: (json['balanceLimit'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'INR',
      createdById: createdById,
      createdByName: createdByName,
      members: (json['members'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(GroupMember.fromJson)
          .toList(),
      pendingInvites: (json['invites'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PendingInvite.fromJson)
          .toList(),
      invite: json['invite'] != null
          ? GroupInvite.fromJson(Map<String, dynamic>.from(json['invite']))
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
      defaultSplit: _defaultSplitFrom(json['defaultSplit']),
    );
  }

  static Map<String, double>? _defaultSplitFrom(dynamic raw) {
    if (raw is! List || raw.isEmpty) return null;
    final map = <String, double>{};
    for (final entry in raw) {
      if (entry is! Map) continue;
      final user = entry['user'];
      final id = user is Map
          ? (user['_id'] ?? user['id'] ?? '').toString()
          : (user ?? '').toString();
      if (id.isEmpty) continue;
      map[id] = (entry['percentage'] as num?)?.toDouble() ?? 0.0;
    }
    return map.isEmpty ? null : map;
  }

  bool isCreatedBy(String userId) => createdById == userId;

  bool hasMember(String userId) => members.any((m) => m.id == userId);

  GroupMember? memberById(String userId) {
    for (final m in members) {
      if (m.id == userId) return m;
    }
    return null;
  }

  bool get hasBalanceLimit => balanceLimit > 0;

  bool get hasDefaultSplit => defaultSplit != null && defaultSplit!.isNotEmpty;

  /// The currency symbol used throughout the group's screens. Resolved from
  /// the shared catalogue so this and the currency picker never disagree.
  String get currencySymbol => currencySymbolFor(currency);
}

/// One member's standing in a group, including how much of the group's
/// balance limit they have used.
class MemberBalance {
  final String userId;
  final String name;
  final String avatarUrl;
  final double balance;
  final double limitUsed;
  final bool limitExceeded;

  const MemberBalance({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.balance,
    required this.limitUsed,
    required this.limitExceeded,
  });

  factory MemberBalance.fromJson(Map<String, dynamic> json) {
    final user = Map<String, dynamic>.from(json['user'] ?? {});
    return MemberBalance(
      userId: (user['id'] ?? user['_id'] ?? '').toString(),
      name: user['name'] ?? '',
      avatarUrl: user['avatarUrl'] ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      limitUsed: (json['limitUsed'] as num?)?.toDouble() ?? 0.0,
      limitExceeded: json['limitExceeded'] ?? false,
    );
  }
}

/// A suggested "who pays whom" transfer that settles the group.
class SettlementSuggestion {
  final String fromId;
  final String fromName;
  final String toId;
  final String toName;
  final double amount;

  const SettlementSuggestion({
    required this.fromId,
    required this.fromName,
    required this.toId,
    required this.toName,
    required this.amount,
  });

  factory SettlementSuggestion.fromJson(Map<String, dynamic> json) {
    final from = Map<String, dynamic>.from(json['from'] ?? {});
    final to = Map<String, dynamic>.from(json['to'] ?? {});
    return SettlementSuggestion(
      fromId: (from['id'] ?? '').toString(),
      fromName: from['name'] ?? '',
      toId: (to['id'] ?? '').toString(),
      toName: to['name'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Everything the balances endpoint returns for one group.
class GroupBalances {
  final List<MemberBalance> balances;
  final List<SettlementSuggestion> suggestions;
  final double balanceLimit;
  final String currency;

  const GroupBalances({
    required this.balances,
    required this.suggestions,
    required this.balanceLimit,
    required this.currency,
  });

  const GroupBalances.empty()
      : balances = const [],
        suggestions = const [],
        balanceLimit = 0,
        currency = 'INR';

  factory GroupBalances.fromJson(Map<String, dynamic> json) {
    return GroupBalances(
      balances: (json['balances'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(MemberBalance.fromJson)
          .toList(),
      suggestions: (json['suggestions'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(SettlementSuggestion.fromJson)
          .toList(),
      balanceLimit: (json['balanceLimit'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'INR',
    );
  }

  double balanceFor(String userId) {
    for (final b in balances) {
      if (b.userId == userId) return b.balance;
    }
    return 0.0;
  }
}

/// The `category` value a budget uses to mean "all spending in the group".
/// Matches the server's `ALL_CATEGORIES`.
const String kAllCategoriesBudget = 'All';

/// One monthly budget and how much of it has gone this month.
class BudgetStatus {
  final String category;
  final double amount;
  final double spent;
  final double percent;

  const BudgetStatus({
    required this.category,
    required this.amount,
    required this.spent,
    required this.percent,
  });

  factory BudgetStatus.fromJson(Map<String, dynamic> json) {
    return BudgetStatus(
      category: json['category'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      spent: (json['spent'] as num?)?.toDouble() ?? 0.0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  bool get isOverall => category == kAllCategoriesBudget;

  /// What to call it on screen.
  String get label => isOverall ? 'All spending' : category;

  double get remaining => amount - spent;

  bool get isExceeded => percent >= 100;

  /// Past the 80% line members are warned at.
  bool get isNearLimit => percent >= 80;
}

/// Everything the budgets endpoint returns for one group.
class GroupBudgets {
  /// 'YYYY-MM' — the month these figures cover.
  final String month;
  final String currency;
  final List<BudgetStatus> budgets;

  /// This month's spend per category (plus [kAllCategoriesBudget] for the
  /// total), including categories with no budget — handy when picking one.
  final Map<String, double> spend;

  const GroupBudgets({
    required this.month,
    required this.currency,
    required this.budgets,
    required this.spend,
  });

  const GroupBudgets.empty()
      : month = '',
        currency = 'INR',
        budgets = const [],
        spend = const {};

  factory GroupBudgets.fromJson(Map<String, dynamic> json) {
    final rawSpend = json['spend'];
    return GroupBudgets(
      month: json['month'] ?? '',
      currency: json['currency'] ?? 'INR',
      budgets: (json['budgets'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(BudgetStatus.fromJson)
          .toList(),
      spend: rawSpend is Map
          ? {
              for (final e in rawSpend.entries)
                e.key.toString(): (e.value as num?)?.toDouble() ?? 0.0,
            }
          : const {},
    );
  }

  bool get isEmpty => budgets.isEmpty;
}

/// The other side of a cross-group balance: who they are and how to pay them.
class BalancePerson {
  final String id;
  final String name;
  final String avatarUrl;
  final String upiId;
  final String paypalMe;

  const BalancePerson({
    required this.id,
    required this.name,
    this.avatarUrl = '',
    this.upiId = '',
    this.paypalMe = '',
  });

  factory BalancePerson.fromJson(Map<String, dynamic> json) {
    return BalancePerson(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: json['name'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      upiId: json['upiId'] ?? '',
      paypalMe: json['paypalMe'] ?? '',
    );
  }
}

/// One group's contribution to a [PersonBalance]. Positive means they owe
/// the signed-in user; negative means the user owes them.
class PersonGroupDebt {
  final String groupId;
  final String groupName;
  final String currency;
  final double amount;

  const PersonGroupDebt({
    required this.groupId,
    required this.groupName,
    required this.currency,
    required this.amount,
  });

  factory PersonGroupDebt.fromJson(Map<String, dynamic> json) {
    return PersonGroupDebt(
      groupId: (json['groupId'] ?? '').toString(),
      groupName: json['groupName'] ?? '',
      currency: json['currency'] ?? 'INR',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get currencySymbol => currencySymbolFor(currency);
}

/// Where the signed-in user stands with one person across every group they
/// share, netted into a single figure.
class PersonBalance {
  final BalancePerson person;

  /// In [NetBalances.currency]. Null when a group's currency could not be
  /// converted — show [netByCurrency] instead.
  final double? net;
  final Map<String, double> netByCurrency;
  final List<PersonGroupDebt> groups;

  const PersonBalance({
    required this.person,
    required this.net,
    required this.netByCurrency,
    required this.groups,
  });

  factory PersonBalance.fromJson(Map<String, dynamic> json) {
    final rawByCurrency = json['netByCurrency'];
    return PersonBalance(
      person: BalancePerson.fromJson(Map<String, dynamic>.from(json['user'] ?? {})),
      net: (json['net'] as num?)?.toDouble(),
      netByCurrency: rawByCurrency is Map
          ? {
              for (final e in rawByCurrency.entries)
                e.key.toString(): (e.value as num?)?.toDouble() ?? 0.0,
            }
          : const {},
      groups: (json['groups'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PersonGroupDebt.fromJson)
          .toList(),
    );
  }

  /// Every group involved uses one currency, so the net can be settled in
  /// one payment — the server refuses a cross-currency "settle all".
  bool get isSingleCurrency => netByCurrency.length == 1;

  /// The currency a single settling payment would be made in.
  String? get settleCurrency =>
      isSingleCurrency ? netByCurrency.keys.first : null;

  /// The net in [settleCurrency], when there is exactly one.
  double? get settleAmount =>
      isSingleCurrency ? netByCurrency.values.first : null;

  bool get theyOweYou => (net ?? settleAmount ?? 0) > 0;

  bool get isSettled =>
      netByCurrency.values.every((v) => v.abs() < 0.01);

  /// More than one group is being netted together — the case this view
  /// exists for.
  bool get spansGroups => groups.length > 1;
}

/// The cross-group "who owes whom" for the signed-in user.
class NetBalances {
  final String currency;
  final List<PersonBalance> people;
  final double totalOwed;
  final double totalOwe;

  const NetBalances({
    required this.currency,
    required this.people,
    required this.totalOwed,
    required this.totalOwe,
  });

  const NetBalances.empty()
      : currency = 'INR',
        people = const [],
        totalOwed = 0,
        totalOwe = 0;

  factory NetBalances.fromJson(Map<String, dynamic> json) {
    final totals = Map<String, dynamic>.from(json['totals'] ?? {});
    return NetBalances(
      currency: json['currency'] ?? 'INR',
      people: (json['people'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PersonBalance.fromJson)
          .where((p) => !p.isSettled)
          .toList(),
      totalOwed: (totals['owed'] as num?)?.toDouble() ?? 0.0,
      totalOwe: (totals['owe'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get currencySymbol => currencySymbolFor(currency);

  PersonBalance? forPerson(String userId) {
    for (final p in people) {
      if (p.person.id == userId) return p;
    }
    return null;
  }
}

/// What the join screen shows before the user commits to joining.
class InvitePreview {
  final String groupId;
  final String name;
  final String description;
  final GroupType type;
  final String photoUrl;
  final int memberCount;
  final String createdByName;
  final bool active;
  final bool alreadyMember;

  const InvitePreview({
    required this.groupId,
    required this.name,
    required this.description,
    required this.type,
    required this.photoUrl,
    required this.memberCount,
    required this.createdByName,
    required this.active,
    required this.alreadyMember,
  });

  factory InvitePreview.fromJson(Map<String, dynamic> json) {
    final group = Map<String, dynamic>.from(json['group'] ?? {});
    final createdBy = group['createdBy'];
    return InvitePreview(
      groupId: (group['id'] ?? group['_id'] ?? '').toString(),
      name: group['name'] ?? '',
      description: group['description'] ?? '',
      type: GroupTypeInfo.fromWire(group['type']),
      photoUrl: group['photoUrl'] ?? '',
      memberCount: (group['memberCount'] as num?)?.toInt() ?? 0,
      createdByName: createdBy is Map ? (createdBy['name'] ?? '') : '',
      active: json['active'] ?? false,
      alreadyMember: json['alreadyMember'] ?? false,
    );
  }
}
