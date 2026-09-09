import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------

/// Formats amounts as ₹1,23,456 using the Indian grouping convention.
String formatMoney(num amount, {bool withSymbol = true, bool decimals = false}) {
  final negative = amount < 0;
  final value = amount.abs();
  final fixed = decimals ? value.toStringAsFixed(2) : value.round().toString();
  final parts = fixed.split('.');
  var digits = parts[0];

  String grouped;
  if (digits.length <= 3) {
    grouped = digits;
  } else {
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final buffer = <String>[];
    while (rest.length > 2) {
      buffer.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) buffer.insert(0, rest);
    grouped = '${buffer.join(',')},$last3';
  }

  final decimalPart = parts.length > 1 ? '.${parts[1]}' : '';
  return '${negative ? '-' : ''}${withSymbol ? '₹' : ''}$grouped$decimalPart';
}

/// Two-letter initials for an avatar.
String initialsOf(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

/// Constrains page content to a readable column and applies page padding.
///
/// On a phone this is just padding; on tablet and desktop it centres the
/// content so lines never stretch to an uncomfortable measure.
class PageContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? maxWidth;

  const PageContainer({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final horizontal = AppBreakpoints.pagePadding(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? AppBreakpoints.contentMaxWidth(context),
        ),
        child: Padding(
          padding: padding ?? EdgeInsets.symmetric(horizontal: horizontal),
          child: child,
        ),
      ),
    );
  }
}

/// A titled section with optional trailing action — the standard way to
/// introduce a list on any screen.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? subtitle;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// The base surface for everything card-shaped: white, hairline border, and a
/// whisper of shadow. Pass [onTap] to get the press and hover states for free.
class PSCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final List<BoxShadow>? shadow;

  const PSCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.color,
    this.borderColor,
    this.radius = AppRadius.lg,
    this.shadow,
  });

  @override
  State<PSCard> createState() => _PSCardState();
}

class _PSCardState extends State<PSCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final radius = BorderRadius.circular(widget.radius);

    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: interactive ? (_) => setState(() => _hovered = true) : null,
      onExit: interactive ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: interactive ? (_) => setState(() => _pressed = true) : null,
        onTapUp: interactive ? (_) => setState(() => _pressed = false) : null,
        onTapCancel:
            interactive ? () => setState(() => _pressed = false) : null,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          curve: Curves.easeOut,
          transform: _pressed
              ? (Matrix4.identity()..scaleByDouble(0.985, 0.985, 1.0, 1.0))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          padding: widget.padding ?? const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: widget.color ?? AppColors.bgPrimary,
            borderRadius: radius,
            border: Border.all(
              color: widget.borderColor ??
                  (_hovered ? AppColors.borderStrong : AppColors.border),
            ),
            boxShadow: widget.shadow ??
                (_hovered && interactive ? AppShadow.raised : AppShadow.card),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

enum PSButtonVariant { primary, secondary, accent, ghost, danger }
enum PSButtonSize { small, medium, large }

