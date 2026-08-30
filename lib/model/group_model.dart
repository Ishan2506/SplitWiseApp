import 'package:flutter/material.dart';

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

  const GroupMember({
    required this.id,
    required this.name,
    this.email,
    this.mobileNumber,
    this.avatarUrl = '',
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: json['name'] ?? '',
      email: json['email'],
      mobileNumber: json['mobileNumber'],
      avatarUrl: json['avatarUrl'] ?? '',
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
    );
  }

  bool isCreatedBy(String userId) => createdById == userId;

  bool hasMember(String userId) => members.any((m) => m.id == userId);

  bool get hasBalanceLimit => balanceLimit > 0;

  /// The currency symbol used throughout the group's screens.
  String get currencySymbol {
    switch (currency.toUpperCase()) {
      case 'INR':
        return '₹';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return '$currency ';
    }
  }
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
