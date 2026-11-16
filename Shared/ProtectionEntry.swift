import Foundation

struct ProtectionEntry {
    let date: Date
    let isProtected: Bool
    let timeRemaining: TimeInterval?
    let blockedAttempts: Int

    static func entries(for session: ProtectionSession?, now: Date) -> [ProtectionEntry] {
        let attempts = session?.blockedAttempts.count ?? 0
        guard let session = session, session.isActive else {
            return [ProtectionEntry(date: now, isProtected: false, timeRemaining: nil, blockedAttempts: attempts)]
        }
        guard let end = session.scheduledEndTime else {
            return [ProtectionEntry(date: now, isProtected: true, timeRemaining: nil, blockedAttempts: attempts)]
        }
        guard end > now else {
            return [ProtectionEntry(date: now, isProtected: false, timeRemaining: nil, blockedAttempts: attempts)]
        }
        var entries: [ProtectionEntry] = []
        var date = now
        while date < end {
            entries.append(ProtectionEntry(date: date, isProtected: true, timeRemaining: end.timeIntervalSince(date), blockedAttempts: attempts))
            date = date.addingTimeInterval(60)
        }
        entries.append(ProtectionEntry(date: end, isProtected: false, timeRemaining: nil, blockedAttempts: attempts))
        return entries
    }
}
