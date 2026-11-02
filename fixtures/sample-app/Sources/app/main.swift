import Foundation
import SampleCore

struct BehaviourResult: Codable {
    let name: String
    let passed: Bool
    let failure: String?
}

let behaviours: [(name: String, body: () -> String?)] = [
    ("increment-adds-one", {
        let state = Counter.run(Counter.State(), [.increment])
        return state.count == 1 ? nil : "count: expected 1, got \(state.count)"
    }),
    ("reset-returns-to-zero", {
        let state = Counter.run(Counter.State(count: 4), [.reset])
        return state.count == 0 ? nil : "count: expected 0, got \(state.count)"
    })
]

func line<T: Encodable>(_ value: T) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    guard let data = try? encoder.encode(value) else { return }
    print(String(decoding: data, as: UTF8.self))
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(2)
}

let arguments = Array(CommandLine.arguments.dropFirst())
let selection = arguments.count > 1 ? arguments[1] : "all"

switch arguments.first {
case "test":
    let results = behaviours
        .filter { selection == "all" || $0.name == selection }
        .map { behaviour in
            let failure = behaviour.body()
            return BehaviourResult(name: behaviour.name, passed: failure == nil, failure: failure)
        }
    results.forEach(line)
    let failed = results.filter { !$0.passed }.count
    line(["passed": results.count - failed, "failed": failed])
    exit(failed == 0 ? 0 : 1)
case "vectors":
    let names = selection == "all" ? VectorLoader.names : [selection]
    do {
        let reports = try names.map(VectorLoader.run)
        reports.forEach(line)
        exit(reports.allSatisfy(\.passed) ? 0 : 1)
    } catch {
        fail("vectors: \(error)")
    }
default:
    fail("usage: app test [name|all] | app vectors [counter|floor|all]")
}
