import Foundation

/// One user-defined spelling: whenever the recognizer writes `heard`, Dictate
/// writes `written` instead. This fixes names the model hears correctly but
/// cannot spell, such as a company name that sounds like ordinary words.
struct CustomWord: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var heard: String
    var written: String

    /// A rule with nothing to match or nothing to write is ignored.
    var isUsable: Bool {
        !heard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !written.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// The custom-words window writes this key; the engine reads it when each
/// recording starts, so an edit applies to the very next dictation.
enum CustomWordPreference {
    static let defaultsKey = "DictateCustomWords"

    static func load(from defaults: UserDefaults = .standard) -> [CustomWord] {
        guard let data = defaults.data(forKey: defaultsKey),
              let words = try? JSONDecoder().decode([CustomWord].self, from: data) else {
            return []
        }
        return words
    }

    static func save(_ words: [CustomWord], to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(words) else { return }
        defaults.set(data, forKey: defaultsKey)
    }
}

/// Applies custom words to recognizer output. Matching ignores case, only
/// matches whole words, and treats the gaps between the words of `heard` as
/// optional, so "block swap" also matches "blockswap" and "Block-Swap".
struct CustomWordReplacer: Sendable {
    private struct Rule: @unchecked Sendable {
        let expression: NSRegularExpression
        let template: String
    }

    private let rules: [Rule]

    var isEmpty: Bool { rules.isEmpty }

    init(words: [CustomWord]) {
        // Longest phrase first, so a short rule cannot consume part of the
        // text a longer rule was written for.
        let usable = words.filter(\.isUsable).sorted { $0.heard.count > $1.heard.count }
        rules = usable.compactMap { word in
            let parts = word.heard
                .split(whereSeparator: { $0.isWhitespace || $0 == "-" })
                .map { NSRegularExpression.escapedPattern(for: String($0)) }
            guard !parts.isEmpty else { return nil }
            let pattern = #"(?<![\p{L}\p{N}])"# + parts.joined(separator: #"[\s\-]*"#) + #"(?![\p{L}\p{N}])"#
            guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return nil
            }
            let written = word.written.trimmingCharacters(in: .whitespacesAndNewlines)
            return Rule(expression: expression, template: NSRegularExpression.escapedTemplate(for: written))
        }
    }

    func apply(to text: String) -> String {
        rules.reduce(text) { current, rule in
            rule.expression.stringByReplacingMatches(
                in: current,
                range: NSRange(current.startIndex..., in: current),
                withTemplate: rule.template
            )
        }
    }
}
