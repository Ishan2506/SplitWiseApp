# 🚀 PaisaSplit Flutter UI - Quick Start Guide

## Setup (5 minutes)

### 1. Install Dependencies
```bash
cd D:\PaisaSplit\SplitWiseApp
flutter pub get
```

### 2. Run the App
```bash
flutter run
```

You should see the beautiful new splash screen with PaisaSplit branding!

---

## 🎨 Key Files to Know

```
lib/
├── theme/app_theme.dart          ← BRAND COLORS & TYPOGRAPHY
├── utils/app_constants.dart      ← SPACING & SIZING
├── widgets/common_widgets.dart   ← REUSABLE COMPONENTS
└── screen/splash_screen.dart     ← UPDATED EXAMPLE
```

---

## 💻 How to Build a New Screen

### Template (Copy-Paste Ready)
```dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';

class MyNewScreen extends StatefulWidget {
  const MyNewScreen({Key? key}) : super(key: key);

  @override
  State<MyNewScreen> createState() => _MyNewScreenState();
}

class _MyNewScreenState extends State<MyNewScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Title'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add your content here
          ],
        ),
      ),
    );
  }
}
```

---

## 🎨 Quick Reference

### Colors
```dart
AppColors.primaryAccent    // Pink #EE2B6C
AppColors.textPrimary      // Black #1A1512
AppColors.textSecondary    // Brown #6B5F56
AppColors.bgPrimary        // White #FFFFFF
AppColors.bgSecondary      // Cream #F7EEE4
```

### Spacing
```dart
AppSpacing.xs   // 8px
AppSpacing.sm   // 12px
AppSpacing.md   // 16px
AppSpacing.lg   // 24px
AppSpacing.xl   // 32px
AppSpacing.xxl  // 48px
AppSpacing.xxxl // 64px
```

### Border Radius
```dart
AppRadius.md  // 12px
AppRadius.lg  // 16px
AppRadius.xl  // 18px
AppRadius.pill // 30px
```

---

## 🧩 Using Pre-built Components

### Button
```dart
PSButton(
  label: 'Click Me',
  onPressed: () { },
  isPrimary: true,
  isLoading: false,
)
```

### Text Input
```dart
PSTextField(
  label: 'Email',
  placeholder: 'Enter your email',
  keyboardType: TextInputType.emailAddress,
  validator: (value) {
    if (value?.isEmpty ?? true) return 'Required';
    return null;
  },
)
```

### Group Card
```dart
GroupCard(
  groupName: 'Apartment',
  description: '5 members',
  emoji: '🏠',
  amount: '₹1,240',
  amountLabel: 'You owe',
  amountColor: AppColors.primaryAccent,
  onTap: () { },
)
```

### Status Badge
```dart
StatusBadge(
  label: 'Settled',
  backgroundColor: const Color(0xFFE8F5E9),
  textColor: const Color(0xFF2E7D32),
)
```

### Avatar
```dart
AvatarWidget(
  initials: 'JD',
  size: 48,
  backgroundColor: AppColors.bgSecondary,
  textColor: AppColors.textPrimary,
)
```

---

## 📱 Screen Size Reference

### Standard Padding
All screens should use consistent padding:
```dart
padding: const EdgeInsets.all(AppSpacing.lg), // 24px
```

### Safe Area
Always wrap main content in `SingleChildScrollView`:
```dart
body: SingleChildScrollView(
  padding: const EdgeInsets.all(AppSpacing.lg),
  child: Column(...),
)
```

### Card Spacing
Cards inside should have gap:
```dart
ListView(
  children: [...],
  // or
  Column(
    children: [
      Card(...),
      SizedBox(height: AppSpacing.md),
      Card(...),
    ],
  ),
)
```

---

## 🎯 Common Patterns

### Input Form
```dart
Column(
  children: [
    PSTextField(label: 'Email'),
    SizedBox(height: AppSpacing.lg),
    PSTextField(label: 'Password', obscureText: true),
    SizedBox(height: AppSpacing.xl),
    PSButton(label: 'Sign In', onPressed: () { }),
  ],
)
```

