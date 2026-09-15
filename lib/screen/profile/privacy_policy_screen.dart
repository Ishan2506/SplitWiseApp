import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';
import 'help_support_screen.dart' show kSupportEmail;

/// The date the wording below last changed. Update it whenever the policy does.
const String kPolicyLastUpdated = '16 September 2026';

class _Section {
  final String title;
  final List<String> paragraphs;

  const _Section(this.title, this.paragraphs);
}

/// Written to describe what the app actually does today. If the data the app
/// collects changes, this text and [kPolicyLastUpdated] change with it.
const List<_Section> _sections = [
  _Section('What we collect', [
    'Your account details: name, and an email address or mobile number. One of '
        'the two is required so people can invite you and so you can sign in.',
    'A profile photo, only if you upload one. If you sign in with Google we '
        'also store the profile picture and Google account id that Google '
        'gives us, so we can recognise you next time.',
    'The groups you belong to, the expenses and settlements you record in '
        'them, and the notes and receipt details you add yourself.',
  ]),
  _Section('What we do with it', [
    'We use it to run the app: to work out who owes whom, to show your groups '
        'and history, and to let the people you share a group with see the '
        'expenses you record there.',
    'We do not sell your information, and we do not use it for advertising.',
  ]),
  _Section('Who can see your information', [
    'People you share a group with can see your name, profile photo, and the '
        'expenses and settlements in that group, including amounts and who '
        'paid.',
    'Your email address and mobile number are visible to people you share a '
        'group with, so they can recognise and add you. They are not shown to '
        'anyone else using the app.',
    'People you share no group with cannot look you up or see anything about '
        'you.',
  ]),
  _Section('Receipt scanning', [
    'When you scan a receipt, the text is read on your device to fill in the '
        'expense for you. The photo is not uploaded to us — only the expense '
        'details you confirm and save are.',
  ]),
  _Section('Where it is stored', [
    'Your data is held in our database, and uploaded profile photos are stored '
        'on our server. Passwords are never stored directly; they are stored '
        'as a hash, which cannot be read back.',
    'You stay signed in using a token held on your device. Signing out removes '
        'it, along with the groups and balances cached there.',
  ]),
  _Section('Your choices', [
    'You can edit your name, contact details and profile photo at any time '
        'from Edit profile, and remove your photo to go back to the generated '
        'initials.',
    'You can leave a group once your balance in it is settled. Expenses you '
        'already recorded stay with the group, because they are part of other '
        "people's balances too.",
    'To have your account and personal details deleted, email us and we will '
        'take care of it.',
  ]),
  _Section('Children', [
    'The app is not intended for children under 13, and we do not knowingly '
        'collect their information.',
  ]),
  _Section('Changes to this policy', [
    'If this policy changes we will update the date at the top of this screen. '
        'Significant changes will be called out in the app.',
  ]),
];

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: AppColors.textSecondary, height: 1.5);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Last updated $kPolicyLastUpdated',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'PaisaSplit keeps track of shared expenses. That only works '
                  'if we hold some information about you, so here is exactly '
                  'what we keep and who can see it.',
                  style: body,
                ),
                const SizedBox(height: AppSpacing.lg),

                for (final section in _sections) ...[
                  Text(
                    section.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final paragraph in section.paragraphs) ...[
                    Text(paragraph, style: body),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  const SizedBox(height: AppSpacing.md),
                ],

                PSCard(
                  color: AppColors.bgSubtle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Questions about your data',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text('Email $kSupportEmail', style: body),
                    ],
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
