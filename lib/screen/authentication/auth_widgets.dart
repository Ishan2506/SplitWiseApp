import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';

/// Shared chrome for the sign-in and sign-up screens: a centred, width-capped
/// column with the wordmark, a heading and a subheading above the form.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? footer;
  final bool showBack;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: showBack
          ? AppBar(backgroundColor: AppColors.bgPrimary)
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: AppBreakpoints.pagePadding(context),
              vertical: AppSpacing.lg,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!showBack) ...[
                    const AuthBrandMark(),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                  Text(title,
                      style: Theme.of(context).textTheme.displayMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.xl),
                  ...children,
                  if (footer != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The pink tile plus wordmark used at the top of the auth screens.
class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primaryAccent,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: const Text(
            '₹',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        const Text(
          'PaisaSplit',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// A hairline rule with a centred "or".
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text('or', style: Theme.of(context).textTheme.labelSmall),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// "Continue with Google", with the multi-colour mark drawn in-widget so the
/// button needs no image asset.
class GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  const GoogleButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Continue with Google',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _GoogleGlyph(),
                  const SizedBox(width: AppSpacing.xs),
                  // Flexible so the label ellipsises on a narrow phone
                  // instead of pushing the row past the button.
                  Flexible(
                    child: Text(label,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..style = PaintingStyle.fill;
    const quarter = 1.5707963;

    const colors = [
      Color(0xFFEA4335),
      Color(0xFFFBBC05),
      Color(0xFF34A853),
      Color(0xFF4285F4),
    ];
    for (var i = 0; i < 4; i++) {
      paint.color = colors[i];
      canvas.drawArc(rect, -quarter + i * quarter, quarter, true, paint);
    }

    // Punch out the centre so it reads as a ring rather than a pie.
    paint.color = AppColors.bgPrimary;
    canvas.drawCircle(rect.center, size.width * 0.28, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Prompt shown at the bottom of an auth screen ("New here? Create an account").
class AuthFooterPrompt extends StatelessWidget {
  final String question;
  final String action;
  final VoidCallback onTap;

  const AuthFooterPrompt({
    super.key,
    required this.question,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Wrap rather than Row: on a narrow phone the prompt and its action need
    // to be able to fall onto two lines instead of overflowing.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(question, style: Theme.of(context).textTheme.bodySmall),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(action),
        ),
      ],
    );
  }
}

/// Inline error banner used above auth forms.
class AuthErrorBanner extends StatelessWidget {
  final String message;

  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 17, color: AppColors.error),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
