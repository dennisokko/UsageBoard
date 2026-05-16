@preconcurrency import Foundation

public enum AppRelauncher {
    public static func relaunchCurrent() throws {
        let currentBundleURL = Bundle.main.bundleURL
        let pid = ProcessInfo.processInfo.processIdentifier
        let escapedCurrent = shellEscaped(currentBundleURL.path)

        let script = """
        #!/bin/bash
        mkdir -p ~/Library/Logs/UsageBoard
        exec 2>>~/Library/Logs/UsageBoard/relauncher.log
        set -e
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        open \(escapedCurrent)
        rm -f "$0"
        """

        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("usageboard-relaunch-\(UUID().uuidString).sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = scriptURL
        try process.run()
    }

    public static func relaunch(replacingWith newBundleURL: URL, cleanupDirectoryURL: URL? = nil) throws {
        let currentBundleURL = Bundle.main.bundleURL
        let pid = ProcessInfo.processInfo.processIdentifier

        let escapedCurrent = shellEscaped(currentBundleURL.path)
        let escapedNew = shellEscaped(newBundleURL.path)
        let cleanupCommand = cleanupDirectoryURL.map { "rm -rf \(shellEscaped($0.path))" } ?? ":"

        let script = """
        #!/bin/bash
        mkdir -p ~/Library/Logs/UsageBoard
        exec 2>>~/Library/Logs/UsageBoard/relauncher.log
        set -e
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        rm -rf \(escapedCurrent)
        mv \(escapedNew) \(escapedCurrent)
        codesign --force --deep --sign - \(escapedCurrent) 2>/dev/null
        open \(escapedCurrent)
        \(cleanupCommand)
        rm -f "$0"
        """

        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("usageboard-update-\(UUID().uuidString).sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = scriptURL
        try process.run()
    }

    private static func shellEscaped(_ path: String) -> String {
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}
