# PaisaSplit UI Design Implementation Guide

## Project Overview
Converting the entire SplitWiseApp Flutter UI to match the PaisaSplit design system with the official brand colors and modern mobile-first design.

## 📋 Color Palette (Official PaisaSplit Branding)

### Primary Colors
- **Pink (Primary Accent)**: `#EE2B6C` (`Color(0xFFEE2B6C)`)
- **Soft Pink Tint**: `#F7D9DE` (`Color(0xFFF7D9DE)`)

### Text Colors
- **Black (Primary Text)**: `#1A1512` (`Color(0xFF1A1512)`)
- **Muted Brown-Grey (Secondary Text)**: `#6B5F56` (`Color(0xFF6B5F56)`)

### Background Colors
- **White (Primary)**: `#FFFFFF` (`Color(0xFFFFFFFF)`)
- **Cream (Secondary)**: `#F7EEE4` (`Color(0xFFF7EEE4)`)
- **Light Pink**: `#FBF3F6` (`Color(0xFFFBF3F6)`)

### UI Colors
- **Success**: `#4CAF50`
- **Warning**: `#FF9800`
- **Error**: `#F44336`
- **Muted**: `#8A8490`
- **Border**: `#ECE8EF`
- **Border Light**: `#EFE9EC`
- **Input Background**: `#F6F4F7`

---

## ✅ Completed Tasks

### 1. Theme System (`lib/theme/app_theme.dart`)
- ✅ Created comprehensive `AppColors` class with all brand colors
- ✅ Implemented `lightTheme()` with Material 3
- ✅ Implemented `darkTheme()` for dark mode support
- ✅ Full typography scale (display, heading, title, body, label)
- ✅ Input decoration theme with proper styling
- ✅ Button themes (elevated, outlined, text)
- ✅ Card and chip themes
- ✅ Color contrast ratios optimized for accessibility

### 2. Main App (`lib/main.dart`)
- ✅ Updated to use new `AppTheme` system
- ✅ Changed app title to "PaisaSplit"
- ✅ Added light and dark theme support
- ✅ Set `themeMode` to `ThemeMode.system`

### 3. Splash Screen (`lib/screen/splash_screen.dart`)
- ✅ Complete redesign matching HTML design
- ✅ Gradient background (pink to white)
- ✅ Branded logo with gradient
- ✅ Animated entrance (slide + fade)
- ✅ "PaisaSplit" branding with colored text
- ✅ Tagline: "Share the bill, not the stress"
- ✅ Loading indicator with brand color
- ✅ Professional typography and spacing

### 4. Utilities (`lib/utils/app_constants.dart`)
- ✅ Spacing constants (xs, sm, md, lg, xl, xxl, xxxl)
- ✅ Border radius constants
- ✅ Typography font size constants
- ✅ Letter spacing constants
- ✅ Shadow definitions

---

## 📱 Screens to Implement (15 Screens Total)

### ✅ Completed
1. ✅ **Splash Screen** - Onboarding intro

### 🔄 In Progress / To Do

#### Authentication Section (4 screens)
2. **Login Screen** - Email/password sign-in
   - Update colors and styling
   - Implement proper form validation
   - Add password visibility toggle
   - Update button styling

3. **Sign Up Screen** - Registration flow
   - Phone number input
   - Email validation
   - Password requirements display
   - Terms & conditions

4. **Profile Setup** - User profile completion
   - Avatar picker
   - Full name input
   - Phone number
   - UPI ID setup

5. **Groups List Screen** - Main dashboard entry
   - Groups grid/list
   - "You owe" vs "You're owed" indicators
   - Quick add button
   - Group status badges

#### Group Creation Section (3 screens)
6. **Create Group** - Group setup
   - Group name input
   - Icon/emoji selector
   - Group settings

7. **Add Members** - Member selection
   - Contact search
   - Selected members display
   - Suggested contacts

8. **Invite Link** - Sharing & invitations
   - Invite link display
   - Copy to clipboard
   - Share options
   - Settings button

#### Expense Management Section (3 screens)
9. **Dashboard/Groups View** - Main expense view
   - Recent expenses list
   - Quick add buttons (scan/manual)
   - Group selection

