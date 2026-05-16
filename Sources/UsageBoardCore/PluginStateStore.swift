@preconcurrency import Foundation

public struct PluginStateStore: Sendable {
    public var directoryURL: URL

    public init(directoryURL: URL = ConfigStore.statesDirectoryURL()) {
        self.directoryURL = directoryURL
    }

    public func load(stateID: String) -> PluginCachedState? {
        let fileURL = directoryURL.appendingPathComponent("\(stateID).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? UsageBoardJSON.decoder().decode(PluginCachedState.self, from: data)
    }

    public func save(stateID: String, state: PluginCachedState) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent("\(stateID).json")
        let data = try UsageBoardJSON.encoder().encode(state)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func needsRefresh(stateID: String, intervalSeconds: Int) -> Bool {
        guard let cached = load(stateID: stateID) else { return true }
        let interval = max(intervalSeconds, 5)
        return Date().timeIntervalSince(cached.updatedAt) > Double(interval)
    }
}
