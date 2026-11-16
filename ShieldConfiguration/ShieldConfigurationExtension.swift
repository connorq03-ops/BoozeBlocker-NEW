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
