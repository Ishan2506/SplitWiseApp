import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../model/group_model.dart';

/// The palette the group screens share with the rest of the app.
class GroupColors {
  static const background = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const surfaceAlt = Color(0xFF334155);
  static const primary = Color(0xFF0D9488);
  static const accent = Color(0xFF14B8A6);
  static const muted = Color(0xFF94A3B8);
  static const positive = Color(0xFF10B981);
  static const negative = Color(0xFFF43F5E);
  static const warning = Color(0xFFF59E0B);
}

/// Shows a group's photo, falling back to a tinted icon for its type.
///
/// Photos may be a remote URL or a `data:image/...;base64,...` string, which is
/// what the picker produces, so both are handled here.
class GroupAvatar extends StatelessWidget {
  final GroupModel? group;
  final GroupType type;
  final String photoUrl;
  final double size;
  final double radius;

  GroupAvatar({
    super.key,
    required this.group,
    this.size = 52,
    this.radius = 14,
  })  : type = group?.type ?? GroupType.other,
        photoUrl = group?.photoUrl ?? '';

  /// For screens that have a type and photo but no full group yet.
  const GroupAvatar.raw({
    super.key,
    required this.type,
    required this.photoUrl,
    this.size = 52,
    this.radius = 14,
  }) : group = null;

  /// Decodes a `data:` URI into bytes, or returns null if this is not one.
  static Uint8List? decodeDataUri(String value) {
    if (!value.startsWith('data:')) return null;
    final comma = value.indexOf(',');
    if (comma == -1) return null;
    try {
      return base64Decode(value.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(type.icon, color: type.color, size: size * 0.5),
    );

    if (photoUrl.isEmpty) return placeholder;

    final bytes = decodeDataUri(photoUrl);
    final image = bytes != null
        ? Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
          )
        : Image.network(
            photoUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : placeholder,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: image,
    );
  }
}

/// A small pill naming the group's type, e.g. "Trip".
class GroupTypeChip extends StatelessWidget {
  final GroupType type;
  final bool compact;

  const GroupTypeChip({super.key, required this.type, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: type.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: compact ? 11 : 13, color: type.color),
          SizedBox(width: compact ? 4 : 5),
          Text(
            type.label,
            style: TextStyle(
              color: type.color,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Visualises how much of a group's per-member balance limit is in use.
class BalanceLimitBar extends StatelessWidget {
  final double used;
  final double limit;
  final String currencySymbol;
  final String? label;

  const BalanceLimitBar({
    super.key,
    required this.used,
    required this.limit,
    required this.currencySymbol,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (limit <= 0) return const SizedBox.shrink();

    final ratio = (used / limit).clamp(0.0, 1.0);
    final exceeded = used > limit;
    // Green well inside the limit, amber as it approaches, red once past it.
    final color = exceeded
        ? GroupColors.negative
        : ratio > 0.8
            ? GroupColors.warning
            : GroupColors.positive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label ?? 'Balance limit',
              style: const TextStyle(color: GroupColors.muted, fontSize: 11),
            ),
            Text(
              '$currencySymbol${used.toStringAsFixed(0)} / $currencySymbol${limit.toStringAsFixed(0)}',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: GroupColors.surfaceAlt,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        if (exceeded)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Over the limit by $currencySymbol${(used - limit).toStringAsFixed(2)}',
              style: const TextStyle(
                color: GroupColors.negative,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// A member's avatar: their picture when they have one, initials otherwise.
class MemberAvatar extends StatelessWidget {
  final GroupMember member;
  final double radius;

  const MemberAvatar({super.key, required this.member, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: GroupColors.surfaceAlt,
      child: Text(
        member.initials,
        style: TextStyle(
          fontSize: radius * 0.7,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    if (member.avatarUrl.isEmpty) return fallback;

    final bytes = GroupAvatar.decodeDataUri(member.avatarUrl);
    if (bytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: GroupColors.surfaceAlt,
        backgroundImage: MemoryImage(bytes),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: GroupColors.surfaceAlt,
      backgroundImage: NetworkImage(member.avatarUrl),
      onBackgroundImageError: (_, __) {},
      child: null,
    );
  }
}

/// Shows a snackbar in the app's colours. Green for success, red for failure.
void showGroupSnack(BuildContext context, String message, {bool success = true}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success ? GroupColors.primary : GroupColors.negative,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
}

/// The standard dark-theme decoration for text fields on these screens.
InputDecoration groupFieldDecoration({
  required String label,
  String? hint,
  Widget? prefix,
  Widget? suffix,
  String? helper,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperStyle: const TextStyle(color: GroupColors.muted, fontSize: 11),
    labelStyle: const TextStyle(color: GroupColors.muted),
    hintStyle: const TextStyle(color: Color(0xFF64748B)),
    prefixIcon: prefix,
    suffixIcon: suffix,
    filled: true,
    fillColor: GroupColors.background,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: GroupColors.surfaceAlt),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: GroupColors.primary, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: GroupColors.negative),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: GroupColors.negative, width: 1.6),
    ),
  );
}
