import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';

/// Where to reach us. Kept here rather than inline so there is one place to
/// change if the address moves.
const String kSupportEmail = 'support@paisasplit.app';

class _Faq {
  final String question;
  final String answer;

  const _Faq(this.question, this.answer);
}

/// Answers to the questions the app actually raises — written against how it
/// behaves today, so nothing here promises something that does not exist.
const List<_Faq> _faqs = [
  _Faq(
    'How do I add someone to a group?',
    'Open the group, go to Members and tap Add. You can pick anyone you '
        'already share a group with. To reach someone new, use Invite with a '
        'link or QR code — they join the group as soon as they open it.',
  ),
  _Faq(
    'Why can I only see some people when adding members?',
    'The member list shows people you already share a group with, not everyone '
        'who uses the app. That keeps your contacts private. Anyone else joins '
        'through an invite link or QR code.',
  ),
  _Faq(
    'I invited someone but they do not appear.',
    'An invite stays pending until they open the link and join. If they signed '
        'up before opening it, ask them to tap the link again or scan the '
        'group QR code — signing up on its own does not join a group.',
  ),
  _Faq(
    'How are expenses split?',
    'Equally by default, across everyone you select. You can also split by '
        'exact amounts, percentages or shares when you add the expense.',
  ),
  _Faq(
    'What does the balance limit do?',
    'A group can set a cap on how much any one member is allowed to owe. If a '
        'new expense would push someone past it, the app blocks that expense '
        'and tells you who it affects.',
  ),
  _Faq(
    'How does settling up work?',
    'Settle up records a payment between two people. It does not move any '
        'money — pay each other however you normally do, then record it here '
        'so the balances match.',
  ),
  _Faq(
    'Can I remove someone from a group?',
    'Yes, once their balance is zero. The app refuses to remove anyone who '
        'still owes or is owed money, so nothing is lost. Settle up first, '
        'then remove them. Only the group creator can remove other people, but '
        'anyone can leave a group themselves.',
  ),
  _Faq(
    'Can I change a group to a different currency?',
    'A group keeps the currency it was created with, and amounts are never '
        'converted. Your own default currency, under Preferences, applies to '
        'new groups you create.',
  ),
  _Faq(
    'What happens if I delete a group?',
    'Its expenses and settlements are deleted with it, for everyone in the '
        'group. This cannot be undone, so settle up and check with the others '
        'first. Only the creator can delete a group.',
  ),
];

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _copyEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: kSupportEmail));
    if (!context.mounted) return;
    showAppSnack(context, 'Support email copied');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xs),
                const OverlineLabel('Common questions'),
                const SizedBox(height: AppSpacing.xs),
                PSCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final faq in _faqs)
                        _FaqTile(
                          faq: faq,
                          isLast: faq.question == _faqs.last.question,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                const OverlineLabel('Still stuck'),
                const SizedBox(height: AppSpacing.xs),
                PSCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Email us',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Tell us what you expected and what happened instead. '
                        'If it involves a group, mention its name — it helps '
                        'us find the problem faster.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      InkWell(
                        onTap: () => _copyEmail(context),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.bgSubtle,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.mail_outline_rounded,
                                  size: 18, color: AppColors.textSecondary),
                              const SizedBox(width: AppSpacing.xs),
                              const Expanded(
                                child: Text(
                                  kSupportEmail,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const Icon(Icons.copy_rounded,
                                  size: 16, color: AppColors.textTertiary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Text(
                    'PaisaSplit · v1.0.0',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One question, expanding in place to reveal its answer.
class _FaqTile extends StatefulWidget {
  final _Faq faq;
  final bool isLast;

  const _FaqTile({required this.faq, required this.isLast});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.faq.question,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: AppDuration.fast,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  duration: AppDuration.fast,
                  crossFadeState: _open
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.xs,
                      right: AppSpacing.lg,
                    ),
                    child: Text(
                      widget.faq.answer,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!widget.isLast)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Divider(height: 1, color: AppColors.borderLight),
          ),
      ],
    );
  }
}
