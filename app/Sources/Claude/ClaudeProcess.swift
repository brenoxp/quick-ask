import Foundation

/// One conversation's connection to Claude: NDJSON user lines in, parsed events out.
@MainActor protocol ClaudeSession: AnyObject {
    var isRunning: Bool { get }
    func start() throws
    func send(_ line: Data) throws
    func stop()
}

enum ClaudeProcessError: LocalizedError {
    case notRunning

    var errorDescription: String? {
        switch self {
        case .notRunning: "The claude process is not running."
        }
    }
}

/// A long-lived `claude -p` child speaking stream-json over stdin/stdout.
///
/// Every callback reaches the main actor through `DispatchQueue.main`, one FIFO path, so text deltas
/// arrive in order and the last `result` event arrives before `onExit`. `onExit` fires once per run,
/// after both the process exit and stdout EOF, and never for a run ended by `stop()`.
@MainActor final class ClaudeProcess: ClaudeSession {
    private let configuration: ClaudeLaunchConfiguration
    private let onEvent: @MainActor (ClaudeEvent) -> Void
    private let onExit: @MainActor (Int32) -> Void

    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    private var stderrHandle: FileHandle?
    /// Identifies the current run; callbacks carrying an older value belong to a stopped or replaced process.
    private var runID = 0
    private var stdoutClosed = false
    private var exitStatus: Int32?

    private static var ignoresSIGPIPE = false

    init(
        configuration: ClaudeLaunchConfiguration,
        onEvent: @escaping @MainActor (ClaudeEvent) -> Void,
        onExit: @escaping @MainActor (Int32) -> Void
    ) {
        self.configuration = configuration
        self.onEvent = onEvent
        self.onExit = onExit
    }

    var isRunning: Bool { process?.isRunning ?? false }

    /// Spawns the child. Does nothing while a child is already running.
    func start() throws {
        if isRunning { return }
        Self.ignoreSIGPIPE()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: configuration.executablePath)
        process.arguments = configuration.arguments
        process.environment = configuration.environment(base: ProcessInfo.processInfo.environment)
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        runID += 1
        stdoutClosed = false
        exitStatus = nil
        Self.attachHandlers(
            owner: self,
            runID: runID,
            process: process,
            stdout: stdoutPipe.fileHandleForReading,
            stderr: stderrPipe.fileHandleForReading
        )

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            process.terminationHandler = nil
            FileLog.error("could not start claude at \(configuration.executablePath): \(error.localizedDescription)")
            throw error
        }

        self.process = process
        stdinHandle = stdinPipe.fileHandleForWriting
        stdoutHandle = stdoutPipe.fileHandleForReading
        stderrHandle = stderrPipe.fileHandleForReading
        FileLog.info("started claude (model \(configuration.model), pid \(process.processIdentifier))")
    }

    /// Writes one NDJSON line (already ending in a newline) to the child's stdin.
    /// A dead child makes this throw EPIPE, since the app ignores SIGPIPE.
    func send(_ line: Data) throws {
        guard let stdinHandle, isRunning else { throw ClaudeProcessError.notRunning }
        try stdinHandle.write(contentsOf: line)
    }

    /// Detaches every callback, then terminates the child. Its remaining output and exit are ignored.
    func stop() {
        runID += 1
        stdoutHandle?.readabilityHandler = nil
        stderrHandle?.readabilityHandler = nil
        process?.terminationHandler = nil
        if let process, process.isRunning {
            process.terminate()
            FileLog.info("stopped claude (pid \(process.processIdentifier))")
        }
        try? stdinHandle?.close()
        clearRun()
    }

    // MARK: - Main-actor callbacks

    private func deliver(_ events: [ClaudeEvent], runID: Int) {
        guard runID == self.runID else { return }
        for event in events {
            onEvent(event)
            // A callback may stop this process mid-batch.
            guard runID == self.runID else { return }
        }
    }

    private func stdoutDidClose(runID: Int) {
        guard runID == self.runID else { return }
        stdoutClosed = true
        finishIfDone()
    }

    private func processDidExit(status: Int32, runID: Int) {
        guard runID == self.runID else { return }
        exitStatus = status
        finishIfDone()
    }

    private func finishIfDone() {
        guard stdoutClosed, let status = exitStatus else { return }
        FileLog.info("claude exited (code \(status))")
        runID += 1
        try? stdinHandle?.close()
        clearRun()
        onExit(status)
    }

    private func clearRun() {
        process = nil
        stdinHandle = nil
        stdoutHandle = nil
        stderrHandle = nil
        stdoutClosed = false
        exitStatus = nil
    }

    private static func ignoreSIGPIPE() {
        guard !ignoresSIGPIPE else { return }
        signal(SIGPIPE, SIG_IGN)
        ignoresSIGPIPE = true
    }

    // MARK: - Background wiring

    /// Builds the pipe and termination handlers outside the main actor, since they run on background threads.
    private nonisolated static func attachHandlers(
        owner: ClaudeProcess,
        runID: Int,
        process: Process,
        stdout: FileHandle,
        stderr: FileHandle
    ) {
        PipeLineReader(label: "io.binarygap.quick-ask.claude-stdout").attach(
            to: stdout,
            onLines: { [weak owner] lines in
                guard let owner else { return }
                let events = lines.compactMap { StreamProtocol.parse(line: $0) }
                guard !events.isEmpty else { return }
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { owner.deliver(events, runID: runID) }
                }
            },
            onClose: { [weak owner] in
                guard let owner else { return }
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { owner.stdoutDidClose(runID: runID) }
                }
            }
        )

        PipeLineReader(label: "io.binarygap.quick-ask.claude-stderr").attach(
            to: stderr,
            onLines: { lines in
                for line in lines {
                    FileLog.warn("claude stderr: \(String(decoding: line.prefix(500), as: UTF8.self))")
                }
            },
            onClose: {}
        )

        process.terminationHandler = { [weak owner] process in
            guard let owner else { return }
            let status = process.terminationStatus
            DispatchQueue.main.async {
                MainActor.assumeIsolated { owner.processDidExit(status: status, runID: runID) }
            }
        }
    }
}

/// Reads one pipe and hands complete lines to `onLines` in order, on a private serial queue.
/// `onClose` runs on the same queue after the last line.
private final class PipeLineReader: @unchecked Sendable {
    private let queue: DispatchQueue
    /// Touched only on `queue`.
    private var buffer = LineBuffer()

    init(label: String) {
        queue = DispatchQueue(label: label)
    }

    func attach(
        to handle: FileHandle,
        onLines: @escaping @Sendable ([Data]) -> Void,
        onClose: @escaping @Sendable () -> Void
    ) {
        handle.readabilityHandler = { [self] handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                // EOF: an attached handler would keep firing with empty data.
                handle.readabilityHandler = nil
                queue.async { onClose() }
                return
            }
            queue.async {
                let lines = self.buffer.append(chunk)
                if !lines.isEmpty { onLines(lines) }
            }
        }
    }
}
