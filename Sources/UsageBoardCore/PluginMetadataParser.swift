@preconcurrency import Foundation

public enum PluginMetadataParser {
    private static let beginMarker = "UsageBoardPlugin:"
    private static let endMarker = "/UsageBoardPlugin"

    public static func parse(fileURL: URL) -> PluginMetadata? {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return nil
        }
        return parse(text: text)
    }

    public static func parse(text: String) -> PluginMetadata? {
        var isCollecting = false
        var closed = false
        var lines: [String] = []

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false).prefix(80) {
            let line = stripCommentPrefix(String(rawLine))
            if line.trimmingCharacters(in: .whitespaces).hasPrefix(beginMarker) {
                isCollecting = true
                let afterMarker = line.components(separatedBy: beginMarker).dropFirst().joined(separator: beginMarker)
                if !afterMarker.trimmingCharacters(in: .whitespaces).isEmpty {
                    lines.append(afterMarker)
                }
                continue
            }

            if line.trimmingCharacters(in: .whitespaces).hasPrefix(endMarker) {
                closed = true
                break
            }

            if isCollecting {
                lines.append(line)
            }
        }

        guard isCollecting && closed else {
            if isCollecting {
                fputs("UsageBoardPlugin: metadata block not closed with /UsageBoardPlugin\n", stderr)
            }
            return nil
        }

        let jsonText = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !jsonText.isEmpty, let data = jsonText.data(using: .utf8) else {
            return nil
        }

        return try? UsageBoardJSON.decoder().decode(PluginMetadata.self, from: data)
    }

    private static func stripCommentPrefix(_ line: String) -> String {
        let trimmedLeading = line.trimmingCharacters(in: .whitespaces)
        guard trimmedLeading.hasPrefix("#") else {
            return line
        }
        return String(trimmedLeading.dropFirst()).trimmingCharacters(in: .whitespaces)
    }
}
