# Booze Blocker

An iPhone self-control app that adds friction to opening selected apps during a
protection session. Requires iOS 17+, Xcode 15+ with an iOS SDK, and XcodeGen.
It cannot block calls or messages to individual contacts.

## Feature status

- **Implemented:** onboarding, manual/timed sessions, persisted history and insights,
  math/typing sobriety checks, a persisted 10-minute cooldown after three failures,
  notification/deep-link routing, appearance settings, and an App Group-backed widget.
  Early deactivation (including `boozeblocker://deactivate`) requires the sobriety gate.
- **Device-only, awaiting physical-device validation:** Family Controls authorization,
  app/category/web selection and ManagedSettings shields, app-removal prevention
  during protection, and DeviceActivity expiry. Simulator uses
  `NoopBlockingController`: session UI works, but apps are **not blocked**.
- **Deferred/default off:** enabling these flags exposes prototype UI, not
  production-ready integrations.

| Flag (UserDefaults suffix) | Deferred feature |
|---|---|
| `integrations` | Oura, Plaid, Location; services are not instantiated while off |
| `siriShortcuts` | Legacy Siri shortcuts UI |
| `delayedMessages` | Message preview demo; no interception or sending |
| `schedules` | Scheduled Protection settings; saved schedules do not activate protection |
| `extraSobrietyTests` | Standalone math/typing/reaction/balance practice screens |
| `morningSummary` | Summary of a stored protection session (requires history) |

Flags live in `BoozeBlocker/Core/FeatureFlags.swift`. In **DEBUG**, add Xcode
launch arguments such as `-feature.integrations YES` or
`-feature.extraSobrietyTests YES`. Equivalent UserDefaults keys are
`feature.integrations`, etc. Remove the override or set it to `NO` to disable.
Release builds ignore overrides and always keep these flags off.

## Setup and signing

```sh
brew install xcodegen
xcodegen generate
open BoozeBlocker.xcodeproj
```

Select the BoozeBlocker scheme and an iPhone simulator. The generated project is
committed: edit `project.yml`, regenerate, and commit both together.
`xcodegen generate && git diff --exit-code` on a clean checkout must produce no diff.
CI uses the runner's default Xcode and resolves an available iPhone at runtime.

For device signing, use a **paid Apple Developer account**, set your development
team and registered identifiers in `project.yml`, then regenerate. Enable Family
Controls and the shared App Group (`group.com.connorq03.boozeblocker` by default)
for the appropriate targets and provisioning profiles.
TestFlight/App Store distribution requires Apple's **Family Controls distribution
entitlement approval for each of these four bundle IDs**:

- `com.connorq03.boozeblocker` — app
- `com.connorq03.boozeblocker.shieldconfig` — ShieldConfiguration
- `com.connorq03.boozeblocker.shieldaction` — ShieldAction
- `com.connorq03.boozeblocker.activitymonitor` — DeviceActivityMonitor

The widget (`com.connorq03.boozeblocker.widget`) needs App Group provisioning,
not Family Controls. These defaults come from `project.yml`; substitute your
registered prefix consistently. Unsigned builds do not validate entitlements.

## iOS limitations

| Limitation | Current behavior |
|---|---|
| No public API to block outgoing calls/SMS/iMessage to particular contacts | Contact lists are informational/emergency lists, not per-contact blocking. Shield whole Messages/WhatsApp-style apps where supported. Phone/emergency calls remain available. |
| No incoming-call filtering implementation | No Call Directory extension is shipped; CallKit incoming-call filtering is deferred. |
| Apps cannot enable Focus or intercept messages | No Focus-based contact blocking, message interception, or delayed delivery is provided. |
| Users can revoke Screen Time authorization or disable Screen Time | Protection is a speed bump, not tamper-proof enforcement; foreground reconciliation reports unavailable/revoked authorization. |
| DeviceActivity intervals must be at least 15 minutes | Background timed expiry is scheduled only for eligible intervals; shorter sessions rely on foreground reconciliation. Recurring schedules are deferred. |
| Opening a shield does not notify the host app | Attempt counts record shield-button interactions, not every app opening. |
| Temporary access requires an explicit shield/monitoring flow | No “Request 5 Minutes” bypass is shipped; passing the sobriety gate ends protection. |

## Project layout

| Path / target | Role |
|---|---|
| `BoozeBlocker/` | SwiftUI app: App routing, Features UI, Core models/services/extensions, Resources |
| `Shared/` | App Group storage, session/attempt models, ManagedSettings names and token IDs shared across targets |
| `BoozeBlockerWidget/` | Widget extension; shares storage/models, excludes ManagedSettings names |
| `ShieldConfiguration/` | System shield appearance extension |
| `ShieldAction/` | Shield-button logging and notification handoff |
| `DeviceActivityMonitor/` | Clears shields and ends the stored session at monitored expiry |
| `BoozeBlockerTests/`, `BoozeBlockerUITests/` | Unit and UI test targets |

## Running tests

List devices with `xcrun simctl list devices available`, then set an iPhone UDID:

```sh
xcodegen generate
UDID="<available iPhone simulator UDID>"
xcodebuild build -project BoozeBlocker.xcodeproj -scheme BoozeBlocker -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO
xcodebuild test -project BoozeBlocker.xcodeproj -scheme BoozeBlocker -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO
xcodebuild build -project BoozeBlocker.xcodeproj -scheme BoozeBlocker -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

UI tests use `-resetState YES`; direct-to-tabs launches additionally use
`-hasCompletedOnboarding YES -hasGrantedPermissions YES`. This skips onboarding,
not real device authorization. Tests cover session persistence/migration, blocking
controller wiring, sobriety gates, flags, onboarding, and hidden schedule settings.

## Physical-device validation checklist

Not completed by Simulator tests; use a signed iPhone build with Family Controls:

- [ ] Grant Screen Time authorization; verify the real authentication sheet and picker token labels.
- [ ] Select apps such as Instagram and Messages; activate a timed session and verify custom shields.
- [ ] Tap both shield buttons; verify attempt ingestion and the “I need access” notification opens the sobriety test.
- [ ] Verify passing the test removes shields; three failures persist a 10-minute cooldown across relaunch.
- [ ] Verify Stop/deactivate links cannot bypass the test; selection editing and Reset All Data stay locked while active.
- [ ] Activate for at least 15 minutes, force-quit the app, and verify expiry removes shields and records Timer Expired on relaunch.
- [ ] Verify app removal is denied during protection and allowed after it ends.
- [ ] Revoke authorization in system Settings; foreground the app and verify the warning/reconciliation.
- [ ] Check widget state, notification routing, and shield behavior after relaunch/reboot on supported iOS versions.
