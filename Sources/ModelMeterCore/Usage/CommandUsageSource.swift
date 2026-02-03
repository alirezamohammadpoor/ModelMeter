import Foundation

public enum CommandUsageError: LocalizedError {
    case missingCommand
    case processFailed(String)
    case invalidOutput

    public var errorDescription: String? {
        switch self {
        case .missingCommand:
            return "No providerCommand configured."
        case let .processFailed(message):
            return message
        case .invalidOutput:
            return "Command output was not valid usage JSON."
        }
    }
}

public struct CommandUsageSource: Sendable {
    public init() {}

    public func fetch(config: ModelMeterConfig, provider: UsageProvider) throws -> UsageSnapshot {
        let command = resolveCommand(config: config, provider: provider)
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CommandUsageError.missingCommand
        }

        let output = try runCommand(command: command, args: config.providerArgs)
        guard let data = output.data(using: .utf8) else {
            throw CommandUsageError.invalidOutput
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(CommandUsagePayload.self, from: data)
        return try payload.toSnapshot()
    }

    private func runCommand(command: String, args: [String]?) throws -> String {
        let process = Process()
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let isAbsolutePath = trimmed.hasPrefix("/")
        let fileManager = FileManager.default

        if isAbsolutePath && fileManager.fileExists(atPath: trimmed) {
            process.executableURL = URL(fileURLWithPath: trimmed)
            process.arguments = args ?? []
        } else if let args, !args.isEmpty {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [trimmed] + args
        } else {
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-lc", trimmed]
        }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        let outText = String(data: outData, encoding: .utf8) ?? ""
        let errText = String(data: errData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let message = errText.isEmpty ? "Command failed with exit code \(process.terminationStatus)." : errText
            throw CommandUsageError.processFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return outText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private func resolveCommand(config: ModelMeterConfig, provider: UsageProvider) -> String {
    switch provider {
    case .claude:
        return config.claudeCommand ?? config.providerCommand ?? ""
    case .codex:
        return config.codexCommand ?? config.providerCommand ?? ""
    }
}

private struct CommandUsagePayload: Decodable {
    struct Line: Decodable {
        let type: String
        let label: String?
        let value: Double?
        let max: Double?
        let unit: String?
        let subtitle: String?
    }

    let sessionPercent: Double?
    let weeklyPercent: Double?
    let sessionResetAt: Date?
    let weeklyResetAt: Date?
    let updatedAt: Date?
    let lines: [Line]?

    func toSnapshot() throws -> UsageSnapshot {
        let now = Date()

        let sessionValue: Double?
        let weeklyValue: Double?

        if let sessionPercent, let weeklyPercent {
            sessionValue = sessionPercent
            weeklyValue = weeklyPercent
        } else {
            let progressLines = (lines ?? []).filter { line in
                line.type == "progress" && (line.unit == nil || line.unit == "percent")
            }
            let sessionLine = progressLines.first { line in
                (line.label ?? "").lowercased() == "session"
            }
            let weeklyLine = progressLines.first { line in
                (line.label ?? "").lowercased() == "weekly"
            }
            sessionValue = sessionLine?.value ?? progressLines.first?.value
            weeklyValue = weeklyLine?.value ?? progressLines.dropFirst().first?.value
        }

        guard let sessionValue, let weeklyValue else {
            throw CommandUsageError.invalidOutput
        }

        let sessionReset = sessionResetAt ?? ResetSchedule.nextMidnight(after: now)
        let weeklyReset = weeklyResetAt ?? ResetSchedule.nextWeekStart(after: now)

        return UsageSnapshot(
            sessionUsed: sessionValue,
            weeklyUsed: weeklyValue,
            sessionLimit: 100,
            weeklyLimit: 100,
            sessionUsedPercent: sessionValue,
            weeklyUsedPercent: weeklyValue,
            sessionResetAt: sessionReset,
            weeklyResetAt: weeklyReset,
            updatedAt: updatedAt ?? now,
            sourcePath: URL(fileURLWithPath: "/dev/stdout"),
            sourceMtime: now
        )
    }
}