### List of Cards
```dart
ListView.separated(
  itemCount: items.length,
  separatorBuilder: (_, __) => SizedBox(height: AppSpacing.md),
  itemBuilder: (context, index) => GroupCard(...),
)
```

### Empty State
```dart
EmptyStateWidget(
  icon: '📦',
  title: 'No Groups Yet',
  subtitle: 'Create a group to get started',
  buttonLabel: 'Create Group',
  onButtonPressed: () { },
)
```

### Loading State
```dart
LoadingOverlay(
  isLoading: isLoading,
  message: 'Loading...',
  child: YourContent(),
)
```

---

## 🎨 Text Styling

### Headings
```dart
Text(
  'Large Title',
  style: Theme.of(context).textTheme.displayMedium,
)

Text(
  'Section Title',
  style: Theme.of(context).textTheme.headlineLarge,
)

Text(
  'Card Title',
  style: Theme.of(context).textTheme.titleMedium,
)
```

### Body Text
```dart
Text(
  'Regular text',
  style: Theme.of(context).textTheme.bodyMedium,
)

Text(
  'Small text',
  style: Theme.of(context).textTheme.bodySmall,
)
```

### Labels
```dart
Text(
  'LABEL',
  style: Theme.of(context).textTheme.labelSmall,
)
```

---

## ✅ Before Publishing a Screen

- [ ] All text uses theme typography
- [ ] All colors use `AppColors` constants
- [ ] All spacing uses `AppSpacing` constants
- [ ] All radius uses `AppRadius` constants
- [ ] Buttons use `PSButton` widget
- [ ] Inputs use `PSTextField` widget
- [ ] Cards use `Card()` widget
- [ ] Tested in light mode
- [ ] Tested in dark mode
- [ ] Tested on different screen sizes

---

## 🐛 Troubleshooting

### Colors not updating?
- Make sure you imported `AppColors`
- Clear cache: `flutter clean`
- Rebuild: `flutter pub get && flutter run`

### Text looks wrong?
- Check you're using `Theme.of(context).textTheme` property
- Not using hardcoded `TextStyle`
- Font sizes should come from `AppTextStyles` class

### Layout issues?
- Use `AppSpacing` for all gaps
- Use `SingleChildScrollView` for scrollable content
- Use `Expanded` for flex layouts
- Test on different screen sizes

---

## 📚 Detailed Documentation

For more information, see:
- **`DESIGN_IMPLEMENTATION.md`** - Complete design specs
- **`IMPLEMENTATION_SUMMARY.md`** - Progress & architecture
- **`lib/theme/app_theme.dart`** - Theme code

---

## 🎯 Next Screen to Build

### Login Screen (`lib/screen/authentication/login_screen.dart`)

**Requirements:**
1. Email input with `PSTextField`
2. Password input with `PSTextField` (obscure by default)
3. "Forgot password?" link
4. "Sign in" button with `PSButton` (primary)
5. "Sign up" link at bottom
6. Form validation

**Reference:**
- Look at `DESIGN_IMPLEMENTATION.md` section "Screen Specifications"
- Check HTML design in `PaisaSplit-UI-Design.html`
- Follow the `splash_screen.dart` pattern

---

## 💡 Pro Tips

1. **Copy from splash screen** - Use it as a template for styling
2. **Use `const` keyword** - For performance optimization
3. **Extract components** - Reusable widgets in `common_widgets.dart`
4. **Test dark mode** - Always check both light and dark modes
5. **Use SafeArea** - For notches and system UI insets
6. **Keep logic separate** - UI widgets should be focused on presentation

---

## 🚀 Build & Deploy Commands

```bash
# Clean build
flutter clean
flutter pub get

# Run with debug
flutter run

# Run in release mode
flutter run --release

# Build APK
flutter build apk --release

# Build iOS
flutter build ios --release

# Build web
flutter build web --release
```

---

**Ready to build?** Start with the Login Screen! 🎨

