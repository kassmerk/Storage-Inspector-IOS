import Foundation

/// Reads the real capacity of the device the app runs on.
enum DeviceStorage {
    static func capacity() -> DeviceCapacity {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]

        guard let values = try? home.resourceValues(forKeys: keys) else {
            return .empty
        }

        let total = Int64(values.volumeTotalCapacity ?? 0)
        let available: Int64
        if let important = values.volumeAvailableCapacityForImportantUsage {
            available = important
        } else {
            available = Int64(values.volumeAvailableCapacity ?? 0)
        }

        return DeviceCapacity(total: total, available: available)
    }
}
