import Foundation
import Testing
@testable import QuickAsk

@Test func textDelta() {
    let line = #"{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":"Olá"}}}"#
    #expect(StreamProtocol.parse(line: Data(line.utf8)) == .textDelta("Olá"))
}

@Test func resultCarriesCumulativeCostAndTurnUsage() {
    let line = #"{"type":"result","subtype":"success","is_error":false,"total_cost_usd":0.0025396,"usage":{"input_tokens":2,"cache_creation_input_tokens":802,"cache_read_input_tokens":10,"output_tokens":6},"modelUsage":{"claude-haiku-5-5":{},"claude-sonnet-5-5":{}}}"#
    guard case .turnResult(let r) = StreamProtocol.parse(line: Data(line.utf8)) else { Issue.record(); return }
    #expect(r.cumulativeCostUsd == 0.0025396)
    #expect(r.usage == TurnUsage(inputTokens: 2, outputTokens: 6, cacheReadTokens: 10, cacheWriteTokens: 802))
    #expect(Set(r.models) == ["claude-haiku-5-5", "claude-sonnet-5-5"])
    #expect(!r.isError)
}

@Test func errorResult() {
    let line = #"{"type":"result","subtype":"error_during_execution","is_error":true,"result":"boom","total_cost_usd":0}"#
    guard case .turnResult(let r) = StreamProtocol.parse(line: Data(line.utf8)) else { Issue.record(); return }
    #expect(r.isError && r.errorText == "boom")
}

@Test func errorResultFallsBackToSubtype() {
    let line = #"{"type":"result","subtype":"error_max_turns","is_error":true}"#
    guard case .turnResult(let r) = StreamProtocol.parse(line: Data(line.utf8)) else { Issue.record(); return }
    #expect(r.errorText == "error_max_turns")
    #expect(r.usage == TurnUsage(inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, cacheWriteTokens: 0))
}

@Test func ignoresOtherEventsAndGarbage() {
    #expect(StreamProtocol.parse(line: Data(#"{"type":"system","subtype":"init"}"#.utf8)) == nil)
    #expect(StreamProtocol.parse(line: Data("not json".utf8)) == nil)
}

@Test func userMessageWithImage() throws {
    let data = StreamProtocol.userMessage(text: "what is this", images: [ImagePayload(mediaType: "image/png", base64Data: "AAA=")])
    #expect(data.last == UInt8(ascii: "\n"))
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    let content = (json["message"] as! [String: Any])["content"] as! [[String: Any]]
    #expect(content.count == 2)
    #expect(content[0]["type"] as? String == "image")
    #expect((content[0]["source"] as! [String: Any])["media_type"] as? String == "image/png")
    #expect(content[1]["text"] as? String == "what is this")
}

@Test func userMessageTextOnlyIsPlainString() throws {
    let json = try JSONSerialization.jsonObject(with: StreamProtocol.userMessage(text: "hi", images: [])) as! [String: Any]
    #expect((json["message"] as! [String: Any])["content"] as? String == "hi")
}
