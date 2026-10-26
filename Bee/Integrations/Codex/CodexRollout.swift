import Foundation

/// What Bee reads from a Codex rollout, the JSON Lines file Codex appends every session event to.
/// Pure Foundation so the hostless test bundle can compile it.
enum CodexRollout {
    /// From the `session_meta` record on the first line.
    struct Meta: Equatable, Sendable {
        /// The app that started the session, e.g. `codex_cli_rs` or `T3 Code`.
        let originator: String?
        let cwd: String
    }

    static func meta(firstLine: Data) throws -> Meta {
        let line = try JSONDecoder().decode(Line.self, from: firstLine)
        guard line.type == "session_meta", let cwd = line.payload?.cwd else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "No session_meta record"))
        }
        return Meta(originator: line.payload?.originator, cwd: cwd)
    }

    enum Turn: Equatable, Sendable {
        case inProgress
        case finished
    }

    /// The state of the last turn in `text`, or `nil` when `text` holds no turn boundary. `text` may start
    /// mid-line, so a tail of the file is enough when it reaches back to the latest boundary.
    static func latestTurn(in text: Data) -> Turn? {
        let decoder = JSONDecoder()
        for line in text.split(separator: UInt8(ascii: "\n")).reversed() {
            guard turnMarkers.contains(where: { line.contains($0) }),
                  let event = try? decoder.decode(Line.self, from: line),
                  event.type == "event_msg"
            else { continue }
            switch event.payload?.type {
            case "task_started": return .inProgress
            case "task_complete", "turn_aborted": return .finished
            default: continue
            }
        }
        return nil
    }

    /// Cheap prefilter so only candidate lines get decoded.
    private static let turnMarkers = ["task_started", "task_complete", "turn_aborted"].map { Data($0.utf8) }

    private struct Line: Decodable {
        let type: String
        let payload: Payload?
    }

    private struct Payload: Decodable {
        let type: String?
        let originator: String?
        let cwd: String?
    }
}