/// The app's button. [PSButtonVariant.primary] is the ink-filled default used
/// for the single main action on a screen; [secondary] is the outlined
/// companion; [accent] is reserved for pink emphasis such as "Settle up".
class PSButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final PSButtonVariant variant;
  final PSButtonSize size;
  final bool isLoading;
  final bool expand;
  final IconData? icon;

  const PSButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PSButtonVariant.primary,
    this.size = PSButtonSize.large,
    this.isLoading = false,
    this.expand = true,
    this.icon,
  });

  double get _height => switch (size) {
        PSButtonSize.small => 40,
        PSButtonSize.medium => 48,
        PSButtonSize.large => 54,
      };

  double get _fontSize => switch (size) {
        PSButtonSize.small => 14,
        PSButtonSize.medium => 15,
        PSButtonSize.large => 16,
      };

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    late final Color bg;
    late final Color fg;
    Color? borderColor;

    switch (variant) {
      case PSButtonVariant.primary:
        bg = AppColors.ink;
        fg = Colors.white;
      case PSButtonVariant.accent:
        bg = AppColors.primaryAccent;
        fg = Colors.white;
      case PSButtonVariant.danger:
        bg = AppColors.error;
        fg = Colors.white;
      case PSButtonVariant.secondary:
        bg = AppColors.bgPrimary;
        fg = AppColors.textPrimary;
        borderColor = AppColors.borderStrong;
      case PSButtonVariant.ghost:
        bg = Colors.transparent;
        fg = AppColors.textSecondary;
    }

    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: _fontSize + 3),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _fontSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          );

    final button = TextButton(
      onPressed: enabled ? onPressed : null,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.bgSubtle;
          if (states.contains(WidgetState.pressed)) {
            return switch (variant) {
              PSButtonVariant.primary => const Color(0xFF26262A),
              PSButtonVariant.accent => AppColors.primaryDark,
              PSButtonVariant.danger => AppColors.primaryDark,
              PSButtonVariant.secondary => AppColors.bgSubtle,
              PSButtonVariant.ghost => AppColors.bgSubtle,
            };
          }
          if (states.contains(WidgetState.hovered)) {
            return switch (variant) {
              PSButtonVariant.primary => const Color(0xFF1E1E22),
              PSButtonVariant.accent => AppColors.primaryDark,
              PSButtonVariant.danger => AppColors.primaryDark,
              PSButtonVariant.secondary => AppColors.bgSecondary,
              PSButtonVariant.ghost => AppColors.bgSubtle,
            };
          }
          return bg;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled) ? AppColors.muted : fg),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        minimumSize: WidgetStatePropertyAll(Size(expand ? 0 : 0, _height)),
        fixedSize: WidgetStatePropertyAll(Size.fromHeight(_height)),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(
              horizontal: size == PSButtonSize.small ? 16 : 24),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(_height / 2)),
        ),
        side: WidgetStateProperty.resolveWith((states) {
          if (borderColor == null) return BorderSide.none;
          if (states.contains(WidgetState.disabled)) {
            return const BorderSide(color: AppColors.borderLight);
          }
          return BorderSide(color: borderColor);
        }),
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: _fontSize, fontWeight: FontWeight.w700),
        ),
      ),
      child: child,
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

// ---------------------------------------------------------------------------
// Inputs
// ---------------------------------------------------------------------------

/// A labelled text field. The label sits above the box rather than floating
/// inside it, which keeps forms scannable when several fields stack up.
class PSTextField extends StatefulWidget {
  final String label;
  final String? placeholder;
  final String? helperText;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final int? minLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? prefixText;
  final bool showLabel;
  final bool enabled;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  const PSTextField({
    super.key,
    required this.label,
    this.placeholder,
    this.helperText,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.minLines,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixText,
    this.showLabel = true,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction,
    this.inputFormatters,
    this.maxLength,
  });

  @override
  State<PSTextField> createState() => _PSTextFieldState();
}

class _PSTextFieldState extends State<PSTextField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLabel) ...[
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: _obscure,
          validator: widget.validator,
          onChanged: widget.onChanged,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          textInputAction: widget.textInputAction,
          inputFormatters: widget.inputFormatters,
          maxLength: widget.maxLength,
          maxLines: _obscure ? 1 : widget.maxLines,
          minLines: widget.minLines,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            helperText: widget.helperText,
            helperStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
            counterText: '',
            prefixText: widget.prefixText,
            prefixStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.suffixIcon ??
                (widget.obscureText
                    ? IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                        color: AppColors.muted,
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                      )
                    : null),
          ),
        ),
      ],
    );
  }
}

/// Pill-shaped search box used on the history and group lists.
class PSSearchField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  const PSSearchField({
    super.key,
    this.hint = 'Search',
    this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: const BorderSide(color: AppColors.primaryAccent, width: 1.5),
        ),
      ),
    );
  }
}

