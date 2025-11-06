//
//  HTMLParser.swift
//  SwiftShelf
//
//  Created by Claude on 11/6/25.
//

import Foundation

class HTMLParser {
    /// Convert HTML to plain text, preserving basic formatting
    static func htmlToPlainText(_ html: String) -> String {
        var text = html

        // Remove script and style tags with their content
        text = text.replacingOccurrences(
            of: "<script[^>]*>[\\s\\S]*?</script>",
            with: "",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "<style[^>]*>[\\s\\S]*?</style>",
            with: "",
            options: .regularExpression
        )

        // Convert common block elements to line breaks
        text = text.replacingOccurrences(
            of: "</p>",
            with: "\n\n",
            options: .caseInsensitive
        )
        text = text.replacingOccurrences(
            of: "</div>",
            with: "\n",
            options: .caseInsensitive
        )
        text = text.replacingOccurrences(
            of: "<br[^>]*>",
            with: "\n",
            options: [.caseInsensitive, .regularExpression]
        )
        text = text.replacingOccurrences(
            of: "</h[1-6]>",
            with: "\n\n",
            options: [.caseInsensitive, .regularExpression]
        )

        // Remove all remaining HTML tags
        text = text.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )

        // Decode HTML entities
        text = decodeHTMLEntities(text)

        // Clean up excessive whitespace
        text = text.replacingOccurrences(
            of: "[ \\t]+",
            with: " ",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "\n[ \\t]+",
            with: "\n",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "[ \\t]+\n",
            with: "\n",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeHTMLEntities(_ text: String) -> String {
        var result = text

        // Common HTML entities
        let entities: [String: String] = [
            "&quot;": "\"",
            "&apos;": "'",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&nbsp;": " ",
            "&mdash;": "—",
            "&ndash;": "–",
            "&lsquo;": "'",
            "&rsquo;": "'",
            "&ldquo;": "\u{201C}",
            "&rdquo;": "\u{201D}",
            "&hellip;": "…"
        ]

        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        // Decode numeric entities (&#123;)
        let numericPattern = "&#([0-9]+);"
        if let regex = try? NSRegularExpression(pattern: numericPattern) {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: nsRange)

            for match in matches.reversed() {
                if let matchRange = Range(match.range, in: result),
                   match.numberOfRanges >= 2,
                   let numberRange = Range(match.range(at: 1), in: result) {
                    let numberString = String(result[numberRange])
                    if let number = Int(numberString),
                       let scalar = UnicodeScalar(number) {
                        result.replaceSubrange(matchRange, with: String(Character(scalar)))
                    }
                }
            }
        }

        return result
    }
}
