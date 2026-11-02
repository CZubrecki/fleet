import Foundation

public struct CounterVector: Codable, Sendable {
    public let name: String
    public let start: Counter.State
    public let actions: [Counter.Action]
    public let expected: Int
}

public struct VectorFailure: Codable, Equatable, Sendable {
    public let vector: String
    public let input: String
    public let expected: String
    public let actual: String
}

public struct VectorReport: Codable, Equatable, Sendable {
    public let name: String
    public let checked: Int
    public let failures: [VectorFailure]
    public var passed: Bool { failures.isEmpty }
}

public enum VectorLoader {
    public static let names = ["counter", "floor"]

    public static func run(_ name: String) throws -> VectorReport {
        let vectors = try load(name)
        let failures = vectors.compactMap { vector -> VectorFailure? in
            let actual = Counter.run(vector.start, vector.actions).count
            guard actual != vector.expected else { return nil }
            return VectorFailure(
                vector: vector.name,
                input: vector.actions.map(\.rawValue).joined(separator: ","),
                expected: String(vector.expected),
                actual: String(actual)
            )
        }
        return VectorReport(name: name, checked: vectors.count, failures: failures)
    }

    static func load(_ name: String) throws -> [CounterVector] {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Vectors") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "Vectors/\(name).json"])
        }
        return try JSONDecoder().decode([CounterVector].self, from: Data(contentsOf: url))
    }
}
