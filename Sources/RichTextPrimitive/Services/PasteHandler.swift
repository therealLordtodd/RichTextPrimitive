import Foundation

public struct PasteHandler: Sendable {
    public init() {}

    public func blocks(from plainText: String) -> [Block] {
        let normalized = plainText.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        return lines.map(parseLine)
    }

    public func blocks(fromHTML html: String) -> [Block] {
        let normalized = html
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")

        let headingPattern = try? NSRegularExpression(pattern: "<h([1-6])>(.*?)</h\\1>", options: [.caseInsensitive, .dotMatchesLineSeparators])
        if let headingPattern {
            let nsRange = NSRange(normalized.startIndex..., in: normalized)
            let matches = headingPattern.matches(in: normalized, range: nsRange)
            if !matches.isEmpty {
                return matches.compactMap { match in
                    guard
                        let levelRange = Range(match.range(at: 1), in: normalized),
                        let contentRange = Range(match.range(at: 2), in: normalized),
                        let level = Int(normalized[levelRange])
                    else {
                        return nil
                    }
                    return Block(type: .heading, content: .heading(.plain(stripTags(String(normalized[contentRange]))), level: level))
                }
            }
        }

        let listPattern = try? NSRegularExpression(pattern: "<li>(.*?)</li>", options: [.caseInsensitive, .dotMatchesLineSeparators])
        if let listPattern {
            let nsRange = NSRange(normalized.startIndex..., in: normalized)
            let matches = listPattern.matches(in: normalized, range: nsRange)
            if !matches.isEmpty {
                return matches.compactMap { match in
                    guard let range = Range(match.range(at: 1), in: normalized) else { return nil }
                    return Block(type: .list, content: .list(.plain(stripTags(String(normalized[range]))), style: .bullet, indentLevel: 0))
                }
            }
        }

        let paragraphText = stripTags(normalized)
        return blocks(from: paragraphText)
    }

    public func blocks(fromRTF data: Data) -> [Block] {
        guard let attributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) else {
            return []
        }

        return blocks(from: attributedString.string)
    }

    private func parseLine(_ line: String) -> Block {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if let heading = parseHeading(from: trimmed) {
            return heading
        }

        if trimmed == "---" || trimmed == "***" {
            return Block(type: .divider, content: .divider)
        }

        if let list = parseListItem(from: trimmed) {
            return list
        }

        return Block(type: .paragraph, content: .text(.plain(line)))
    }

    private func parseHeading(from line: String) -> Block? {
        guard line.hasPrefix("#") else { return nil }
        let marks = line.prefix { $0 == "#" }
        let level = min(max(marks.count, 1), 6)
        let text = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
        return Block(type: .heading, content: .heading(.plain(text), level: level))
    }

    private func parseListItem(from line: String) -> Block? {
        if line.hasPrefix("- ") || line.hasPrefix("* ") {
            return Block(type: .list, content: .list(.plain(String(line.dropFirst(2))), style: .bullet, indentLevel: 0))
        }

        if line.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
            let text = line.replacingOccurrences(of: #"^\d+\.\s"#, with: "", options: .regularExpression)
            return Block(type: .list, content: .list(.plain(text), style: .numbered, indentLevel: 0))
        }

        if line.lowercased().hasPrefix("[ ] ") || line.lowercased().hasPrefix("[x] ") {
            return Block(type: .list, content: .list(.plain(String(line.dropFirst(4))), style: .checklist, indentLevel: 0))
        }

        return nil
    }

    private func stripTags(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
