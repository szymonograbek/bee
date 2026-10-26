import CoreServices
import Foundation

/// Signals when files under some directories change. Knows nothing about what the files contain.
enum FileWatcher {
    /// Yields once per burst of changes to any file under `directories`, at any depth, whose URL passes
    /// `isRelevant`. FSEvents coalesces a burst over `latency`, but delivers the first change after a quiet
    /// period immediately. Watching directories rather than files survives a file being deleted and recreated.
    static func changes(
        in directories: [URL],
        where isRelevant: @escaping @Sendable (URL) -> Bool,
        latency: Duration
    ) -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let sink = Sink(isRelevant: isRelevant, continuation: continuation)
            guard let stream = EventStream(watching: directories, latency: latency, sink: sink) else {
                continuation.finish()
                return
            }
            continuation.onTermination = { _ in stream.stop() }
        }
    }
}

/// Receives FSEvents callbacks and forwards the relevant ones.
private final class Sink: Sendable {
    private let isRelevant: @Sendable (URL) -> Bool
    private let continuation: AsyncStream<Void>.Continuation

    init(isRelevant: @escaping @Sendable (URL) -> Bool, continuation: AsyncStream<Void>.Continuation) {
        self.isRelevant = isRelevant
        self.continuation = continuation
    }

    func received(_ paths: [String]) {
        if paths.contains(where: { isRelevant(URL(filePath: $0)) }) {
            continuation.yield()
        }
    }
}

/// A started FSEvents stream. After `init` returns, the stream is touched only on `queue`, which is what
/// makes sharing this handle safe. The stream retains the sink until it is released.
private struct EventStream: @unchecked Sendable {
    private let reference: FSEventStreamRef
    private let queue = DispatchQueue(label: "com.szymonograbek.Bee.FileWatcher")

    init?(watching directories: [URL], latency: Duration, sink: Sink) {
        guard let paths = Self.pathArray(directories.map { $0.path(percentEncoded: false) }) else { return nil }
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

    private static func pathArray(_ paths: [String]) -> CFArray? {
        let strings = paths.compactMap { CFStringCreateWithFileSystemRepresentation(nil, $0) }
        guard !strings.isEmpty, strings.count == paths.count else { return nil }
        var values: [UnsafeRawPointer?] = strings.map { UnsafeRawPointer(Unmanaged.passUnretained($0).toOpaque()) }
        return withExtendedLifetime(strings) {
            withUnsafePointer(to: kCFTypeArrayCallBacks) { CFArrayCreate(nil, &values, values.count, $0) }
        }
    }
}
