import Foundation
import Synchronization

enum ProcessFailure: Error, Equatable, Sendable {
    case launchFailed(String)
    case exited(status: Int32, stderr: String)
    case timedOut
    case cancelled
}

/// Runs one executable to completion. Knows nothing about what it runs.
enum ProcessRunner {
    /// Returns stdout when the process exits with status 0. On timeout or task cancellation the process
    /// gets SIGTERM, then SIGKILL two seconds later if it is still running.
    static func run(_ executable: URL, arguments: [String], timeout: Duration) async throws(ProcessFailure) -> Data {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let exit = AsyncStream.makeStream(of: Int32.self, bufferingPolicy: .bufferingNewest(1))
        process.terminationHandler = { finished in
            exit.continuation.yield(finished.terminationStatus)
            exit.continuation.finish()
        }
        do {
            try process.run()
        } catch {
            throw .launchFailed(error.localizedDescription)
        }

        let stopper = Stopper(process)
        let watchdog = Task {
            try await Task.sleep(for: timeout)
            stopper.stop(because: .timedOut)
        }
        let (status, stdout, stderr) = await withTaskCancellationHandler {
            async let stdout = drain(stdoutPipe.fileHandleForReading)
            async let stderr = drain(stderrPipe.fileHandleForReading)
            var status: Int32 = -1
            for await code in exit.stream { status = code }
            return (status, await stdout, await stderr)
        } onCancel: {
            stopper.stop(because: .cancelled)
        }
        watchdog.cancel()

        if let reason = stopper.reason { throw reason }
        guard status == 0 else {
            throw .exited(status: status, stderr: String(bytes: stderr, encoding: .utf8) ?? "")
        }
        return stdout
    }

    /// Reads until EOF without blocking a cooperative thread, so stdout and stderr drain concurrently.
    private static func drain(_ handle: FileHandle) async -> Data {
        let buffer = DrainBuffer()
        return await withCheckedContinuation { continuation in
            handle.readabilityHandler = { readable in
                let chunk = readable.availableData
                if chunk.isEmpty {
                    readable.readabilityHandler = nil
                    if let data = buffer.finish() { continuation.resume(returning: data) }
                } else {
                    buffer.append(chunk)
                }
            }
        }
    }
}

/// Stops a running process at most once and remembers why, so the caller can report the cause.
private final class Stopper: Sendable {
    private let process: Process
    private let recorded = Mutex<ProcessFailure?>(nil)

    init(_ process: Process) {
        self.process = process
    }

    var reason: ProcessFailure? {
        recorded.withLock { $0 }
    }

    func stop(because reason: ProcessFailure) {
        let isFirstStop = recorded.withLock { recorded in
            guard recorded == nil else { return false }
            recorded = reason
            return true
        }
        guard isFirstStop, process.isRunning else { return }
        let pid = process.processIdentifier
        let process = process
        kill(pid, SIGTERM)
        Task.detached {
            try? await Task.sleep(for: .seconds(2))
            if process.isRunning { kill(pid, SIGKILL) }
        }
    }
}

/// The readability handler can fire again with an empty chunk before it is cleared, so EOF is reported once.
private final class DrainBuffer: Sendable {
    private let state = Mutex((data: Data(), isFinished: false))

    func append(_ chunk: Data) {
        state.withLock { $0.data.append(chunk) }
    }

    func finish() -> Data? {
        state.withLock { state in
            guard !state.isFinished else { return nil }
            state.isFinished = true
            return state.data
        }
    }
}
