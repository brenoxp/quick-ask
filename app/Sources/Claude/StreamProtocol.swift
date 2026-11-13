import Foundation

struct ImagePayload: Equatable, Sendable {
    let mediaType: String
    let base64Data: String
}

struct TurnUsage: Equatable, Codable, Sendable {
    var inputTokens: Int
    var outputTokens: Int
    var cacheReadTokens: Int
    var cacheWriteTokens: Int
}

struct TurnResult: Equatable, Sendable {
    let isError: Bool
    let errorText: String?
    /// Cost accumulated by the whole process so far, not just this turn.
    let cumulativeCostUsd: Double
    /// Token counts for this turn only.
    let usage: TurnUsage
    let models: [String]
}

enum ClaudeEvent: Equatable, Sendable {
    case textDelta(String)
    case turnResult(TurnResult)
}

/// Parses `claude -p` stream-json output lines and encodes user input lines.
enum StreamProtocol {
    /// Returns the event for one NDJSON line, or nil for unknown types and invalid JSON.
    static func parse(line: Data) -> ClaudeEvent? {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let type = object["type"] as? String
        else { return nil }

        switch type {
        case "stream_event":
            guard let event = object["event"] as? [String: Any],
                  event["type"] as? String == "content_block_delta",
                  let delta = event["delta"] as? [String: Any],
                  delta["type"] as? String == "text_delta",
                  let text = delta["text"] as? String
            else { return nil }
            return .textDelta(text)
        case "result":
            return .turnResult(parseResult(object))
        default:
            return nil
        }
    }

    /// One compact JSON line (ending in `\n`) carrying a user message with optional images.
    static func userMessage(text: String, images: [ImagePayload]) -> Data {
        let content: Any
        if images.isEmpty {
            content = text
        } else {
            var blocks: [[String: Any]] = images.map { image in
                [
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": image.mediaType,
                        "data": image.base64Data,
                    ] as [String: Any],
                ]
            }
            blocks.append(["type": "text", "text": text])
            content = blocks
        }
        let line: [String: Any] = [
            "type": "user",
            "message": ["role": "user", "content": content] as [String: Any],
        ]
        var data = (try? JSONSerialization.data(withJSONObject: line, options: [.withoutEscapingSlashes])) ?? Data()
        data.append(UInt8(ascii: "\n"))
        return data
    }

    private static func parseResult(_ object: [String: Any]) -> TurnResult {
        let isError = object["is_error"] as? Bool ?? false
        let errorText: String? = isError
            ? (object["result"] as? String ?? object["subtype"] as? String)
            : nil
        let usage = object["usage"] as? [String: Any] ?? [:]
        let modelUsage = object["modelUsage"] as? [String: Any] ?? [:]
        return TurnResult(
            isError: isError,
            errorText: errorText,
            cumulativeCostUsd: (object["total_cost_usd"] as? NSNumber)?.doubleValue ?? 0,
            usage: TurnUsage(
                inputTokens: intValue(usage["input_tokens"]),
                outputTokens: intValue(usage["output_tokens"]),
                cacheReadTokens: intValue(usage["cache_read_input_tokens"]),
                cacheWriteTokens: intValue(usage["cache_creation_input_tokens"])
            ),
            models: modelUsage.keys.sorted()
        )
    }

    private static func intValue(_ value: Any?) -> Int {
        (value as? NSNumber)?.intValue ?? 0
    }
}
