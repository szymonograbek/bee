import Foundation

/// One sequential polling loop per enabled integration, so reads never overlap. Each loop reads on start, after each
/// change the integration signals, and on a 60-second fallback timer. Triggers that arrive during a read collapse into
/// one follow-up read. Cancellation also kills child processes.
@MainActor
final class IntegrationPollers {
    private var loops: [IntegrationID: Task<Void, Never>] = [:]

    /// Starts a loop for each id in `enabled` that has none, built with `make`, and stops loops for the rest.
    func reconcile(
        enabled: Set<IntegrationID>,
        make: (IntegrationID) -> any Integration,
        report: @escaping @MainActor (IntegrationID, IntegrationReading) -> Void
    ) {
        for id in IntegrationID.allCases {
            if enabled.contains(id), loops[id] == nil {
                loops[id] = Self.poll(id, make(id), report: report)
            } else if !enabled.contains(id), let loop = loops.removeValue(forKey: id) {
                loop.cancel()
            }
        }
    }

    /// The next `reconcile` starts every loop over with an immediate read.
    func stopAll() {
        for loop in loops.values { loop.cancel() }
        loops.removeAll()
    }

    private static func poll(
        _ id: IntegrationID,
        _ integration: any Integration,
        report: @escaping @MainActor (IntegrationID, IntegrationReading) -> Void
    ) -> Task<Void, Never> {
        Task {
            let triggers = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
            triggers.continuation.yield()
            await withDiscardingTaskGroup { group in
                group.addTask {
                    for await _ in integration.changes() { triggers.continuation.yield() }
                }
                group.addTask {
                    while (try? await Task.sleep(for: .seconds(60))) != nil { triggers.continuation.yield() }
                }
                for await _ in triggers.stream {
                    let reading = await integration.read()
                    guard !Task.isCancelled else { break }
                    report(id, reading)
                }
                group.cancelAll()
            }
        }
    }
}
