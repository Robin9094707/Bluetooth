import Foundation
import Combine

final class DebugLogger: ObservableObject {
    static let shared = DebugLogger()
    @Published private(set) var lines: [String] = []
    private let formatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f
    }()

    func log(_ message: String) {
        let line = "[\(formatter.string(from: Date()))] \(message)"
        lines.append(line)
        if lines.count > 600 { lines.removeFirst(lines.count - 600) }
    }

    func clear() { lines.removeAll() }
    var exportText: String { lines.joined(separator: "\n") }
}
