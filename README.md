# Booze Blocker

An iOS app that helps you avoid drunk texting, calling, and app usage by blocking access to selected contacts and apps while you're drinking.

## Features

### MVP (v1.0) - Fully Implemented
- **Manual Activation** - Tap to activate protection when you start drinking
- **Duration Selection** - Choose how long protection lasts (until morning, X hours, or manual stop)
- **App Blocking** - Block access to social media, dating apps, messaging apps (24 common apps pre-configured)
- **Contact Blocking** - Prevent texting/calling specific contacts with categories (ex, boss, family, etc.)
- **Emergency Contacts** - Designate contacts that are always accessible
- **Sobriety Tests** - Math problems or typing tests required to deactivate protection early
- **Session History** - Review past sessions and blocked attempts
- **Insights Dashboard** - View statistics, streaks, and most-blocked items
- **Scheduled Protection** - Pre-set times for automatic activation
- **Onboarding Flow** - Guided setup with permissions requests
- **Widget Support** - Home screen widget showing protection status
- **Deep Link Support** - URL scheme for quick activation
- **Haptic Feedback** - Tactile feedback throughout the app
- **Dark Mode** - Full dark mode support with customizable accent colors

### Planned Features (v2.0+)
- **Oura Ring Integration** - Auto-detect drinking via biometrics (HRV, heart rate)
- **Credit Card Alerts** - Auto-activate when you charge at a bar (via Plaid)
- **Location Triggers** - Activate when entering bars/clubs
- **Accountability Partner** - Share status with trusted friends

## Project Structure (41 Swift Files)

```
BoozeBlocker/
├── App/
│   ├── BoozeBlockerApp.swift          # App entry point with onboarding flow
│   └── ContentView.swift              # Main tab navigation with deep links
│
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift             # Basic home view
│   │   ├── HomeView+Enhanced.swift    # Enhanced home with all components
│   │   └── Components/
│   │       ├── DurationPickerSheet.swift
│   │       ├── StatusCard.swift       # Animated shield status
│   │       ├── QuickActionsView.swift # Quick activation buttons
│   │       └── RecentActivityCard.swift
│   │
│   ├── Protection/
│   │   ├── ShieldView.swift           # Shown when blocked app opened
│   │   └── SobrietyTest/
│   │       ├── SobrietyTestView.swift
│   │       ├── MathTestView.swift     # Custom number pad
│   │       └── TypingTestView.swift   # Type phrase backwards
│   │
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── BlockedAppsView.swift
│   │   ├── BlockedContactsView.swift
│   │   ├── EmergencyContactsView.swift
│   │   ├── ScheduleSettingsView.swift # Scheduled protection
│   │   ├── AppearanceSettingsView.swift
│   │   ├── PrivacySettingsView.swift
│   │   └── HelpSupportView.swift
│   │
│   ├── History/
│   │   ├── HistoryView.swift
│   │   └── InsightsView.swift         # Statistics dashboard
│   │
│   ├── Onboarding/
│   │   ├── OnboardingView.swift       # 5-page intro
│   │   └── PermissionsView.swift      # Request permissions
│   │
│   └── Widget/
│       └── BoozeBlockerWidget.swift   # Home screen widget
│
├── Core/
│   ├── Models/
│   │   ├── UserSettings.swift
│   │   ├── ProtectionSession.swift
│   │   ├── BlockedAttempt.swift
│   │   ├── BlockedApp.swift           # 24 common apps pre-defined
│   │   ├── BlockedContact.swift
│   │   └── DurationOption.swift
│   │
│   ├── Services/
│   │   ├── PersistenceService.swift   # UserDefaults storage
│   │   ├── ProtectionManager.swift    # Central state manager
│   │   ├── SobrietyTestService.swift  # Test generation
│   │   ├── ContactsService.swift      # iOS Contacts access
│   │   ├── ScreenTimeService.swift    # Screen Time API wrapper
│   │   ├── NotificationService.swift  # Local notifications
│   │   ├── AppearanceManager.swift    # Theme/colors
│   │   ├── HapticService.swift        # Haptic feedback
│   │   └── DeepLinkService.swift      # URL scheme handling
│   │
│   └── Extensions/
│       ├── Color+Extensions.swift
│       ├── Date+Extensions.swift
│       ├── View+Extensions.swift      # Shake, glow, card styles
│       └── String+Extensions.swift
│
└── Resources/
    ├── Info.plist                     # Privacy descriptions
    └── Assets.xcassets/               # App icon, colors
```

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+

## Setup in Xcode

1. **Create New Project**
   - Open Xcode → File → New → Project
   - Choose "App" under iOS
   - Product Name: "BoozeBlocker"
   - Interface: SwiftUI
   - Language: Swift

2. **Copy Swift Files**
   - Copy all files from `BoozeBlocker/` folder into your Xcode project
   - Maintain the folder structure

3. **Add Capabilities**
   - Select project → Signing & Capabilities
   - Add: Family Controls (for Screen Time)
   - Add: App Groups (for widget)

4. **Configure Entitlements**
   - Request Family Controls entitlement from Apple Developer Portal

5. **Build and Run**

## Permissions Required

| Permission | Purpose | Privacy Description |
|------------|---------|---------------------|
| Contacts | Select contacts to block/allow | Included in Info.plist |
| Screen Time | Block apps | Requires Family Controls entitlement |
| Notifications | Blocked attempt alerts | Requested at runtime |
| Face ID | Secure history access | Included in Info.plist |

## URL Scheme (Deep Links)

```
boozeblocker://activate              # Open activation flow
boozeblocker://activate?duration=14400  # Activate for 4 hours
boozeblocker://settings              # Open settings
boozeblocker://history               # Open history
```

## Technical Architecture

- **SwiftUI** - Modern declarative UI with animations
- **MVVM** - Clean separation of concerns
- **UserDefaults** - Local persistence (no server required)
- **Combine** - Reactive state management
- **WidgetKit** - Home screen widget
- **CallKit** - Call blocking (incoming only)

## iOS Limitations & Workarounds

| Feature | iOS Limitation | Our Approach |
|---------|----------------|--------------|
| App Blocking | Requires Screen Time API | ManagedSettings framework |
| Outgoing Calls | Cannot block programmatically | Friction overlay + test |
| SMS/iMessage | Cannot intercept | Block Messages app entirely |
| Contact Blocking | No direct API | Focus Mode + overlay |

## File Count Summary

- **41 Swift files** total
- **6 Models** - Data structures
- **9 Services** - Business logic
- **4 Extensions** - Utilities
- **22 Views** - UI components

## License

MIT License - See LICENSE file for details
