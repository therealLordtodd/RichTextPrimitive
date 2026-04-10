import ClipboardPrimitive
import Foundation
import UniformTypeIdentifiers

public struct PasteHandler: Sendable {
    public init() {}

    public func blocks(from plainText: String) -> [Block] {
        let normalized = plainText.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        return lines.map(parseLine)
    }

    public func blocks(from content: ClipboardContent) -> [Block] {
        switch content {
        case let .text(text):
            return blocks(from: text)
        case let .richText(data, type):
            return blocks(fromRichTextData: data, type: type)
        case let .image(data, type):
            return [imageBlock(data: data, type: type)]
        case let .largeImage(thumbnail, originalFileURL, originalUTType):
            let data = (try? Data(contentsOf: originalFileURL)) ?? thumbnail
            return [
                imageBlock(
                    data: data,
                    type: originalUTType,
                    url: originalFileURL,
                    altText: displayName(for: originalFileURL)
                )
            ]
        case let .largeData(preview, originalFileURL, originalUTType):
            if let materialized = materializedContent(
                preview: preview,
                originalFileURL: originalFileURL,
                originalUTType: originalUTType
            ) {
                return blocks(from: materialized)
            }

            return [fileLinkBlock(for: originalFileURL)]
        case let .url(url):
            return [linkBlock(label: url.absoluteString, destination: url)]
        case let .fileURL(urls):
            return urls.map(block(forFileURL:))
        case let .custom(data, type):
            if type.conforms(to: .image) {
                return [imageBlock(data: data, type: type)]
            }

            if type.conforms(to: .html)
                || type.conforms(to: .rtf)
                || type.conforms(to: .rtfd)
                || type.conforms(to: .text)
                || type.conforms(to: .plainText)
                || type.conforms(to: .utf8PlainText) {
                return blocks(fromRichTextData: data, type: type)
            }

            return [
                Block(
                    type: .embed,
                    content: .embed(
                        EmbedContent(
                            kind: type.identifier,
                            metadata: ["byteCount": .int(data.count)]
                        )
                    )
                )
            ]
        }
    }

    public func blocks(fromHTML html: String) -> [Block] {
        let normalized = normalizeHTML(html)
        guard let blockPattern = try? NSRegularExpression(
            pattern: #"<(h[1-6]|p|div|blockquote|pre|li)\b[^>]*>(.*?)</\1\s*>|<hr\b[^>]*\/?>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return blocks(from: htmlText(normalized))
        }

        let fullRange = NSRange(normalized.startIndex..., in: normalized)
        let matches = blockPattern.matches(in: normalized, range: fullRange)
        guard !matches.isEmpty else {
            return blocks(from: htmlText(normalized))
        }

        var parsedBlocks: [Block] = []
        var cursor = normalized.startIndex

        for match in matches {
            guard let matchRange = Range(match.range, in: normalized) else { continue }
            appendParagraphBlocks(fromHTMLFragment: String(normalized[cursor..<matchRange.lowerBound]), to: &parsedBlocks)

            if match.range(at: 1).location == NSNotFound {
                parsedBlocks.append(Block(type: .divider, content: .divider))
            } else if let tagRange = Range(match.range(at: 1), in: normalized),
                      let contentRange = Range(match.range(at: 2), in: normalized),
                      let block = block(
                        tag: String(normalized[tagRange]).lowercased(),
                        htmlContent: String(normalized[contentRange]),
                        fullHTML: normalized,
                        matchLocation: match.range.location
                      ) {
                parsedBlocks.append(block)
            }

            cursor = matchRange.upperBound
        }

        appendParagraphBlocks(fromHTMLFragment: String(normalized[cursor...]), to: &parsedBlocks)

        return parsedBlocks.isEmpty ? blocks(from: htmlText(normalized)) : parsedBlocks
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

    private func block(
        tag: String,
        htmlContent: String,
        fullHTML: String,
        matchLocation: Int
    ) -> Block? {
        switch tag {
        case "h1", "h2", "h3", "h4", "h5", "h6":
            let level = Int(tag.dropFirst()) ?? 1
            return Block(type: .heading, content: .heading(.plain(htmlText(htmlContent)), level: level))
        case "p", "div":
            let text = htmlText(htmlContent)
            guard !text.isEmpty else { return nil }
            return Block(type: .paragraph, content: .text(.plain(text)))
        case "blockquote":
            return Block(type: .blockQuote, content: .blockQuote(.plain(htmlText(htmlContent))))
        case "pre":
            return Block(type: .codeBlock, content: .codeBlock(code: htmlText(htmlContent, preservesLineBreaks: true), language: nil))
        case "li":
            let text = htmlText(htmlContent)
            guard !text.isEmpty else { return nil }
            return Block(
                type: .list,
                content: .list(
                    .plain(text),
                    style: isOrderedListItem(in: fullHTML, beforeUTF16Location: matchLocation) ? .numbered : .bullet,
                    indentLevel: 0
                )
            )
        default:
            return nil
        }
    }

    private func appendParagraphBlocks(
        fromHTMLFragment fragment: String,
        to blocks: inout [Block]
    ) {
        for line in htmlText(fragment).components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            blocks.append(Block(type: .paragraph, content: .text(.plain(trimmed))))
        }
    }

