import CoreServices
import Foundation

/// Signals when named files in one directory change. Knows nothing about what the files contain.
enum FileWatcher {
    /// Yields once per burst of changes to any file in `directory` named in `fileNames`. FSEvents coalesces a
    /// burst over `latency`, but delivers the first change after a quiet period immediately. Watching the
    /// directory rather than the files survives a file being deleted and recreated.
    static func changes(in directory: URL, fileNames: Set<String>, latency: Duration) -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let sink = Sink(fileNames: fileNames, continuation: continuation)
            guard let stream = EventStream(watching: directory, latency: latency, sink: sink) else {
                continuation.finish()
                return
            }
            continuation.onTermination = { _ in stream.stop() }
        }
    }
}

/// Receives FSEvents callbacks and forwards the relevant ones.
private final class Sink: Sendable {
    private let fileNames: Set<String>
    private let continuation: AsyncStream<Void>.Continuation

    init(fileNames: Set<String>, continuation: AsyncStream<Void>.Continuation) {
        self.fileNames = fileNames
        self.continuation = continuation
    }

    func received(_ paths: [String]) {
        if paths.contains(where: { fileNames.contains(URL(filePath: $0).lastPathComponent) }) {
            continuation.yield()
        }
    }
}

/// A started FSEvents stream. After `init` returns, the stream is touched only on `queue`, which is what
/// makes sharing this handle safe. The stream retains the sink until it is released.
private struct EventStream: @unchecked Sendable {
    private let reference: FSEventStreamRef
    private let queue = DispatchQueue(label: "com.szymonograbek.Bee.FileWatcher")

    init?(watching directory: URL, latency: Duration, sink: Sink) {
        guard let paths = Self.pathArray(directory.path(percentEncoded: false)) else { return nil }
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(sink).toOpaque(),
            retain: nil,
            release: { info in
                if let info { Unmanaged<Sink>.fromOpaque(info).release() }
            },
            copyDescription: nil
        )
        let created = FSEventStreamCreate(
            nil,
            { _, info, count, paths, _, _ in
                guard let info else { return }
                let cPaths = paths.assumingMemoryBound(to: UnsafePointer<CChar>.self)
                let changed = (0..<count).map { String(cString: cPaths[$0]) }
                Unmanaged<Sink>.fromOpaque(info).takeUnretainedValue().received(changed)
            },
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            Double(latency.components.seconds) + Double(latency.components.attoseconds) / 1e18,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        )
        guard let created else {
            context.release?(context.info)
            return nil
        }
        reference = created
        FSEventStreamSetDispatchQueue(created, queue)
        FSEventStreamStart(created)
    }

    func stop() {
        queue.async { [self] in
            FSEventStreamStop(reference)
            FSEventStreamInvalidate(reference)
            FSEventStreamRelease(reference)
        }
    }

    private static func pathArray(_ path: String) -> CFArray? {
        guard let string = CFStringCreateWithFileSystemRepresentation(nil, path) else { return nil }
        var values: [UnsafeRawPointer?] = [UnsafeRawPointer(Unmanaged.passUnretained(string).toOpaque())]
        return withUnsafePointer(to: kCFTypeArrayCallBacks) { CFArrayCreate(nil, &values, 1, $0) }
    }
}
