import XCTest
@testable import ModelMeterCore

final class ConfigStoreMigrationTests: XCTestCase {
    func testMigrationRemovesClaudeCookieHeaderField() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("config.json")
        let raw = """
        {
          "source": "command",
          "claudeCommand": "/tmp/claude_usage.py",
          "codexCommand": "/tmp/codex_usage.py",
          "claudeCookieHeader": "sessionKey=secret"
        }
        """
        try raw.data(using: .utf8)?.write(to: fileURL)

        let store = ConfigStore(fileURL: fileURL)
        try store.migrateDeprecatedFields()

        let migratedText = try String(contentsOf: fileURL)
        XCTAssertFalse(migratedText.contains("claudeCookieHeader"))

        let config = try store.load()
        XCTAssertEqual(config?.source, "command")
        XCTAssertEqual(config?.claudeCommand, "/tmp/claude_usage.py")
    }
}
