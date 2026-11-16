# BoozeBlocker — Implementation Plan: from SwiftUI skeleton to a buildable iOS app

> Status: **analysis only, nothing implemented**. Written against commit `e646114` (the only commit on `main`).
> Goal: a follow-up session can run this plan from top to bottom without doing more discovery.
> Where something below is inferred and not verified on a Mac/device, it is marked **(verify)**.

---

## 0. TL;DR

- The repo has **53 Swift files / 9,116 lines** (the README says 41). It has **no buildable target**. `project.pbxproj` contains only project-level build settings, and `Package.swift` declares a *library* target, which cannot produce an app, widget, or app extension.
- About 80% of the UI is written and plausible. The **core is simulated**. Screen Time "authorization" is a UserDefaults flag, "blocking" is a `Set<String>` of bundle IDs, and nothing calls `startBlocking()`/`stopBlocking()`. `ProtectionManager` has `// TODO: Activate Screen Time restrictions`.
- With a deployment target of iOS 16.0, the code will **not compile as-is**. I found at least 11 definite or likely compile errors (iOS 17-only APIs, non-`Equatable` values passed to `onChange`, an unqualified static call, a name clash with `ManagedSettingsUI.ShieldConfiguration`). See §2.3.
- **Decisions in this plan:**
  1. Use **XcodeGen** (`project.yml`) to generate the project. Don't hand-write `project.pbxproj`, and don't use Tuist.
  2. Set the **deployment target to iOS 17.0**.
  3. Add five targets: app, Widget extension, Shield Configuration extension, Shield Action extension, Device Activity Monitor extension. Optionally add unit and UI test targets.
  4. Put persistence that extensions need in an **App Group**.
  5. Replace the `blockedAppBundleIDs` model with a persisted **`FamilyActivitySelection`** (opaque tokens).
  6. Put Oura, Plaid, Location, Siri, and delayed messages behind a **`FeatureFlags`** switch that is off for v1.
- **Hard external blocker:** Screen Time blocking (`FamilyControls`/`ManagedSettings`/`DeviceActivity`) needs the **Family Controls capability**. That means a paid Apple Developer Program membership. Shipping on TestFlight or the App Store also needs a separate **Family Controls (Distribution)** entitlement request, which Apple must approve for each bundle ID. Screen Time APIs do not work meaningfully in the Simulator, so blocking has to be tested on a physical device.
- **Honest limitation:** iOS has **no public API** to block outgoing calls or SMS/iMessage to specific contacts. "Contact blocking" can only be approximated: shield whole apps (Messages, WhatsApp, …) and optionally block *incoming* calls from listed numbers with a CallKit Call Directory extension. See §6.

---

## 1. Decisions the repo owner must make first (blocking)

| # | Decision | Recommended default | Blocks |
|---|----------|--------------------|--------|
| D1 | **Bundle ID prefix** | `com.<yourname>.boozeblocker` (app), then `.widget`, `.shieldconfig`, `.shieldaction`, `.activitymonitor` | Phase 1 |
| D2 | **App Group ID** | `group.com.<yourname>.boozeblocker`. The code currently hard-codes `group.com.boozeblocker.app` in `BoozeBlocker/Widget/BoozeBlockerWidget.swift:35`. | Phase 2 |
| D3 | **Apple Developer account** | A paid Developer Program account ($99/yr). With a free Personal Team you cannot add Family Controls **(verify)**. | Phase 3 on device |
| D4 | **Development Team ID** | Put it in `project.yml`, or in a git-ignored `Config/Signing.xcconfig`. `.gitignore` already ignores `*.xcconfig`. | Signing |
| D5 | **Submit the Family Controls (Distribution) request** | Do this as early as possible. Approval can take days to weeks. The request is made per bundle ID, and the app plus each extension that uses the framework all need it. | TestFlight/App Store only |
| D6 | **Minimum iOS** | **17.0**. The code already uses iOS 17 APIs (`symbolEffect`, two-parameter `onChange`, `setBadgeCount`, widget `#Preview(as:)`). Keeping 16.0 means rewriting about 10 call sites with `if #available`. | Phase 1 |
| D7 | Can the blocked-app selection be **edited while protection is active**? | **No**. Editing is disabled while active, which closes an obvious bypass. Alternative: allow *adding* apps only. | Phase 4 |
| D8 | **Sobriety test lockout** after 3 failed attempts | 10-minute cooldown before the next try (the code currently allows an immediate retry) | Phase 4 |
| D9 | **Emergency override** | Keep `EndReason.emergencyOverride` for later and add no UI in v1. Alternative: a "hold for 10 s + Face ID" escape hatch using `BiometricService`. | Phase 4 |
| D10 | **iPad** | iPhone only (`TARGETED_DEVICE_FAMILY = 1`). The Info.plist currently lists iPad orientations. | Phase 1 |
| D11 | Should `denyAppRemoval` be on while protection is active? | **Yes**. It stops the user deleting BoozeBlocker to escape. | Phase 3 |
| D12 | Should the generated `.xcodeproj` be committed? | **Yes**. Commit it alongside `project.yml` so people without XcodeGen can still open it. CI checks that `xcodegen generate` produces no diff. | Phase 1 |

---

## 2. Full source inventory

Legend for the tables below:
- **Real**: works as written, given permissions.
- **Stub**: placeholder or simulated logic.
- **UI-only**: a view with no real backend.
- **Orphan**: never referenced from any reachable screen.

Compile status is my judgement from reading the code; nothing was compiled.

### 2.1 Non-Swift files

| File | State | Problems |
|------|-------|----------|
| `BoozeBlocker.xcodeproj/project.pbxproj` | Skeleton | Has only a `PBXProject` and Debug/Release settings (`IPHONEOS_DEPLOYMENT_TARGET = 16.0`). There are **no targets, file references, build phases, or Info.plist/entitlements settings**. Replace it with the XcodeGen output. |
| `Package.swift` | Unusable for an app | It is a `.library` over the whole `BoozeBlocker/` folder, which includes the `@main` app, widget code, and `Info.plist`/`Assets` (unhandled resources). SPM cannot build an iOS app or app extensions. **Delete it.** |
| `BoozeBlocker/Resources/Info.plist` | Partially correct | (a) `UIRequiredDeviceCapabilities = armv7` is wrong for iOS 17; remove it or use `arm64`. (b) `UILaunchScreen` points at a `LaunchScreenBackground` color and `LaunchIcon` image that **do not exist** in Assets. (c) There are **no `CFBundleURLTypes`**, so `boozeblocker://` deep links and the widget's `widgetURL` do nothing. (d) `UIBackgroundModes` `fetch`/`processing` are unused, and `processing` needs `BGTaskSchedulerPermittedIdentifiers`, so remove both. (e) `NSUserTrackingUsageDescription` is unused; remove it, because it invites App Review questions. (f) `NSLocation*UsageDescription` is missing (only needed if Location is enabled). (g) `NSUserActivityTypes` is missing (only needed if Siri activities are enabled). |
| `Resources/Assets.xcassets/AppIcon.appiconset` | Empty | No 1024×1024 PNG. Builds pass with a warning; you need an icon before TestFlight. |
| `Resources/Assets.xcassets/AccentColor.colorset` | Real | — |
| `README.md` | Out of date | File count, "Fully Implemented" claims, and the setup steps are wrong. Rewrite it in Phase 6. |
| `.gitignore` | Mostly fine | Ignores `*.xcconfig` and `project.xcworkspace`. That is fine if the generated project is committed without a workspace. |
| *(missing)* | — | Entitlements files, `PrivacyInfo.xcprivacy` (required for UserDefaults "required reason" API use), test targets, and extension folders all need to be added. |

### 2.2 Swift files

#### App
| File | State | Notes |
|------|-------|-------|
| `App/BoozeBlockerApp.swift` | Real | `@main`, `RootView` state machine (Onboarding → Permissions → `ContentView`) driven by `@AppStorage("hasCompletedOnboarding")` and `hasGrantedPermissions`. That duplicates `UserSettings.hasCompletedOnboarding`. There is no `UIApplicationDelegateAdaptor` or `UNUserNotificationCenterDelegate`, so notification actions do nothing. |
| `App/ContentView.swift` | **Compile error** | Line 38: `.onChange(of: deepLinkService.pendingAction)`, but `DeepLinkAction` is not `Equatable` (error), and the two-parameter closure is iOS 17-only. Logic gaps: `.activate(nil)` does not open the duration picker, and `.deactivate` only switches tabs. |

