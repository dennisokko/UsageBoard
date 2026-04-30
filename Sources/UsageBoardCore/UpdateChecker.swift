@preconcurrency import Foundation

public struct UpdateInfo: Decodable, Equatable, Sendable {
    public var latestVersion: String
    public var downloadURL: String
    public var updatedAt: Date?
    public var notes: String?

    public init(latestVersion: String, downloadURL: String, updatedAt: Date? = nil, notes: String? = nil) {
        self.latestVersion = latestVersion
        self.downloadURL = downloadURL
        self.updatedAt = updatedAt
        self.notes = notes
    }
}

public struct UpdateCheckResult: Equatable, Sendable {
    public var info: UpdateInfo
    public var hasUpdate: Bool
}

public struct UpdateDownloader: Sendable {
    public init() {}

    public func download(from url: URL) async throws -> URL {
        let (tempURL, _) = try await URLSession.shared.download(from: url)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let extractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("usageboard-update-\(UUID().uuidString)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", tempURL.path, extractDir.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UpdateError.extractionFailed
        }

        let appURLs = try FileManager.default.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "app" }
        guard let appURL = appURLs.first else {
            throw UpdateError.extractionFailed
        }
        return appURL
    }
}

public enum UpdateError: Error, LocalizedError {
    case extractionFailed

    public var errorDescription: String? {
        switch self {
        case .extractionFailed: return "更新包解压失败"
        }
    }
}

public struct UpdateChecker: Sendable {
    public init() {}

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    public func check(currentVersion: String, url: URL) async throws -> UpdateCheckResult {
        let (data, _) = try await Self.session.data(from: url)
        let info = try UsageBoardJSON.decoder().decode(UpdateInfo.self, from: data)
        return UpdateCheckResult(info: info, hasUpdate: Self.isVersion(info.latestVersion, newerThan: currentVersion))
    }

    public static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let left = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let right = current.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(left.count, right.count)

        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l > r }
        }

        return false
    }
}
