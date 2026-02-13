import Foundation

public struct ThresholdGate: Sendable {
    private var firedThresholds: Set<Int> = []
    private var lastResetSignature: String?
    private var lastPercent: Int?

    public init() {}

    public mutating func nextThreshold(usedPercent: Int, resetAt: Date?) -> Int? {
        let resetSignature = resetAt.map { String(Int($0.timeIntervalSince1970)) }
        if resetSignature != lastResetSignature {
            firedThresholds.removeAll()
            lastResetSignature = resetSignature
            lastPercent = nil
        }

        if let lastPercent, lastPercent - usedPercent >= 50 {
            firedThresholds.removeAll()
        }
        self.lastPercent = usedPercent

        for threshold in UsageThresholds.all where usedPercent >= threshold {
            if firedThresholds.contains(threshold) { continue }
            firedThresholds.insert(threshold)
            return threshold
        }
        return nil
    }
}