/// Horizontally scrolling filter chips.
class PSFilterChips extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const PSFilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        padding: EdgeInsets.zero,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) {
          final option = options[i];
          final isSelected = option == selected;
          return GestureDetector(
            onTap: () => onSelected(option),
            child: AnimatedContainer(
              duration: AppDuration.fast,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.ink : AppColors.bgPrimary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: isSelected ? AppColors.ink : AppColors.border,
                ),
              ),
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------

/// Circular initials avatar. Colour is derived from the name so the same
/// person keeps the same tint everywhere in the app.
class AvatarWidget extends StatelessWidget {
  final String initials;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;
  final String? emoji;
  final String? imageUrl;
  final bool showBorder;

  const AvatarWidget({
    super.key,
    required this.initials,
    this.size = 44,
    this.backgroundColor,
    this.textColor,
    this.emoji,
    this.imageUrl,
    this.showBorder = false,
  });

  /// Builds an avatar whose tint is picked deterministically from [name].
  factory AvatarWidget.forName(
    String name, {
    double size = 44,
    bool showBorder = false,
    String? imageUrl,
  }) {
    final index = name.isEmpty
        ? 0
        : name.codeUnits.fold<int>(0, (a, b) => a + b) %
            AppColors.avatarTints.length;
    return AvatarWidget(
      initials: initialsOf(name),
      size: size,
      backgroundColor: AppColors.avatarTints[index],
      textColor: AppColors.avatarInk[index],
      showBorder: showBorder,
      imageUrl: imageUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.bgSubtle,
        shape: BoxShape.circle,
        border: showBorder ? Border.all(color: Colors.white, width: 2.5) : null,
        image: imageUrl != null && imageUrl!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(imageUrl!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? null
          : emoji != null
              ? Text(emoji!, style: TextStyle(fontSize: size * 0.45))
              : Text(
                  initials,
                  style: TextStyle(
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w800,
                    color: textColor ?? AppColors.textSecondary,
                    letterSpacing: -0.2,
                  ),
                ),
    );
  }
}

/// Overlapping avatar row used to preview a group's members.
class AvatarStack extends StatelessWidget {
  final List<String> names;
  final double size;
  final int max;

  const AvatarStack({
    super.key,
    required this.names,
    this.size = 30,
    this.max = 4,
  });

  @override
  Widget build(BuildContext context) {
    final shown = names.take(max).toList();
    final overflow = names.length - shown.length;
    final overlap = size * 0.32;

    return SizedBox(
      height: size,
      width: shown.isEmpty
          ? 0
          : size + (shown.length - 1) * (size - overlap) +
              (overflow > 0 ? size - overlap : 0),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: AvatarWidget.forName(shown[i], size: size, showBorder: true),
            ),
          if (overflow > 0)
            Positioned(
              left: shown.length * (size - overlap),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppColors.bgSubtle,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$overflow',
                  style: TextStyle(
                    fontSize: size * 0.3,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status
// ---------------------------------------------------------------------------

enum BadgeTone { neutral, positive, negative, accent, warning }

/// Small pill label for statuses such as "Settled" or "You owe".
class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeTone tone;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;

  const StatusBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      BadgeTone.neutral => (AppColors.bgSubtle, AppColors.textSecondary),
      BadgeTone.positive => (AppColors.successLight, AppColors.success),
      BadgeTone.negative => (AppColors.primaryLight, AppColors.primaryDark),
      BadgeTone.accent => (AppColors.primarySurface, AppColors.primaryAccent),
      BadgeTone.warning => (AppColors.warningLight, AppColors.warning),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor ?? bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor ?? fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor ?? fg,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Uppercase caption used above figures ("YOU OWE", "TOTAL").
class OverlineLabel extends StatelessWidget {
  final String text;
  final Color? color;

  const OverlineLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: color ?? AppColors.muted,
      ),
    );
  }
}

/// A figure with its caption — the building block of the balance summary.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Color? background;
  final Color? borderColor;
  final Color? labelColor;
  final String? caption;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.background,
    this.borderColor,
    this.labelColor,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: background ?? AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          OverlineLabel(label, color: labelColor),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                )),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lists
// ---------------------------------------------------------------------------

/// A group in a list: icon tile, name, member count, and the user's balance.
class GroupCard extends StatelessWidget {
  final String groupName;
  final String description;
  final String? emoji;
  final IconData? icon;
  final Color? iconColor;
  final String amount;
  final String amountLabel;
  final Color amountColor;
  final VoidCallback? onTap;
  final bool isSettled;
  final List<String> memberNames;