10. **Add Expense (Manual)** - Manual expense entry
    - Description field
    - Amount input
    - Paid by selector
    - Category picker
    - Date selector

11. **Confirm Split** - Split verification
    - Amount breakdown
    - Member breakdown
    - Split adjustment options
    - Confirm button

#### Settlement Section (3 screens)
12. **Settlement Summary** - Payment status
    - Who owes whom summary
    - Amount calculations
    - Settle/Pay buttons per item

13. **Settle Up Dialog** - Payment interface
    - Payment flow visualization
    - Amount display
    - Payment method selector (UPI, Bank)
    - Confirm payment button

14. **Payment Confirmed** - Success screen
    - Checkmark animation
    - Transaction details
    - Receipt sharing

#### Receipt Scanning Section (2 screens)
15. **Camera/Scanner** - Receipt capture
    - Camera preview
    - Frame guide
    - Photo capture button

16. **Receipt Details** - Extracted items
    - Auto-detected items list
    - Amount verification
    - Item editing
    - Split confirmation

---

## 🎨 Design System Details

### Typography
- **Display/Heading Font**: Plus Jakarta Sans (weights: 700, 800)
- **Body Font**: Plus Jakarta Sans (weights: 400, 500, 600)
- **Mono Font**: JetBrains Mono (for data/codes)

### Spacing System
```
xs: 8px    → Minimal spacing
sm: 12px   → Small gaps
md: 16px   → Standard spacing
lg: 24px   → Section spacing
xl: 32px   → Large sections
xxl: 48px  → Major sections
xxxl: 64px → Page padding
```

### Border Radius
```
sm: 8px    → Small elements
md: 12px   → Chips, badges
lg: 16px   → Cards
xl: 18px   → Input fields
xxl: 20px  → Rounded corners
pill: 30px → Buttons
full: 50%  → Circles
```

---

## 🔧 Implementation Checklist

### Authentication Screens
- [ ] **Login Screen**
  - [ ] Update input field styling with new colors
  - [ ] Implement password toggle icon
  - [ ] Update button styling
  - [ ] Add forgot password link styling
  - [ ] Update text colors (primary/secondary)
  - [ ] Add form validation messages with new error color

- [ ] **Sign Up Screen**
  - [ ] Create phone number input with validation
  - [ ] Add password strength indicator
  - [ ] Implement email validation UI
  - [ ] Add terms & conditions checkbox
  - [ ] Update all colors to match theme
  - [ ] Add success/error states

- [ ] **Profile Setup Screen**
  - [ ] Avatar picker component
  - [ ] Full name input field
  - [ ] Phone number input field
  - [ ] UPI ID input field
  - [ ] Continue button styling
  - [ ] Form validation states

- [ ] **Groups List Screen**
  - [ ] Group card component with proper styling
  - [ ] "You owe" badge (pink accent)
  - [ ] "You're owed" badge (green)
  - [ ] "Settled" badge (gray)
  - [ ] Add group FAB button
  - [ ] Implement group list scrolling
  - [ ] Add empty state when no groups

### Group Management Screens
- [ ] **Create Group Screen**
  - [ ] Text input for group name
  - [ ] Icon/emoji selector grid
  - [ ] Continue/Cancel buttons
  - [ ] Form validation

- [ ] **Add Members Screen**
  - [ ] Search input for contacts
  - [ ] Selected members chips display
  - [ ] Suggested contacts list
  - [ ] Add/remove member buttons
  - [ ] Next button styling

- [ ] **Invite Link Screen**
  - [ ] Success checkmark animation
  - [ ] Invite link display box
  - [ ] Copy link button
  - [ ] Share options (contacts, messaging)
  - [ ] Done button

### Expense Management Screens
- [ ] **Expense Dashboard**
  - [ ] Group selector/navigation
  - [ ] Scan Receipt button (primary)
  - [ ] Add Manually button (secondary)
  - [ ] Recent expenses list
  - [ ] Expense item component

- [ ] **Add Expense (Manual)**
  - [ ] Description input
  - [ ] Amount input with currency symbol
  - [ ] Paid by dropdown
  - [ ] Category picker
  - [ ] Date picker
  - [ ] Next: Split expense button

