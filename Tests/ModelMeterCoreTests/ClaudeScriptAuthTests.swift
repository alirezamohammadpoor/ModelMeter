import XCTest

final class ClaudeScriptAuthTests: XCTestCase {
    func testClaudeScriptsDoNotContainCookieFallback() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let scriptPaths = [
            repoRoot.appendingPathComponent("scripts/claude_usage.py"),
            repoRoot.appendingPathComponent("Sources/ModelMeterApp/Resources/ModelMeterScripts/claude_usage.py")
        ]

        for path in scriptPaths {
            let text = try String(contentsOf: path)
            XCTAssertFalse(text.contains("claudeCookieHeader"), "Cookie config key found in \(path.path)")
            XCTAssertFalse(text.contains("CLAUDE_COOKIE"), "Cookie env fallback found in \(path.path)")
            XCTAssertFalse(text.contains("fetch_web_usage"), "Web cookie fallback function found in \(path.path)")
        }
    }
}
