public enum Counter {
    public struct State: Codable, Equatable, Sendable {
        public var count: Int
        public var limit: Int

        public init(count: Int = 0, limit: Int = 10) {
            self.count = count
            self.limit = limit
        }
    }

    public enum Action: String, Codable, Sendable {
        case increment
        case decrement
        case reset
    }

    public static func reduce(_ state: inout State, _ action: Action) {
        switch action {
        case .increment:
            state.count = min(state.limit, state.count + 1)
        case .decrement:
            state.count -= 1
        case .reset:
            state.count = 0
        }
    }

    public static func run(_ state: State, _ actions: [Action]) -> State {
        actions.reduce(into: state) { reduce(&$0, $1) }
    }
}
