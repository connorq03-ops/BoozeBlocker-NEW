import DeviceActivity
import ManagedSettings

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == .protectionSession else { return }
        ManagedSettingsStore(named: .protection).clearAllSettings()
        SharedStore(defaults: AppGroup.defaults).endCurrentSession(reason: .timerExpired)
    }
}
