import Foundation
import Testing
@testable import QuickAsk

struct FileLogTests {
    @Test func lineFormatsTimestampLevelAndMessage() {
        let line = FileLog.line(level: "INFO", message: "hi", date: Date(timeIntervalSince1970: 0))
        #expect(line == "1970-01-01T00:00:00Z INFO hi\n")
    }

    @Test func testRunsLogToTheirOwnFile() {
        #expect(FileLog.fileName(environment: [:]) == "quick-ask.log")
        #expect(FileLog.fileName(environment: ["XCTestConfigurationFilePath": "/x.xctestconfiguration"]) == "quick-ask-tests.log")
    }
}
