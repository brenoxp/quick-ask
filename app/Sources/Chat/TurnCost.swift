import Foundation

// What one answer cost: the dollar amount of the turn, its token usage and the model that served it.
struct TurnCost: Equatable, Codable, Sendable {
    let totalUsd: Double
    let usage: TurnUsage
    let model: String?
}

// Text for the per-turn cost caption and its tooltip.
enum CostFormat {
    private static let separator = " \u{00B7} "

    static func costText(_ usd: Double) -> String {
        if usd >= 0.01 || usd == 0 { return String(format: "$%.2f", usd) }
        if usd < 0.001 { return "<$0.001" }
        return String(format: "$%.3f", usd)
    }

    static func tokenText(_ count: Int) -> String {
        if count >= 1_000_000 { return compact(Double(count) / 1_000_000, suffix: "M") }
        if count >= 1_000 { return compact(Double(count) / 1_000, suffix: "k") }
        return "\(count)"
    }

    static func caption(_ cost: TurnCost, showsTokens: Bool) -> String {
        var parts = [costText(cost.totalUsd)]
        if showsTokens {
            let kinds: [(String, Int)] = [
                ("in", cost.usage.inputTokens),
                ("out", cost.usage.outputTokens),
                ("c_read", cost.usage.cacheReadTokens),
                ("c_write", cost.usage.cacheWriteTokens),
            ]
            for (label, count) in kinds where count > 0 {
                parts.append("\(label) \(tokenText(count))")
            }
        }
        return parts.joined(separator: separator)
    }

    static func help(_ cost: TurnCost) -> String {
        var lines = [String]()
        if let model = cost.model { lines.append("Model: \(model)") }
        lines.append("Cost: \(costText(cost.totalUsd))")
        lines.append("Tokens: " + caption(cost, showsTokens: true).components(separatedBy: separator).dropFirst().joined(separator: separator))
        lines.append("in: tokens sent that were not served from the cache")
        lines.append("out: tokens generated")
        lines.append("c_read: tokens read from the prompt cache")
        lines.append("c_write: tokens written to the prompt cache")
        return lines.joined(separator: "\n")
    }

    // One decimal below 10 units, none from 10 up; a trailing ".0" is dropped (1.0M -> 1M).
    private static func compact(_ value: Double, suffix: String) -> String {
        if value >= 10 { return "\(Int(value.rounded(.down)))\(suffix)" }
        let tenths = (value * 10).rounded(.down) / 10
        if tenths == tenths.rounded() { return "\(Int(tenths))\(suffix)" }
        return String(format: "%.1f%@", tenths, suffix)
    }
}
