import Foundation

public struct ModelMeterConfig: Codable, Sendable {
    public var usageFilePath: String?
    public var sessionLimitPercent: Double?
    public var weeklyLimitPercent: Double?
    public var source: String?
    public var providerCommand: String?
    public var providerArgs: [String]?
    public var claudeCommand: String?
    public var codexCommand: String?

    public init(
        usageFilePath: String? = nil,
        sessionLimitPercent: Double? = nil,
        weeklyLimitPercent: Double? = nil,
        source: String? = nil,
        providerCommand: String? = nil,
        providerArgs: [String]? = nil,
        claudeCommand: String? = nil,
        codexCommand: String? = nil
    ) {
        self.usageFilePath = usageFilePath
        self.sessionLimitPercent = sessionLimitPercent
        self.weeklyLimitPercent = weeklyLimitPercent
        self.source = source
        self.providerCommand = providerCommand
        self.providerArgs = providerArgs
        self.claudeCommand = claudeCommand
        self.codexCommand = codexCommand
    }
}

public struct ConfigStore: @unchecked Sendable {
    public let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL = ConfigStore.defaultURL(), fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func load() throws -> ModelMeterConfig? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        return try decoder.decode(ModelMeterConfig.self, from: data)
    }

    public func save(_ config: ModelMeterConfig) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        let dir = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        try data.write(to: fileURL, options: [.atomic])
        try applySecurePermissionsIfNeeded()
    }

    public static func defaultURL(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        homeDirectory
            .appendingPathComponent(".modelmeter", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    public func migrateDeprecatedFields() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        let data = try Data(contentsOf: fileURL)
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        guard json["claudeCookieHeader"] != nil else { return }
        json.removeValue(forKey: "claudeCookieHeader")

        let migratedData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try migratedData.write(to: fileURL, options: [.atomic])
        try applySecurePermissionsIfNeeded()
    }

    private func applySecurePermissionsIfNeeded() throws {
        #if os(macOS) || os(Linux)
        try fileManager.setAttributes([
            .posixPermissions: NSNumber(value: Int16(0o600))
        ], ofItemAtPath: fileURL.path)
        #endif
    }
}