    private func normalizeHTML(_ html: String) -> String {
        html
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private func htmlText(
        _ fragment: String,
        preservesLineBreaks: Bool = false
    ) -> String {
        var text = fragment
            .replacingOccurrences(
                of: #"(?is)<(script|style)\b[^>]*>.*?</\1>"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(
                of: #"(?i)</(p|div|li|h[1-6]|blockquote|pre)>"#,
                with: "\n",
                options: .regularExpression
            )
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)

        text = decodeHTMLEntities(in: text)

        guard !preservesLineBreaks else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return text
            .components(separatedBy: "\n")
            .map { line in
                line
                    .replacingOccurrences(of: #"[ \t\f\v]+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private func decodeHTMLEntities(in text: String) -> String {
        var decoded = text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")

        decoded = decodeNumericHTMLEntities(in: decoded, pattern: #"&#(\d+);"#, radix: 10)
        decoded = decodeNumericHTMLEntities(in: decoded, pattern: #"&#x([0-9a-fA-F]+);"#, radix: 16)
        return decoded
    }

    private func decodeNumericHTMLEntities(
        in text: String,
        pattern: String,
        radix: Int
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        var decoded = text
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed()
        for match in matches {
            guard let matchRange = Range(match.range, in: decoded),
                  let valueRange = Range(match.range(at: 1), in: decoded),
                  let scalarValue = UInt32(decoded[valueRange], radix: radix),
                  let scalar = UnicodeScalar(scalarValue) else { continue }

            decoded.replaceSubrange(matchRange, with: String(Character(scalar)))
        }
        return decoded
    }

    private func isOrderedListItem(
        in html: String,
        beforeUTF16Location location: Int
    ) -> Bool {
        let boundedLocation = min(max(location, 0), html.utf16.count)
        let index = String.Index(utf16Offset: boundedLocation, in: html)

        let prefix = String(html[..<index]).lowercased()
        let lastOrderedList = prefix.range(of: "<ol", options: String.CompareOptions.backwards)?.lowerBound
        let lastUnorderedList = prefix.range(of: "<ul", options: String.CompareOptions.backwards)?.lowerBound

        guard let lastOrderedList else { return false }
        guard let lastUnorderedList else { return true }
        return lastOrderedList > lastUnorderedList
    }

    private func blocks(fromRichTextData data: Data, type: UTType) -> [Block] {
        if type.conforms(to: .html),
           let html = String(data: data, encoding: .utf8) {
            let parsed = blocks(fromHTML: html)
            if !parsed.isEmpty {
                return parsed
            }
        }

        if type.conforms(to: .rtf) || type.conforms(to: .rtfd) {
            let parsed = blocks(fromRTF: data)
            if !parsed.isEmpty {
                return parsed
            }
        }

        if (type.conforms(to: .plainText) || type.conforms(to: .text) || type.conforms(to: .utf8PlainText)),
           let string = String(data: data, encoding: .utf8) {
            return blocks(from: string)
        }

        if let plainText = ClipboardFormatter.richTextToPlainText(data, type: type) {
            return blocks(from: plainText)
        }

        return []
    }

    private func materializedContent(
        preview: Data,
        originalFileURL: URL,
        originalUTType: UTType
    ) -> ClipboardContent? {
        if originalUTType.conforms(to: .plainText) || originalUTType.conforms(to: .utf8PlainText),
           let string = String(data: preview, encoding: .utf8)
                ?? (try? Data(contentsOf: originalFileURL)).flatMap({ String(data: $0, encoding: .utf8) }) {
            return .text(string)
        }

        if originalUTType.conforms(to: .html)
            || originalUTType.conforms(to: .rtf)
            || originalUTType.conforms(to: .rtfd),
           let data = try? Data(contentsOf: originalFileURL) {
            return .richText(data, originalUTType)
        }

        if originalUTType.conforms(to: .image),
           let data = try? Data(contentsOf: originalFileURL) {
            return .image(data, originalUTType)
        }

        return nil
    }

    private func block(forFileURL fileURL: URL) -> Block {
        if let type = UTType(filenameExtension: fileURL.pathExtension),
           type.conforms(to: .image) {
            return imageBlock(
                data: try? Data(contentsOf: fileURL),
                type: type,
                url: fileURL,
                altText: displayName(for: fileURL)
            )
        }

        return fileLinkBlock(for: fileURL)
    }

    private func fileLinkBlock(for fileURL: URL) -> Block {
        linkBlock(label: displayName(for: fileURL), destination: fileURL)
    }

    private func linkBlock(label: String, destination: URL) -> Block {
        Block(
            type: .paragraph,
            content: .text(
                TextContent(
                    runs: [
                        TextRun(
                            text: label,
                            attributes: TextAttributes(link: destination)
                        )
                    ]
                )
            )
        )
    }

    private func imageBlock(
        data: Data?,
        type: UTType,
        url: URL? = nil,
        altText: String? = nil
    ) -> Block {
        Block(
            type: .image,
            content: .image(
                ImageContent(
                    url: url,
                    data: data,
                    altText: altText ?? type.localizedDescription ?? "Image"
                )
            )
        )
    }

    private func displayName(for fileURL: URL) -> String {
        let name = fileURL.deletingPathExtension().lastPathComponent
        return name.isEmpty ? fileURL.lastPathComponent : name
    }
}
