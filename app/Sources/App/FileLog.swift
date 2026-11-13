import Foundation

/// Appends timestamped lines to `~/Library/Logs/quick-ask.log`; test runs write to `quick-ask-tests.log`
/// instead, so failures the tests provoke on purpose never show up in the app's log.
enum FileLog {
    private static let queue = DispatchQueue(label: "io.binarygap.quick-ask.filelog")
    private static let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Logs/\(fileName(environment: ProcessInfo.processInfo.environment))")

    /// Xcode sets `XCTestConfigurationFilePath` in the test host process (Swift Testing runs included).
    static func fileName(environment: [String: String]) -> String {
        environment["XCTestConfigurationFilePath"] == nil ? "quick-ask.log" : "quick-ask-tests.log"
    }

    static func info(_ message: String) { write(level: "INFO", message: message) }
    static func warn(_ message: String) { write(level: "WARN", message: message) }
    static func error(_ message: String) { write(level: "ERROR", message: message) }

    /// One log line: ISO 8601 UTC timestamp, level, message, trailing newline.
    static func line(level: String, message: String, date: Date) -> String {
        let timestamp = date.formatted(.iso8601)
        return "\(timestamp) \(level) \(message)\n"
    }

    private static func write(level: String, message: String) {
        let text = line(level: level, message: message, date: Date())
        queue.async {
            let url = fileURL
            guard let data = text.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url)
            }
        }
    }
}
