import Foundation
import ManagedSettings
import DeviceActivity
import CryptoKit

extension ManagedSettingsStore.Name {
    static let protection = Self("protection")
}

extension DeviceActivityName {
    static let protectionSession = Self("protectionSession")
}

extension SharedStore {
    static func tokenID<T: Encodable>(_ token: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(token) else { return "unknown-token" }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