#### Core/Models
| File | State | Notes |
|------|-------|-------|
| `BlockedApp.swift` | **Conceptually wrong** | Keyed by bundle ID, with 24 hard-coded `commonApps`. iOS gives apps only opaque `ApplicationToken`s, so this model must be removed (§5.2). |
| `BlockedAttempt.swift` | Real | `AttemptType` (`app/message/call`), `AttemptOutcome`. Keep it; move it into `Shared/`. |
| `BlockedContact.swift` | Real | Built from `CNContact`. Keep it. |
| `DurationOption.swift` | Orphan | Has `presets`, which duplicate the list in `DurationPickerSheet`. Either use it from `DurationPickerSheet` or delete it. |
| `ProtectionSession.swift` | Real | Also defines `ActivationType` and `EndReason`. Move it into `Shared/` (the widget and extensions need it). |
| `UserSettings.swift` | Needs migration | `blockedAppBundleIDs: [String]` must go (§5.2). Not `Equatable`, which causes the SettingsView error. Uses synthesized `Codable`, so it will fail to decode once fields change; add `decodeIfPresent` defaults. |

#### Core/Services
| File | State | Notes |
|------|-------|-------|
| `ProtectionManager.swift` | **Stub core** | Session state, a 1-second `Timer`, and expiry while the app is running are real. Screen Time and Focus are `TODO`. Not `@MainActor`. Writes to `UserDefaults.standard` (the widget can't see it). `isAppBlocked(bundleIdentifier:)` is meaningless with tokens. Doesn't schedule notifications or reload widgets. |
| `ScreenTimeService.swift` | **Stub** | Authorization is faked via `UserDefaults "screenTimeAuthorized"`. `blockedAppTokens: Set<String>`. The real `ManagedSettingsStore` code is commented out. `temporarilyAllowApp` uses `asyncAfter`, which dies when the app is suspended. Line 133 declares `struct ShieldConfiguration`, which will **clash** with `ManagedSettingsUI.ShieldConfiguration`. |
| `PersistenceService.swift` | Real (wrong store) | JSON in `UserDefaults.standard`. Needs to move to App Group `UserDefaults(suiteName:)` with a one-time migration. `loadCurrentSession()` auto-expires sessions and writes them to history (keep that). |
| `SobrietyTestService.swift` | Real | Math (add/sub/mul) and reversed-phrase typing. Unit-testable. |
| `NotificationService.swift` | Real, **compile error** | Line 211: `center.setBadgeCount(0)` is iOS 17+. Categories are registered, but nothing handles the actions. Nothing calls `scheduleSessionEndingNotification` or `notifySessionEnded`. |
| `ContactsService.swift` | Real | `CNContactStore` enumeration (synchronous on the calling thread; fine for v1). |
| `BiometricService.swift` | Real, **orphan** | The `.opticID` case (line 37) needs the iOS 17 SDK. Never used. |
| `AppearanceManager.swift` | Real, **not applied** | Never applied: no `.preferredColorScheme(...)`, and `ContentView` hard-codes `.tint(.blue)`. |
| `HapticService.swift` | Real | — |
| `DeepLinkService.swift` | Real | Parsing is fine. Make `DeepLinkAction: Equatable`. Needs `CFBundleURLTypes`. |
| `LocationService.swift` | Real code, **defer** | Region monitoring. Needs `NSLocationAlwaysAndWhenInUseUsageDescription` and `NSLocationWhenInUseUsageDescription`. Nothing observes `.locationTriggered`. |
| `OuraService.swift` | **Stub, defer** | The OAuth exchange embeds a **client secret in the app**. The `fetch*` functions return `nil`. Tokens are stored in UserDefaults instead of the Keychain. |
| `PlaidService.swift` | **Stub, defer** | Calls the Plaid sandbox **directly from the app with `client_id` and `secret`**, which is never acceptable; it needs a backend. The access token is in UserDefaults. There is no Plaid Link SDK. |

#### Core/Extensions
| File | State | Notes |
|------|-------|-------|
| `Color+Extensions.swift` | Real, **risky** | `Color.init(_ name: String)` shadows SwiftUI's asset initializer `Color(_:bundle:)`, so the compiler may report ambiguity **(verify)** and asset-catalog color lookups silently return `.primary`. Rename it to `Color(named:)` and update the 4 call sites in `BlockedContactsView.swift:115-138`. Also defines `RoundedCorner`. |
| `Date+Extensions.swift` | Real | — |
| `String+Extensions.swift` | Real | — |
| `View+Extensions.swift` | Real, **compile error** | Line 54: two-parameter `onChange` is iOS 17-only. `HapticButton`, `cardStyle`, `glassStyle`, and `loadingOverlay` are unused. |

#### Features
| File | State | Notes |
|------|-------|-------|
| `Onboarding/OnboardingView.swift` | Real | Five pages, then **Get Started**. Writes both `UserSettings` and `@AppStorage`. |
| `Onboarding/PermissionsView.swift` | Real UI, stub backend | Three cards: Contacts (real), Screen Time (fake), Notifications (real). "Skip for Now" is always allowed. Uses `@StateObject` on singletons; that works, but `@ObservedObject` is the correct wrapper. |
| `Home/HomeView+Enhanced.swift` | Real | `EnhancedHomeView` is the live Home tab. Activation goes through the duration picker or quick actions. Deactivation goes through a confirmation dialog, then `SobrietyTestView`, then `deactivateProtection(.sobrietyTestPassed)`. |
| `Home/HomeView.swift` | Orphan | The older Home. Delete it. |
| `Home/Components/DurationPickerSheet.swift` | **Likely compile error** | Line 9: the instance stored property calls `private static func calculateTimeUntil8AM()` without qualification. Use `Date.timeUntil(hour: 8)` instead. Also, "Until 8 AM" is computed when the view is created, so the value goes stale. |
| `Home/Components/QuickActionsView.swift` | Real | — |
| `Home/Components/RecentActivityCard.swift` | Real | — |
| `Home/Components/StatusCard.swift` | **Compile error on iOS 16** | `.symbolEffect` (line 70) and two-parameter `onChange` (line 75) are iOS 17-only. |
| `Protection/SobrietyTest/SobrietyTestView.swift` | Real | Three attempts with a new question after each wrong answer; `onComplete(Bool)`. The live gate. |
| `Protection/SobrietyTest/MathTestView.swift` | Orphan | Custom number pad. |
| `Protection/SobrietyTest/TypingTestView.swift` | Orphan | — |
| `Protection/SobrietyTest/ReactionTestView.swift` | Orphan | — |
| `Protection/SobrietyTest/BalanceTestView.swift` | Orphan | `CMMotionManager` held in `@State`; should be a `@StateObject` wrapper or a plain object. |
| `Protection/ShieldView.swift` | Orphan, **cannot work as designed** | An in-app SwiftUI view. iOS never lets an app draw over another app. The real shield is a `ShieldConfigurationDataSource` extension (§4.4). Keep it only as an in-app "preview of your shield", or delete it. |
| `Protection/MessagePreviewView.swift` | Orphan, defer | `DelayedMessage` and `DelayedMessageService`, plus a `NotificationService` extension. There is no way to intercept a message before it is sent. |
| `Settings/SettingsView.swift` | **Compile error** | Line 168: `.onChange(of: settings)`, but `UserSettings` is not `Equatable`, and the closure is two-parameter. "Reset All Data" doesn't clear `@AppStorage` flags or shields, and isn't gated while protection is active. Shows `settings.blockedAppBundleIDs.count`. |
| `Settings/BlockedAppsView.swift` | **Must be rewritten** | Bundle-ID toggles over `BlockedApp.commonApps`. Line 42 uses a two-parameter `onChange`. Replace it with `FamilyActivityPicker` (§5.3). |
| `Settings/BlockedContactsView.swift` | Real | Real contact picking and persistence. It has no blocking effect on iOS, and the UI should say so (§6). |
| `Settings/EmergencyContactsView.swift` | Real | Same as above. `await contactsService.requestAccess()` result is unused (warning). |
| `Settings/ScheduleSettingsView.swift` | UI-only | `ProtectionSchedule`/`Weekday` are saved to `UserDefaults "protectionSchedules"`, but **nothing triggers activation**. A real version needs `DeviceActivityCenter` repeating schedules (Phase 5, optional). |
| `Settings/AppearanceSettingsView.swift` | UI-only effect | Writes `AppearanceManager`, which is never applied. |
| `Settings/PrivacySettingsView.swift` | Partly stub | Clearing history is real. Export only calls `print()`. |
| `Settings/HelpSupportView.swift` | Real | `mailto:` and `https://boozeblocker.app/help` links. Confirm the domain exists. |
| `Settings/IntegrationsView.swift` | Orphan, defer | Oura/Plaid/Location rows. Connect buttons only `print`. Toggles are `.constant(true)`. `AddLocationView` hard-codes Austin, TX coordinates. |
| `Settings/SiriShortcutsView.swift` | Orphan, defer | Donates `NSUserActivity` (`import Intents`). App Intents (iOS 16+) is the modern replacement. |
| `History/HistoryView.swift` | Real | — |
| `History/InsightsView.swift` | Real | Reached from the Home toolbar. |
| `History/MorningSummaryView.swift` | Orphan | Share only calls `print()`. Could be shown after a session ends (optional). |

#### Widget
| File | State | Notes |
|------|-------|-------|
| `Widget/BoozeBlockerWidget.swift` | Partial | There is **no `@main` `WidgetBundle`**, so the extension fails to link with no entry point. It defines `BoozeBlockerWidget` and `QuickActivateWidget`. It reads `ProtectionSession` from App Group `group.com.boozeblocker.app`, but the app writes to `.standard`, so the widget will always show "Not Protected". It needs the `ProtectionSession` source compiled into the widget target. It is missing `.containerBackground(for: .widget)`; on iOS 17 the system shows a "Please adopt containerBackground API" placeholder. `#Preview(as:timeline:)` is iOS 17-only. |

### 2.3 Expected compile errors with the current code

These are the first errors to expect once a target exists. The fix for each is noted.

| # | Location | Error | Fix |
|---|----------|-------|-----|
| E1 | `App/ContentView.swift:38` | `DeepLinkAction` does not conform to `Equatable` (`onChange` requires it) | Add `: Equatable` to `enum DeepLinkAction` |
| E2 | `Features/Settings/SettingsView.swift:168` | `UserSettings` does not conform to `Equatable` | Add `: Equatable` to `UserSettings` and `SobrietyTestDifficulty` (enums with raw values are already Equatable) |
| E3 | `ContentView:38`, `SettingsView:168`, `BlockedAppsView:42`, `StatusCard:75`, `View+Extensions:54` | `onChange(of:initial:_:)` with 2 params is only available in iOS 17 | Set the deployment target to 17.0 (D6) |
| E4 | `StatusCard.swift:70` | `symbolEffect` is only available in iOS 17 | Same |
| E5 | `NotificationService.swift:211` | `setBadgeCount` is only available in iOS 17 | Same |
| E6 | `BiometricService.swift:37` | `.opticID` availability **(verify)** | Same |
| E7 | `Widget/BoozeBlockerWidget.swift:276` | `#Preview(as:timeline:)` is iOS 17-only | Same |
| E8 | `DurationPickerSheet.swift:9` | Static member `calculateTimeUntil8AM` cannot be used on an instance **(verify)** | Replace with `Date.timeUntil(hour: 8)` and delete the static function |
| E9 | `ScreenTimeService.swift:133` | Once `ManagedSettingsUI` is imported anywhere in the same module, `ShieldConfiguration` is ambiguous | Delete the placeholder struct |
| E10 | Widget target | `ProtectionSession` not found in scope | Move it to `Shared/` with target membership in both app and widget |
| E11 | Widget target | No `@main` entry point | Add a `@main struct BoozeBlockerWidgets: WidgetBundle` |
| E12 | `Color+Extensions.swift:4` | Possible ambiguous use of `init(_:)` **(verify)** | Rename to `Color(named:)` |
| W1 | Several | Warnings: unused results, `@StateObject` on externally owned singletons, widget `containerBackground` | Fix in Phase 1 or 2 |

---

## 3. Project generation: XcodeGen

### 3.1 Why XcodeGen

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| Hand-write `project.pbxproj` | No tools needed | About 1,500 lines of 24-hex-character object IDs across 5+ targets, embed phases, and entitlements. Very easy to break, and impossible to review or merge. | No |
| Create it in Xcode by hand | Familiar | Can't be done from a Linux session, isn't reproducible, and produces huge diffs | No (but this is the fallback if the owner insists) |
| **XcodeGen** | One readable `project.yml`. Generates targets, extension embedding, Info.plist, and entitlements. Installs with `brew install xcodegen`. Widely used, stable. | Requires one regeneration step after adding files | **Yes** |
| Tuist | Powerful, with caching | Its own toolchain and version pinning, Swift manifests, and more concepts than a 5-target app needs | No |

### 3.2 Target folder layout

Steps 1.2–1.4 move files to produce this layout:

```
project.yml
BoozeBlocker/                      # app target (existing)
  App/  Core/  Features/
  Resources/
    Info.plist                     # generated/owned by project.yml `info:`
    BoozeBlocker.entitlements      # generated by project.yml `entitlements:`
    PrivacyInfo.xcprivacy          # new
    Assets.xcassets
Shared/                            # NEW — compiled into app + every extension
  AppGroup.swift                   # IDs + shared UserDefaults
  SharedStore.swift                # session / selection / attempt I/O
  ManagedSettings+Names.swift      # ManagedSettingsStore.Name.protection, DeviceActivityName.*
  Models/ProtectionSession.swift   # moved from Core/Models (+ ActivationType, EndReason)
  Models/BlockedAttempt.swift      # moved from Core/Models
BoozeBlockerWidget/                # NEW folder; move BoozeBlocker/Widget/BoozeBlockerWidget.swift here
  BoozeBlockerWidgetBundle.swift   # @main WidgetBundle
  BoozeBlockerWidget.swift
  Info.plist / BoozeBlockerWidget.entitlements
ShieldConfiguration/               # NEW ManagedSettingsUI extension
  ShieldConfigurationExtension.swift
  Info.plist / ShieldConfiguration.entitlements
ShieldAction/                      # NEW ManagedSettings extension
  ShieldActionExtension.swift
  Info.plist / ShieldAction.entitlements
DeviceActivityMonitor/             # NEW DeviceActivity extension (auto-end when app is not running)
  DeviceActivityMonitorExtension.swift
  Info.plist / DeviceActivityMonitor.entitlements
BoozeBlockerTests/                 # NEW unit tests
BoozeBlockerUITests/               # NEW smoke UI test (onboarding → tabs)
```

Notes on the extensions:
- **The user asked for the Shield Configuration extension.** The plan adds two more extensions, for these reasons:
  - The **Shield Action** extension is what responds to the buttons on the shield. Without it, tapping a button does nothing useful.
  - The **Device Activity Monitor** extension is the only way to *remove* shields when a timed session ends while the app is suspended or killed. Without it, a "4 hours" session keeps blocking until the user opens BoozeBlocker again.

### 3.3 `project.yml`

This is the full intended content. Replace `CHANGEME` per D1, D2, and D4.

```yaml
name: BoozeBlocker
options:
  bundleIdPrefix: com.CHANGEME
  deploymentTarget:
    iOS: "17.0"
  createIntermediateGroups: true
  generateEmptyDirectories: true
settings:
  base:
    DEVELOPMENT_TEAM: CHANGEME          # or move to Config/Signing.xcconfig (gitignored)
    CODE_SIGN_STYLE: Automatic
    SWIFT_VERSION: "5.9"
    MARKETING_VERSION: "1.0.0"
    CURRENT_PROJECT_VERSION: "1"
    TARGETED_DEVICE_FAMILY: "1"
    ENABLE_USER_SCRIPT_SANDBOXING: YES
    SWIFT_STRICT_CONCURRENCY: minimal  # raise later
  configs:
    Debug:
      SWIFT_ACTIVE_COMPILATION_CONDITIONS: "DEBUG"

targets:
  BoozeBlocker:
    type: application
    platform: iOS
    sources:
      - path: BoozeBlocker
      - path: Shared
    resources: []                       # Assets/PrivacyInfo are picked up from sources automatically
    info:
      path: BoozeBlocker/Resources/Info.plist
      properties:
        CFBundleDisplayName: Booze Blocker
        CFBundleShortVersionString: $(MARKETING_VERSION)
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
        LSRequiresIPhoneOS: true
        UILaunchScreen: {}               # plain launch screen until assets exist
        UISupportedInterfaceOrientations: [UIInterfaceOrientationPortrait]
        UIApplicationSceneManifest:
          UIApplicationSupportsMultipleScenes: false
        CFBundleURLTypes:
          - CFBundleURLName: $(PRODUCT_BUNDLE_IDENTIFIER)
            CFBundleURLSchemes: [boozeblocker]
        NSContactsUsageDescription: "Booze Blocker needs access to your contacts so you can select which people to block while drinking and designate emergency contacts."
        NSFaceIDUsageDescription: "Use Face ID to verify your identity for sensitive actions."
        AppGroupIdentifier: group.com.CHANGEME.boozeblocker   # read at runtime by AppGroup.swift
    entitlements:
      path: BoozeBlocker/Resources/BoozeBlocker.entitlements
      properties:
        com.apple.developer.family-controls: true
        com.apple.security.application-groups: [group.com.CHANGEME.boozeblocker]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.CHANGEME.boozeblocker
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
    dependencies:
      - target: BoozeBlockerWidget
      - target: ShieldConfiguration
      - target: ShieldAction
      - target: DeviceActivityMonitor
      - sdk: FamilyControls.framework
      - sdk: ManagedSettings.framework
      - sdk: DeviceActivity.framework

  BoozeBlockerWidget:
    type: app-extension
    platform: iOS
    sources:
      - path: BoozeBlockerWidget
      - path: Shared
    info:
      path: BoozeBlockerWidget/Info.plist
      properties:
        CFBundleDisplayName: Booze Blocker Widget
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
        AppGroupIdentifier: group.com.CHANGEME.boozeblocker
    entitlements:
      path: BoozeBlockerWidget/BoozeBlockerWidget.entitlements
      properties:
        com.apple.security.application-groups: [group.com.CHANGEME.boozeblocker]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.CHANGEME.boozeblocker.widget
    dependencies:
      - sdk: WidgetKit.framework
      - sdk: SwiftUI.framework

  ShieldConfiguration:
    type: app-extension
    platform: iOS
    sources:
      - path: ShieldConfiguration
      - path: Shared
    info:
      path: ShieldConfiguration/Info.plist
      properties:
        CFBundleDisplayName: Booze Blocker Shield
        NSExtension:
          NSExtensionPointIdentifier: com.apple.ManagedSettingsUI.shield-configuration-service
          NSExtensionPrincipalClass: $(PRODUCT_MODULE_NAME).ShieldConfigurationExtension
        AppGroupIdentifier: group.com.CHANGEME.boozeblocker
    entitlements:
      path: ShieldConfiguration/ShieldConfiguration.entitlements
      properties:
        com.apple.developer.family-controls: true
        com.apple.security.application-groups: [group.com.CHANGEME.boozeblocker]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.CHANGEME.boozeblocker.shieldconfig
    dependencies:
      - sdk: ManagedSettings.framework
      - sdk: ManagedSettingsUI.framework

  ShieldAction:
    type: app-extension
    platform: iOS
    sources:
      - path: ShieldAction
      - path: Shared
    info:
      path: ShieldAction/Info.plist
      properties:
        CFBundleDisplayName: Booze Blocker Shield Action
        NSExtension:
          NSExtensionPointIdentifier: com.apple.ManagedSettings.shield-action-service
          NSExtensionPrincipalClass: $(PRODUCT_MODULE_NAME).ShieldActionExtension
        AppGroupIdentifier: group.com.CHANGEME.boozeblocker
    entitlements:
      path: ShieldAction/ShieldAction.entitlements
      properties:
        com.apple.developer.family-controls: true
        com.apple.security.application-groups: [group.com.CHANGEME.boozeblocker]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.CHANGEME.boozeblocker.shieldaction
    dependencies:
      - sdk: ManagedSettings.framework
      - sdk: UserNotifications.framework

  DeviceActivityMonitor:
    type: app-extension
    platform: iOS
    sources:
      - path: DeviceActivityMonitor
      - path: Shared
    info:
      path: DeviceActivityMonitor/Info.plist
      properties:
        CFBundleDisplayName: Booze Blocker Monitor
        NSExtension:
          NSExtensionPointIdentifier: com.apple.deviceactivity.monitor-extension
          NSExtensionPrincipalClass: $(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension
        AppGroupIdentifier: group.com.CHANGEME.boozeblocker
    entitlements:
      path: DeviceActivityMonitor/DeviceActivityMonitor.entitlements
      properties:
        com.apple.developer.family-controls: true
        com.apple.security.application-groups: [group.com.CHANGEME.boozeblocker]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.CHANGEME.boozeblocker.activitymonitor
    dependencies:
      - sdk: DeviceActivity.framework
      - sdk: ManagedSettings.framework

  BoozeBlockerTests:
    type: bundle.unit-test
    platform: iOS
    sources: [BoozeBlockerTests]
    dependencies: [{ target: BoozeBlocker }]

  BoozeBlockerUITests:
    type: bundle.ui-testing
    platform: iOS
    sources: [BoozeBlockerUITests]
    dependencies: [{ target: BoozeBlocker }]

schemes:
  BoozeBlocker:
    build:
      targets: { BoozeBlocker: all }
    test:
      targets: [BoozeBlockerTests, BoozeBlockerUITests]
    run:
      commandLineArguments: { "-resetState": false }
```

Things to know about this file:
- XcodeGen **overwrites** the `info.path` and `entitlements.path` files from `properties` every time it runs. Treat `project.yml` as the single source of truth, and don't edit those plists by hand.
- The `Shared/` sources are compiled separately into every target. Do not create a framework for v1; it adds embedding and signing complexity. Every file in `Shared/` must only import frameworks that are available in *every* target that compiles it. Foundation is fine. `FamilyControls` is not wanted in the widget, so keep selection decoding in a separate `Shared/SelectionStore.swift` that is listed only in the app and the extensions that need it. Use per-target `sources` with `excludes`.
- The Shield Action extension can't link SwiftUI views from the app; it only needs ManagedSettings and UserNotifications.

### 3.4 `PrivacyInfo.xcprivacy` (app and each extension)

Declare `NSPrivacyAccessedAPICategoryUserDefaults` with these reasons:
- `CA92.1`: the app's own defaults.
- `1C8F.1`: App Group defaults shared with extensions.

Also set `NSPrivacyTracking = false` and give an empty `NSPrivacyCollectedDataTypes`. If this is missing, App Store Connect will warn or reject the build.

---

## 4. Real Screen Time integration

Background on how Apple's model works:
- The app **never sees bundle IDs**. The user picks apps, categories, and web domains in Apple's `FamilyActivityPicker`. The result is a `FamilyActivitySelection` of opaque tokens: `ApplicationToken`, `ActivityCategoryToken`, `WebDomainToken`.
- The app persists that selection (it is `Codable`), and applies it to a `ManagedSettingsStore` to shield those apps.
- The shield UI is drawn by the system, using text and colors supplied by the Shield Configuration extension.

### 4.1 `Shared/AppGroup.swift`

```swift
import Foundation

enum AppGroup {
    static let id: String = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
        ?? "group.com.CHANGEME.boozeblocker"
    static let defaults: UserDefaults = UserDefaults(suiteName: id)!   // crash early if entitlement missing
}

enum SharedKeys {
    static let currentSession = "currentSession"
    static let sessionHistory = "sessionHistory"
    static let userSettings = "userSettings"
    static let activitySelection = "familyActivitySelection"   // Data (JSON of FamilyActivitySelection)
    static let pendingAttempts = "pendingBlockedAttempts"      // [BlockedAttempt] written by extensions
    static let migratedFromStandard = "migratedFromStandardV1"
}
```

### 4.2 `Shared/ManagedSettings+Names.swift`

List this file only in the app and the three Screen Time extensions.

```swift
import ManagedSettings
import DeviceActivity

extension ManagedSettingsStore.Name {
    static let protection = Self("protection")
}
extension DeviceActivityName {
    static let protectionSession = Self("protectionSession")
    static let temporaryAllow = Self("temporaryAllow")
}
```

### 4.3 Rewrite `Core/Services/ScreenTimeService.swift`

Replace the simulated version entirely.

```swift
import Foundation
import Combine
import FamilyControls
import ManagedSettings
import DeviceActivity

@MainActor
final class ScreenTimeService: ObservableObject {
    static let shared = ScreenTimeService()

    @Published private(set) var authorizationStatus: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @Published var selection: FamilyActivitySelection { didSet { saveSelection() } }
    @Published private(set) var isBlocking = false

    var isAuthorized: Bool { authorizationStatus == .approved }
    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty
    }

    private let store = ManagedSettingsStore(named: .protection)
    private let activityCenter = DeviceActivityCenter()
    private var cancellables = Set<AnyCancellable>()

    private init() {
        selection = Self.loadSelection()
        AuthorizationCenter.shared.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$authorizationStatus)
        isBlocking = store.shield.applications != nil || store.shield.applicationCategories != nil
    }

    func requestAuthorization() async -> Bool {
        do { try await AuthorizationCenter.shared.requestAuthorization(for: .individual) }
        catch { print("FamilyControls auth failed: \(error)") }   // e.g. FamilyControlsError.restricted / .unavailable / .invalidAccountType
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        return isAuthorized
    }

    func startBlocking(until endDate: Date?) {
        guard isAuthorized else { return }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.application.denyAppRemoval = true                       // D11
        isBlocking = true
        if let endDate { scheduleAutoEnd(at: endDate) }
    }

    func stopBlocking() {
        store.clearAllSettings()
        activityCenter.stopMonitoring([.protectionSession, .temporaryAllow])
        isBlocking = false
    }

    /// Re-applies shields after launch if a session is active but the store was cleared (e.g. reinstall).
    func reconcile(sessionActive: Bool, endDate: Date?) {
        if sessionActive && !isBlocking { startBlocking(until: endDate) }
        if !sessionActive && isBlocking { stopBlocking() }
    }

    private func scheduleAutoEnd(at endDate: Date) {
        let cal = Calendar.current
        let now = Date()
        // DeviceActivity requires >= 15 min intervals; shorter sessions rely on the in-app timer (+ reconcile on launch).
        guard endDate.timeIntervalSince(now) >= 15 * 60 else { return }
        let comps: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: cal.dateComponents(comps, from: now),
            intervalEnd: cal.dateComponents(comps, from: endDate),
            repeats: false)
        do { try activityCenter.startMonitoring(.protectionSession, during: schedule) }
        catch { print("startMonitoring failed: \(error)") }   // intervalTooShort / excessiveActivities etc.
    }

    private func saveSelection() {
        if let data = try? JSONEncoder().encode(selection) { AppGroup.defaults.set(data, forKey: SharedKeys.activitySelection) }
    }
    private static func loadSelection() -> FamilyActivitySelection {
        guard let data = AppGroup.defaults.data(forKey: SharedKeys.activitySelection),
              let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return FamilyActivitySelection() }
        return sel
    }
}
```

Remove the following:
- the `blockedAppTokens: Set<String>` property
- `isAppBlocked(bundleIdentifier:)`
- the `asyncAfter`-based `temporarilyAllowApp`
- the placeholder `ShieldConfiguration` struct

Keep the `.appBlockingStarted`/`.appBlockingStopped` notification names only if something listens to them. Currently nothing does, so delete them.

Constraints to respect **(verify on device)**:
- `shield.applications` accepts at most **50 tokens**. If the picker returns more, show a warning or prefer categories.
- Shielding Apple's **Phone** app and emergency calls is not possible in practice. Messages, FaceTime, and Mail can be selected in the picker.
- `authorizationStatus` can flip to `.denied` at any time. With `.individual` authorization, the user can revoke access in Settings → Screen Time.

### 4.4 Shield Configuration extension (`ShieldConfiguration/ShieldConfigurationExtension.swift`)

```swift
import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private func make(_ name: String?) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: UIColor.systemIndigo.withAlphaComponent(0.6),
            icon: UIImage(systemName: "shield.checkmark.fill"),
            title: .init(text: "\(name ?? "This app") is blocked", color: .white),
            subtitle: .init(text: "Booze Blocker is protecting you tonight.", color: .white.withAlphaComponent(0.8)),
            primaryButtonLabel: .init(text: "Stay Protected", color: .systemIndigo),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: .init(text: "I need access", color: .white))
    }
    override func configuration(shielding application: Application) -> ShieldConfiguration { make(application.localizedDisplayName) }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { make(application.localizedDisplayName) }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { make(webDomain.domain) }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { make(webDomain.domain) }
}
```

- The shield can only show the fields above: icon, title, subtitle, two buttons, and colors/blur. It cannot use arbitrary SwiftUI, so the existing `ShieldView.swift` design must be reduced to this.
- Optionally, read `AppGroup.defaults` to show the time remaining in the subtitle. Recompute it from `currentSession.scheduledEndTime`.

### 4.5 Shield Action extension (`ShieldAction/ShieldActionExtension.swift`)

```swift
import ManagedSettings
import UserNotifications

final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        SharedStore.appendPendingAttempt(type: .app, targetName: "Blocked app",
                                         targetIdentifier: SharedStore.tokenID(application),
                                         outcome: .blocked)
        switch action {
        case .primaryButtonPressed:
            completionHandler(.close)
        case .secondaryButtonPressed:
            // There is no API to open the host app from a shield. Post a local notification that deep-links
            // to boozeblocker://deactivate, where the sobriety test is shown.
            let content = UNMutableNotificationContent()
            content.title = "Want access?"
            content.body = "Open Booze Blocker and pass the sobriety test."
            content.userInfo = ["url": "boozeblocker://deactivate"]
            UNUserNotificationCenter.current().add(.init(identifier: "shield-request", content: content, trigger: nil))
            completionHandler(.defer)
        @unknown default:
            completionHandler(.close)
        }
    }
    // Implement the same for `for webDomain: WebDomainToken` and `for category: ActivityCategoryToken`.
}
```

- `SharedStore.tokenID(_:)` returns a stable string for a token, such as a SHA-256 hash of the token's `JSONEncoder` output.
- The extension **cannot** resolve the app's name, so `targetName` is generic. History rows show "Blocked app" with a `Label(token)` in the main app when the token can be decoded.
- On the next foreground, `ProtectionManager.ingestPendingAttempts()` moves `pendingBlockedAttempts` into `currentSession.blockedAttempts`.

### 4.6 Device Activity Monitor extension (`DeviceActivityMonitor/DeviceActivityMonitorExtension.swift`)

```swift
import DeviceActivity
import ManagedSettings
import Foundation

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == .protectionSession else { return }
        ManagedSettingsStore(named: .protection).clearAllSettings()
        SharedStore.endCurrentSession(reason: .timerExpired)   // moves session to history in App Group
        // WidgetCenter is not available here; the widget refreshes on its next timeline tick.
    }
}
```

`SharedStore.endCurrentSession` is a small, Foundation-only copy of the `PersistenceService` logic that operates on `AppGroup.defaults`. To avoid duplicating it, move the session/history read and write code from `PersistenceService` into `SharedStore`, and have `PersistenceService` call it.

### 4.7 `FamilyActivityPicker` UI: rewrite `Features/Settings/BlockedAppsView.swift`

```swift
import SwiftUI
import FamilyControls

struct BlockedAppsView: View {
    @EnvironmentObject var screenTime: ScreenTimeService
    @EnvironmentObject var protectionManager: ProtectionManager
    @State private var showPicker = false

    var body: some View {
        List {
            if !screenTime.isAuthorized {
                Section { Button("Allow Screen Time Access") { Task { await screenTime.requestAuthorization() } } }
                    footer: { Text("Required to block apps. Your selection never leaves your device.") }
            }
            Section {
                Button("Choose Apps & Categories") { showPicker = true }
                    .disabled(!screenTime.isAuthorized || protectionManager.isProtectionActive)   // D7
            } footer: {
                if protectionManager.isProtectionActive { Text("You can't change blocked apps while protection is active.") }
            }
            Section("Apps") { ForEach(Array(screenTime.selection.applicationTokens), id: \.self) { Label($0) } }
            Section("Categories") { ForEach(Array(screenTime.selection.categoryTokens), id: \.self) { Label($0) } }
            Section("Websites") { ForEach(Array(screenTime.selection.webDomainTokens), id: \.self) { Label($0) } }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $screenTime.selection)
        .navigationTitle("Blocked Apps")
    }
}
```

- Delete `AppIconPlaceholder` and the `BlockedApp.commonApps` list. `Label(token)` renders the real app icon and name.
- **Optional onboarding step:** after Screen Time is granted in `PermissionsView`, show a "Choose apps to block" button that opens the same picker. Without a selection, activating protection does nothing.

---

## 5. Data model changes

### 5.1 Overview

| Model / API | Change |
|-------------|--------|
| `UserSettings.blockedAppBundleIDs` | **Remove.** Add `Equatable`. Add a custom `init(from:)` that uses `decodeIfPresent` for every field, so old JSON that still contains `blockedAppBundleIDs` decodes. Extra keys are ignored automatically; the custom init is there to tolerate *missing* keys later. |
| `BlockedApp` (+ `commonApps`) | **Delete the file.** |
| `PersistenceService.saveBlockedApps/loadBlockedApps`, `Keys.blockedApps` | **Delete.** In migration, remove the `blockedApps` key. |
| `ProtectionManager.isAppBlocked(bundleIdentifier:)` | **Delete** (no callers). |
| `ScreenTimeService.blockedAppTokens: Set<String>` | Replace with `selection: FamilyActivitySelection`, persisted as JSON under `SharedKeys.activitySelection` in App Group defaults. |
| `BlockedAttempt.targetIdentifier` | Keep it as a `String`. For apps, it holds `SharedStore.tokenID(token)`. |
| `SettingsView` "Blocked Apps" count | Change to `screenTime.selection.applicationTokens.count + screenTime.selection.categoryTokens.count`. |
| `UserSettings.hasCompletedOnboarding` and `@AppStorage("hasCompletedOnboarding")` | Keep **one** source: the `@AppStorage` value. Remove the field from `UserSettings` and delete the duplicate write in `OnboardingView.completeOnboarding()`. |
| `DeepLinkAction` | Add `Equatable`. |

### 5.2 Why tokens instead of bundle IDs

- `ManagedSettingsStore.shield.applications` only accepts `Set<ApplicationToken>`.
- Tokens can only be obtained from `FamilyActivityPicker`, or from `Application(bundleIdentifier:)`. The latter **cannot** be used to shield. Its token is nil unless the app came from the picker **(verify)**.
- Tokens are device-specific and opaque, so a curated "24 common apps" list cannot be shipped. The picker's category tokens (Social, Games, …) are the closest replacement for "one-tap block social media".

### 5.3 Migration (one time, in `PersistenceService.init`)

1. If `AppGroup.defaults.bool(forKey: SharedKeys.migratedFromStandard)` is false, copy `userSettings`, `currentSession`, `sessionHistory`, and `blockedContacts` from `UserDefaults.standard` to `AppGroup.defaults`.
2. Remove `blockedApps` and `screenTimeAuthorized` from `.standard`.
3. Set the migrated flag.
4. Because there are no real users yet, this is mostly to avoid surprises on developer devices.

---

## 6. Platform limits and entitlements

### 6.1 Required capabilities and entitlements

| Capability | Targets | Requires | Notes |
|------------|---------|----------|-------|
| `com.apple.developer.family-controls` | App, ShieldConfiguration, ShieldAction, DeviceActivityMonitor | **Paid** Developer Program. Development works once the capability is enabled on each App ID. **Distribution** (TestFlight/App Store/Ad Hoc) needs Apple's approval through the Family Controls entitlement request form, for **each** bundle ID. | Without it: `requestAuthorization` throws, the picker shows nothing, and shields don't apply. |
| `com.apple.security.application-groups` | All 5 targets | Any account that can create App Groups (paid) | Shared session, selection, and attempts |
| Push / Background Modes | none | — | Not needed. Remove `UIBackgroundModes`. |
| CallKit Call Directory (optional, §6.3) | New extension | Paid account, no special approval | Blocks incoming calls only |

### 6.2 What works with each account level

| Feature | Free account / Simulator | Paid account + dev entitlement on device | + Distribution approval |
|---------|--------------------------|-------------------------------------------|-------------------------|
| UI, onboarding, tabs, sessions, history, insights, sobriety tests | Yes | Yes | Yes |
| Contacts picking, notifications, haptics, Face ID | Yes (Simulator supports most) | Yes | Yes |
| Widget | Yes (needs App Group; Simulator OK with automatic signing) | Yes | Yes |
| Screen Time authorization, `FamilyActivityPicker`, shields | **No.** Simulator support is unreliable or absent; plan on device-only **(verify)**. | Yes, on the developer's device | Yes, for testers and users |
| Auto-end via DeviceActivity when the app is killed | No | Yes | Yes |

**Simulator fallback.** Wrap all `FamilyControls` calls behind a `BlockingController` protocol with two implementations:
- `ScreenTimeBlockingController`: the real one.
- `NoopBlockingController`: used when the build runs in the Simulator (`#if targetEnvironment(simulator)`) or when `FeatureFlags.screenTimeEnabled == false`.

With this in place, the whole app runs in the Simulator, and the Screen Time UI shows a "Requires a real device" banner.

### 6.3 What iOS does not allow

| Promised in the README / UI | Reality on iOS 17 | What v1 should do |
|------------------------------|-------------------|-------------------|
| Block texting specific contacts | No public API to intercept or block outgoing SMS/iMessage. Screen Time "Communication Limits" exist, but there is no API for them. | Shield the whole **Messages**, WhatsApp, and similar apps. Label the Contacts screen honestly: "Used for your summary and emergency list. iOS doesn't allow blocking individual contacts. Block Messages/WhatsApp to prevent texting." |
| Block calling specific contacts | Outgoing calls can't be intercepted. Phone and emergency calls stay available. | Same honest copy. Optional Phase 7: a **CallKit Call Directory extension** that blocks **incoming** calls from blocked contacts' numbers while protection is active. The app writes numbers to the App Group and calls `CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier:)` on start and stop. |
| `ShieldView` "Request 5 Minutes" | Shields can be lifted only from the app or the extensions. DeviceActivity schedules need ≥ 15 minutes. | Make temporary access part of the sobriety-test flow inside the app: pass the test, then the shield is lifted for 15 minutes using a `temporaryAllow` DeviceActivity interval whose `intervalDidEnd` reapplies shields. Or drop the feature. |
| Count every blocked attempt | Opening a shielded app does not notify the host app. Only a tap on a shield button reaches `ShieldActionDelegate`. | Count shield button taps only, and change the UI wording to "times you hit a shield". |
| Focus Mode for contacts (`// TODO: Activate Focus Mode`) | Apps can't turn Focus on or off. A Focus filter (`SetFocusFilterIntent`) only lets the *user's* Focus configure the app. | Remove the TODO. |
| A blocker the user can't escape | With `.individual` authorization the user can revoke Screen Time access in Settings, or turn off Screen Time. `denyAppRemoval` stops deleting the app, not revoking access. | Present it as a "speed bump", not enforcement. Optionally detect `authorizationStatus != .approved` on the next launch and log it to history. |

---

## 7. Wiring `ProtectionManager` and the sobriety gate

### 7.1 `ProtectionManager` changes (`Core/Services/ProtectionManager.swift`)

1. Mark it `@MainActor final class`. Inject its dependencies, with the singletons as defaults: `init(persistence:blocker:notifications:widgets:)`. Tests pass mocks.
2. `activateProtection(duration:type:)`:
   1. `guard !isProtectionActive`.
   2. If `blocker.isAuthorized == false || !blocker.hasSelection`, still start the session (the in-app timer and history work) and set `@Published var blockingWarning: String?`, for example "No apps selected — nothing is being blocked". `StatusCard` shows this warning.
   3. Create the session, `persistence.saveCurrentSession`.
   4. `blocker.startBlocking(until: session.scheduledEndTime)`.
   5. `notifications.scheduleSessionEndingNotification(endTime:)` when there is an end time.
   6. `WidgetCenter.shared.reloadAllTimelines()`.
   7. `startTimerIfNeeded()`, then post `.protectionActivated`.
3. `deactivateProtection(reason:)`:
   1. End the session and add it to history.
   2. `blocker.stopBlocking()`.
   3. `notifications.cancelSessionNotifications()`, then `notifySessionEnded(blockedAttempts:)`.
   4. Reload widgets, stop the timer, post `.protectionDeactivated`.
4. **Launch and foreground reconcile.** Call this from `init` and from `scenePhase == .active` in `BoozeBlockerApp`:
   1. `ingestPendingAttempts()` from the App Group.
   2. `loadCurrentSession()`. The existing auto-expire logic stays, but it now runs on `AppGroup.defaults`.
   3. `blocker.reconcile(sessionActive: isProtectionActive, endDate: currentSession?.scheduledEndTime)`.
   4. If the extension already ended the session (`currentSession == nil` while the old in-memory one was active), publish the state change.
5. `timerTick` expiry calls `deactivateProtection(reason: .timerExpired)`. This is unchanged, but it now also clears the shields.
6. Delete `isAppBlocked(bundleIdentifier:)`. Keep `isContactBlocked` for the CallKit option, or delete it.

### 7.2 Sobriety gate: every path that ends protection must pass the test

| Path | Current behaviour | Required change |
|------|-------------------|-----------------|
| Home → Stop → confirmation → `SobrietyTestView` (both `HomeView` variants) | Correct | Keep it. Add the D8 cooldown: persist `lastFailedTestAt` and disable the "Take Sobriety Test" button with a countdown. |
| Timer expiry (in the app) | `deactivateProtection(.timerExpired)` | Keep it; it now also clears shields. |
| Timer expiry (app killed) | Session expires only on the next launch, and shields would persist | The DeviceActivityMonitor `intervalDidEnd` clears shields and ends the session (§4.6). Sessions shorter than 15 minutes rely on the in-app timer and launch reconcile. Make the picker's minimum 1 hour, so this edge case never happens. |
| Deep link `boozeblocker://deactivate` | Only switches to the Home tab | Present `SobrietyTestView`. **Never** deactivate directly from a URL. |
| Deep link `boozeblocker://activate` with no duration | Does nothing | Open `DurationPickerSheet`. Lift the Home sheet state into `ContentView`, or use a `@Published var showDurationPicker` on `DeepLinkService`. |
| Settings → Reset All Data | Wipes data, leaves `@AppStorage`, ignores the active session | `.disabled(protectionManager.isProtectionActive)`. When not active, also clear `ScreenTimeService.selection`, call `stopBlocking()`, and reset the `@AppStorage` flags. |
| Blocked Apps editing while active | Possible | Disabled (D7, §4.7). |
| Shield "I need access" button | — | Sends a notification. Tapping it opens the app at `boozeblocker://deactivate` → sobriety test (§4.5). Needs a `UNUserNotificationCenterDelegate` in an `AppDelegate`, wired with `@UIApplicationDelegateAdaptor`. It forwards `userInfo["url"]` to `DeepLinkService.handle(url:)` and handles the `EXTEND_SESSION`, `ACTIVATE_PROTECTION`, and `VIEW_ATTEMPTS` actions. |
| Revoking Screen Time access in iOS Settings | — | This can't be prevented. Detect it on launch (`authorizationStatus`) and show a banner. |

Optional: let `SobrietyTestView` rotate through the orphaned `MathTestView`, `TypingTestView`, `ReactionTestView`, and `BalanceTestView` according to difficulty. Each already exposes `onComplete: (Bool) -> Void`. Wire this after v1 works.

### 7.3 Widget wiring

- Move `ProtectionSession` and `BlockedAttempt` to `Shared/`.
- Read `SharedKeys.currentSession` from `AppGroup.defaults`.
- Add `BoozeBlockerWidgetBundle` containing `BoozeBlockerWidget()` and `QuickActivateWidget()`.
- Add `.containerBackground(for: .widget) { … }` to all three entry views, replacing the `ContainerRelativeShape` backgrounds.
- In `getTimeline`, return entries every 60 s while protected, up to `scheduledEndTime`.

---

## 8. Feature flags: what to defer

Add `BoozeBlocker/Core/FeatureFlags.swift`:

```swift
enum FeatureFlags {
    static let screenTimeEnabled = true          // false → NoopBlockingController everywhere
    static let integrationsEnabled = false       // Oura, Plaid, Location (IntegrationsView)
    static let siriShortcutsEnabled = false      // SiriShortcutsView (replace with App Intents later)
    static let delayedMessagesEnabled = false    // MessagePreviewView / DelayedMessageService
    static let schedulesEnabled = false          // ScheduleSettingsView until DeviceActivity schedules are implemented
    static let extraSobrietyTests = false        // Math/Typing/Reaction/Balance views
    static let morningSummaryEnabled = false
}
```

| Item | Action for v1 | Why |
|------|---------------|-----|
| `OuraService` + IntegrationsView Oura row | Off. Don't instantiate the singleton (it is only created lazily from `IntegrationsView`, which is unreachable today). | The fetch functions are placeholders, and a client secret must never ship in the binary. To enable: a backend for the token exchange, Keychain storage, and real `/v2/usercollection/*` calls. |
| `PlaidService` + Plaid row | Off | Calling Plaid with `client_id`/`secret` from a device violates Plaid's terms and leaks credentials. To enable: a server, the Plaid Link iOS SDK, and webhooks for transactions. |
| `LocationService` + Location row, `SavedLocationsView`, `AddLocationView` | Off | Info.plist keys are missing, coordinates are hard-coded, and nothing listens for `.locationTriggered`. Also, Always-location triggers heavy App Review scrutiny. To enable: Info.plist keys, a MapKit picker, and a `.locationTriggered` → `activateProtection(type: .location)` observer (a notification prompt, since the app can't activate in the background without the user). |
| `SiriShortcutsView` | Off | It only donates `NSUserActivity` and has no `NSUserActivityTypes`. Replace it with `AppIntent`s (`ActivateProtectionIntent`) in a later phase. |
| `MessagePreviewView` / `DelayedMessageService` | Off | Messages can't be intercepted (§6.3). |
| `ScheduleSettingsView` | Off (or "Coming soon") | Saving schedules does nothing. A real version uses repeating `DeviceActivitySchedule`s (one `DeviceActivityName` per schedule, with a 20-activity limit **(verify)**). The monitor's `intervalDidStart` applies shields and creates a `.scheduled` session in the App Group. |
| `BiometricService` | Keep compiled. Unused unless D9 chooses Face ID. | — |
| Orphan `HomeView.swift`, `ShieldView.swift`, `DurationOption.swift`, `View+Extensions` helpers | Delete `HomeView` and `DurationOption` (or use presets). Keep `ShieldView` only as an in-app preview. | Less dead code. |

Gate each entry point in `SettingsView`. Add an "Integrations (beta)" row only when `FeatureFlags.integrationsEnabled` is on. `ActivationType.location/.ouraDetected/.creditCard` stay in the model for history compatibility.

---

## 9. Execution phases

Each phase is one PR. PRs 1–2 can be done on Linux plus a macOS CI or macOS session. PR 3 and later need a Mac for compile checks, and a physical device plus a paid account to validate blocking.

### Phase 0: Prerequisites (owner)
- [ ] Answer D1–D12.
- [ ] Join the paid Developer Program, then register the App IDs and App Group in the developer portal. Xcode automatic signing can also do this.
- [ ] Submit the Family Controls (Distribution) request for all four Family Controls bundle IDs.

### Phase 1: Buildable project, no behaviour change (PR 1)
1. Add `project.yml` (§3.3). At first, include only the **app target**, the **widget**, and the test targets. Add the Screen Time extensions in Phase 3, so Phase 1 compiles without the entitlement.
2. Delete `Package.swift`. Delete the old `BoozeBlocker.xcodeproj/project.pbxproj` and regenerate it.
3. Run `git mv BoozeBlocker/Widget/BoozeBlockerWidget.swift BoozeBlockerWidget/`. Create `Shared/Models/`, then `git mv` `ProtectionSession.swift` and `BlockedAttempt.swift` into it.
4. Info.plist cleanup through `project.yml` `info.properties`:
   - remove `armv7`, the background modes, `NSUserTrackingUsageDescription`, and the iPad orientations
   - replace `UILaunchScreen` with `{}`
   - add `CFBundleURLTypes`
5. Fix compile errors E1, E2, E8, E9, E11, and E12 (§2.3). Setting the deployment target to 17.0 resolves E3–E7.
6. Add `BoozeBlockerWidgetBundle.swift` and `.containerBackground`.
7. Add `PrivacyInfo.xcprivacy`.
8. Run `xcodegen generate`, then `xcodebuild` for the Simulator (§10) until there are 0 errors.
9. Rewrite the README "Setup" section: `brew install xcodegen && xcodegen generate && open BoozeBlocker.xcodeproj`.

### Phase 2: App Group persistence and a working widget (PR 2)
1. Add `Shared/AppGroup.swift` and `Shared/SharedStore.swift`.
2. Point `PersistenceService` at `AppGroup.defaults`, and add the migration (§5.3).
3. Make `UserSettings` `Equatable`, give it a tolerant decoder, and remove `hasCompletedOnboarding` from it.
4. Widget: read the App Group, add per-minute timelines, and call `WidgetCenter.reloadAllTimelines()` from `ProtectionManager`.
5. Add `AppDelegate` with `UNUserNotificationCenterDelegate`, and make deep links from notifications work.
6. Wire `NotificationService` into `ProtectionManager` activate and deactivate.
7. Apply `AppearanceManager`: `.preferredColorScheme(appearanceManager.colorScheme.colorScheme)` and `.tint(appearanceManager.accentColor.color)` at the root.

### Phase 3: Screen Time (PR 3; needs a paid account to run on device)
1. Add the three extension targets and the Family Controls entitlements to `project.yml`.
2. Add `Shared/ManagedSettings+Names.swift`.
3. Rewrite `ScreenTimeService` (§4.3) behind a `BlockingController` protocol, plus a `NoopBlockingController` for the Simulator.
4. Implement the Shield Configuration (§4.4), Shield Action (§4.5), and Device Activity Monitor (§4.6) extensions.
5. Make the model changes (§5): delete `BlockedApp` and `blockedAppBundleIDs`, and rewrite `BlockedAppsView` (§4.7).
6. Use the real authorization in `PermissionsView`, and add the "Choose apps" step.

### Phase 4: Protection wiring and gate hardening (PR 4)
1. Make the `ProtectionManager` changes (§7.1), including reconcile on `scenePhase`.
2. Close every gate path in the §7.2 table, including the deep-link deactivate, Reset All Data, and the D8 cooldown.
3. Show the `blockingWarning` banner in `StatusCard`.
4. Make the contacts screens' copy honest (§6.3).

### Phase 5: Feature flags and cleanup (PR 5)
1. Add `FeatureFlags` and gate Integrations, Siri, Delayed messages, and Schedules (§8).
2. Delete the orphans: `HomeView`, `DurationOption`, unused helpers.
3. Optional: real schedules with `DeviceActivity`, and the extra sobriety test types.

### Phase 6: Tests, CI, and docs (PR 6)
1. Unit tests:
   - `SobrietyTestService`: answers validate; the typing test expects the reversed phrase.
   - `ProtectionSession` math: `timeRemaining` and `isActive`.
   - `DeepLinkService` parsing.
   - `PersistenceService` round-trip and migration.
   - `ProtectionManager` with a `MockBlockingController`: activate calls `startBlocking`; deactivate calls `stopBlocking`; expiry clears; reconcile reapplies.
2. A UI smoke test (§10.3).
3. GitHub Actions on `macos-14`: `brew install xcodegen`, then `xcodegen generate`, then `git diff --exit-code`, then `xcodebuild build test` for the Simulator with `CODE_SIGNING_ALLOWED=NO`.
4. Update the README: real feature status, limitations (§6.3), and setup.

### Phase 7: Optional, post-v1
- CallKit Call Directory to block incoming calls from blocked contacts.
- App Intents (Shortcuts and Siri).
- Show `MorningSummaryView` after a session ends.
- Integrations, once a backend exists.

**Rough effort:** Phases 1–2 take about 1 session. Phases 3–4 take about 1–2 sessions plus owner device testing. Phases 5–6 take about 1 session.

---

## 10. Build and verification

### 10.1 Toolchain
- macOS 14+ with **Xcode 15.4 or 16.x**. The iOS 17 SDK or later is required.
- `brew install xcodegen` (2.38+).

### 10.2 Build order and commands

```bash
xcodegen generate
xcodebuild -project BoozeBlocker.xcodeproj -scheme BoozeBlocker \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | xcpretty   # or grep "error:"
```

Xcode builds the extensions first, because they are dependencies that get embedded, and then the app. Errors to expect, in roughly this order:
1. **Widget target:** E10 (`ProtectionSession` missing) and E11 (no `@main`), fixed in Phase 1.
2. **App target, Swift type check:** E1, E2, E8, E9, E12, plus E3–E7 if the target were left at 16.0.
3. **Linker or processing:** "Multiple commands produce Info.plist" if `Resources/Info.plist` is also picked up as a resource. Fix it by excluding the plist from `sources` resources. XcodeGen normally handles `info.path` correctly **(verify)**.
4. **Phase 3:**
   - Simulator builds with `CODE_SIGNING_ALLOWED=NO` should compile with the Family Controls entitlements present.
   - Device builds fail with "Provisioning profile doesn't include the com.apple.developer.family-controls entitlement" until the capability is enabled on all four App IDs.
   - Archive and export fail until Distribution is approved.

### 10.3 Checking the app launches through onboarding to the main tabs

**Manual check in the Simulator:**
1. `xcrun simctl boot "iPhone 15"`
2. Install the built `.app`: `xcrun simctl install booted <DerivedData>/Build/Products/Debug-iphonesimulator/BoozeBlocker.app`
3. `xcrun simctl launch booted com.CHANGEME.boozeblocker`
4. You should see **OnboardingView** page 1, "Welcome to Booze Blocker". Tap **Next** 4 times, then **Get Started**.
5. You should see **PermissionsView**, "Permissions Required". Tap **Skip for Now**.
6. You should see **ContentView** with the tabs **Home / Settings / History**. Home shows "NOT PROTECTED".
7. Tap **Activate Protection**, then **4 hours**. The status should be "PROTECTED" with the time remaining. Then tap **Stop Protection** → **Take Sobriety Test**, answer, and check that it returns to not protected and that a session appears in History.
8. Deep links:
   - `xcrun simctl openurl booted "boozeblocker://settings"` should switch to the Settings tab.
   - `xcrun simctl openurl booted "boozeblocker://deactivate"` should show the sobriety test while active.
9. To reset: `xcrun simctl uninstall booted com.CHANGEME.boozeblocker`, or launch with `-resetState YES`. Implement this in `BoozeBlockerApp.init` so it wipes `AppGroup.defaults` and the `@AppStorage` flags in DEBUG builds.

**Automated check, `BoozeBlockerUITests/OnboardingSmokeTests.swift`:**

```swift
func testOnboardingReachesTabs() {
    let app = XCUIApplication(); app.launchArguments = ["-resetState", "YES"]; app.launch()
    XCTAssertTrue(app.staticTexts["Welcome to Booze Blocker"].waitForExistence(timeout: 5))
    for _ in 0..<4 { app.buttons["Next"].tap() }
    app.buttons["Get Started"].tap()
    XCTAssertTrue(app.staticTexts["Permissions Required"].waitForExistence(timeout: 3))
    app.buttons["Skip for Now"].tap()
    XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    XCTAssertTrue(app.tabBars.buttons["History"].exists)
}
```

### 10.4 Device validation for Screen Time (owner, Phase 3/4)
1. Run on an iPhone with iOS 17+, signed with a team where Family Controls is enabled.
2. Permissions → Screen Time → **Allow**. The system sheet appears and asks for Face ID or the passcode.
3. Settings → Blocked Apps → pick Instagram and Messages. Check that the `Label(token)` rows show their icons.
4. Activate for 1 hour. Open Instagram: the custom shield should show "Instagram is blocked" with the two buttons.
5. Tap "I need access". A notification should arrive; tapping it should open the sobriety test.
6. Pass the test. Instagram should open normally.
7. **Expiry while the app is killed:** activate for the shortest allowed duration (≥ 15 min), force-quit BoozeBlocker, and wait. Instagram should be unshielded after the end time, and History should show "Timer Expired" on the next launch.
8. Try to delete BoozeBlocker while protection is active. It should be blocked (`denyAppRemoval`).
9. Revoke access in Settings → Screen Time. On the next launch, the app should show the "Screen Time access revoked" banner.

---

## 11. Risks and open questions

| Risk / question | Impact | Mitigation |
|-----------------|--------|------------|
| Family Controls **Distribution** approval is delayed or denied | Can't use TestFlight or the App Store with blocking | Apply early (D5). Explain the self-control use case clearly. Development builds still work on the owner's devices. |
| Screen Time APIs are buggy or flaky on some iOS versions (known issues with picker crashes and the shield extension not loading) **(verify)** | Inconsistent blocking | Test on the latest iOS 17 and 18. Keep the extensions small. Add a "Re-apply shields" debug button. |
| The user can revoke Screen Time access, or turn off Screen Time | The blocker can be bypassed | Present it as a speed bump. Detect and log it (§6.3). |
| Expectations about contact blocking | Users feel misled | Honest copy, plus optionally CallKit for incoming calls (§6.3). |
| The 15-minute minimum DeviceActivity interval | Short sessions don't auto-end in the background | Set the minimum duration option to 1 hour, and reconcile on launch. |
| The 50-token shield limit | Large selections get silently truncated **(verify)** | Warn in the picker UI. Prefer categories. |
| Can extensions write to the App Group? (ShieldConfiguration extensions are sandboxed more tightly than ShieldAction or Monitor) **(verify)** | Attempt logging | Log only from ShieldAction and the Monitor. Treat the ShieldConfiguration extension as read-only. |
| App Review: Guideline 5.1.1 (data) and the usage of the FamilyControls entitlement | Rejection | Keep all data on the device. Ship `PrivacyInfo.xcprivacy`. Remove unused permission strings (tracking, location). |
| The App Store name "Booze Blocker" and alcohol references | Age rating 17+ is possible | Owner decision. Set the age-rating questionnaire accordingly. |
| No Mac in the current Devin environment (Linux) | Can't compile here | Use a macOS Devin session or GitHub Actions `macos-14` for Phases 1+. |
| Domain `boozeblocker.app` in HelpSupportView, and email `support@boozeblocker.app` | Broken links | The owner confirms or replaces them. |

Open questions for the owner, beyond D1–D12:
1. Should "Until I stop" sessions be allowed? With no end, only the sobriety test ends them. That's fine, but confirm it is intended.
2. Should the sobriety test also be required to *shorten* or *extend* a session (the `EXTEND_SESSION` notification action)?
3. Which test types, and how many attempts, at each difficulty?
4. Should an accountability partner or remote unlock be in scope? It needs a backend; currently out of scope.
5. Is the default difficulty `.medium` and the default duration of 8 hours (`UserSettings.defaultDuration`, which is unused today) the right UX?

---

## 12. Checklist for the follow-up session

1. Read §1 and get answers to D1, D2, D4, and D6 from the owner (other decisions have defaults).
2. Phase 1 (§9) → build is green in the Simulator (§10.2) → UI smoke test passes (§10.3).
3. Phase 2 → the widget shows live status. Notification and deep-link actions work.
4. Phase 3 → compiles with the extensions. The owner validates on a device (§10.4).
5. Phase 4 → every gate path in the §7.2 table is verified.
6. Phases 5–6 → flags, cleanup, tests, CI, README.