  const GroupCard({
    super.key,
    required this.groupName,
    required this.description,
    this.emoji,
    this.icon,
    this.iconColor,
    required this.amount,
    required this.amountLabel,
    this.amountColor = AppColors.textPrimary,
    this.onTap,
    this.isSettled = false,
    this.memberNames = const [],
  });

  @override
  Widget build(BuildContext context) {
    return PSCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.textSecondary).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: emoji != null && emoji!.isNotEmpty
                ? Text(emoji!, style: const TextStyle(fontSize: 22))
                : Icon(icon ?? Icons.groups_rounded,
                    size: 21, color: iconColor ?? AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  groupName,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (memberNames.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  AvatarStack(names: memberNames, size: 24),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (isSettled)
            const StatusBadge(
              label: 'Settled',
              tone: BadgeTone.positive,
              icon: Icons.check_rounded,
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                OverlineLabel(amountLabel),
                const SizedBox(height: 3),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: amountColor,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A single expense row: date tile, title, who paid, and the amount.
class ExpenseItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final String? emoji;
  final String? day;
  final String? month;
  final Color? amountColor;
  final String? trailingLabel;
  final VoidCallback? onTap;

  const ExpenseItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.emoji,
    this.day,
    this.month,
    this.amountColor,
    this.trailingLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PSCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.bgSubtle,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: day != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        day!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (month ?? '').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          height: 1,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  )
                : Text(emoji ?? '🧾', style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                amount,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: amountColor ?? AppColors.textPrimary,
                ),
              ),
              if (trailingLabel != null) ...[
                const SizedBox(height: 2),
                OverlineLabel(trailingLabel!),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A member and where they stand — used in the group balance list.
class BalanceRow extends StatelessWidget {
  final String name;
  final String label;
  final String amount;
  final Color amountColor;
  final VoidCallback? onTap;

  const BalanceRow({
    super.key,
    required this.name,
    required this.label,
    required this.amount,
    required this.amountColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
          child: Row(
            children: [
              AvatarWidget.forName(name, size: 38),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  OverlineLabel(label),
                  const SizedBox(height: 2),
                  Text(
                    amount,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: amountColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feedback
// ---------------------------------------------------------------------------

/// Polished empty state: a soft icon medallion, a clear line about what is
/// missing, and the action that fixes it.
class EmptyStateWidget extends StatelessWidget {
  final String? icon;
  final IconData? iconData;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButtonPressed;
  final bool compact;

  const EmptyStateWidget({
    super.key,
    this.icon,
    this.iconData,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButtonPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: compact ? AppSpacing.xl : AppSpacing.xxxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: iconData != null
                  ? Icon(iconData, size: 30, color: AppColors.primaryAccent)
                  : Text(icon ?? '✨', style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            if (buttonLabel != null && onButtonPressed != null) ...[
              const SizedBox(height: AppSpacing.lg),
              PSButton(
                label: buttonLabel!,
                onPressed: onButtonPressed,
                expand: false,
                size: PSButtonSize.medium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dims the screen while a request is in flight.
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0x99FFFFFF),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.bgPrimary,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadow.overlay,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      if (message != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(message!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            )),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Consistent toast for success and failure across every screen.
void showAppSnack(BuildContext context, String message, {bool success = true}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_rounded,
              size: 18,
              color: success ? const Color(0xFF6EE7A8) : const Color(0xFFFF8FA8),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Skeleton block shown while data loads.
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.xs,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.bgSubtle,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Placeholder card shown in lists while the real data arrives.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return PSCard(
      child: Row(
        children: [
          const ShimmerBox(width: 46, height: 46, radius: AppRadius.md),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 140, height: 14),
                SizedBox(height: AppSpacing.xs),
                ShimmerBox(width: 90, height: 11),
              ],
            ),
          ),
          const ShimmerBox(width: 54, height: 18),
        ],
      ),
    );
  }
}