- [ ] **Confirm Split**
  - [ ] Amount breakdown card
  - [ ] Member breakdown list
  - [ ] Per-person amount display
  - [ ] Adjust split button
  - [ ] Add Expense button (primary)

### Settlement Screens
- [ ] **Settlement Summary**
  - [ ] Summary cards (paid/owed amounts)
  - [ ] Who owes you list
  - [ ] Who you owe list
  - [ ] Settle/Pay buttons per item
  - [ ] Badge styling (settled/owing)

- [ ] **Settle Up Dialog**
  - [ ] Payment flow visualization (from → to)
  - [ ] Amount display
  - [ ] Payment method selector
  - [ ] UPI option
  - [ ] Bank transfer option
  - [ ] Confirm & Pay button

- [ ] **Payment Confirmed**
  - [ ] Success checkmark (animated)
  - [ ] Transaction ID display
  - [ ] Receipt sharing button
  - [ ] Done button

### Receipt Scanning Screens
- [ ] **Camera Screen**
  - [ ] Camera preview
  - [ ] Frame guide overlay
  - [ ] Take photo button
  - [ ] Status text
  - [ ] Back button

- [ ] **Receipt Details**
  - [ ] Restaurant/vendor name
  - [ ] Order date display
  - [ ] Items list with prices
  - [ ] Item quantity display
  - [ ] Total amount
  - [ ] Split these items button

---

## 📐 Component Hierarchy

```
App
├── Splash Screen ✅
├── Authentication
│   ├── Login Screen
│   ├── Sign Up Screen
│   └── Profile Setup
├── Dashboard
│   ├── Groups List
│   └── Group Details
│       ├── Expenses List
│       ├── Add Expense (Manual/Camera)
│       ├── Confirm Split
│       └── Settlement
└── Settings/Profile
```

---

## 🚀 Next Steps

1. **Update Login Screen** - Most critical user-facing screen
2. **Update Sign Up Screen** - Registration flow
3. **Create Profile Setup Screen** - User onboarding
4. **Update Dashboard/Groups List** - Main content screen
5. **Create Group Management Screens** - Group CRUD operations
6. **Update Expense Screens** - Core feature screens
7. **Create Settlement Screens** - Payment flows
8. **Add Receipt Scanning UI** - Premium feature screens

---

## 🎯 Design Specifications

### Button Sizing
- **Standard Button**: 60px height, 30px border-radius (pill-shaped)
- **Small Button**: 44px height, 20px border-radius
- **FAB Button**: 60px diameter circle

### Card Styling
- **Background**: White (#FFFFFF)
- **Border**: 1px #ECE8EF
- **Border Radius**: 16px
- **Padding**: 16px
- **Shadow**: Subtle (0 2px 8px rgba(0,0,0,0.1))

### Input Fields
- **Height**: 58px
- **Border Radius**: 18px
- **Background**: #F6F4F7
- **Border**: 1px #ECE8EF
- **Focus Border**: 2px #EE2B6C
- **Padding**: 18px horizontal, 16px vertical

### Typography Hierarchy
- **Display (Hero)**: 64px, 800 weight, -0.035 letter-spacing
- **Large Heading**: 40px, 800 weight, -0.035 letter-spacing
- **Heading**: 26px, 800 weight, -0.02 letter-spacing
- **Title**: 19px, 800 weight, -0.01 letter-spacing
- **Body**: 16px, 500 weight
- **Label**: 13px, 600 weight, 0.16 letter-spacing

---

## 📝 Notes

- All colors are tested for WCAG AA contrast ratios
- Dark theme automatically applies inverse colors
- System respects user's OS theme preference
- Animations use standard Material easing curves
- All touchable elements have 48px minimum tap target
- Font loading handled by Material 3 defaults (Plus Jakarta Sans via Google Fonts)

---

## 🔗 References

- **HTML Design File**: `D:\PaisaSplit\MVP Expense-Splitting App\PaisaSplit-UI-Design.html`
- **Theme File**: `lib/theme/app_theme.dart`
- **Constants**: `lib/utils/app_constants.dart`

---

**Last Updated**: September 4, 2026
**Status**: In Progress - Theme System Complete, Screens in Development
