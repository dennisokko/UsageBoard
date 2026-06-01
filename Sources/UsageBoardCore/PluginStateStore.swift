@preconcurrency import Foundation

private final class StateCache: @unchecked Sendable {
    private var store: [String: PluginCachedState] = [:]
    private let lock = NSLock()

    func get(_ key: String) -> PluginCachedState? {
        lock.lock()
        defer { lock.unlock() }
        return store[key]
    }

    func set(_ key: String, _ value: PluginCachedState) {
        lock.lock()
        defer { lock.unlock() }
        store[key] = value
    }
}

public struct PluginStateStore: Sendable {
    public var directoryURL: URL
    private let cache = StateCache()

    public init(directoryURL: URL = ConfigStore.statesDirectoryURL()) {
        self.directoryURL = directoryURL
    }

    public func load(stateID: String) -> PluginCachedState? {
        if let cached = cache.get(stateID) { return cached }
        let fileURL = directoryURL.appendingPathComponent("\(stateID).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let state = try? UsageBoardJSON.decoder().decode(PluginCachedState.self, from: data) else { return nil }
        cache.set(stateID, state)
        return state
    }

    public func save(stateID: String, state: PluginCachedState) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent("\(stateID).json")
        let data = try UsageBoardJSON.encoder().encode(state)
        try data.write(to: fileURL, options: [.atomic])
        cache.set(stateID, state)
    }

    public func needsRefresh(stateID: String, intervalSeconds: Int) -> Bool {
        guard let cached = load(stateID: stateID) else { return true }
        let interval = max(intervalSeconds, 5)
        return Date().timeIntervalSince(cached.updatedAt) > Double(interval)
    }
}
