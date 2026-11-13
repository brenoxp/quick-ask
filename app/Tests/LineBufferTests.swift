import Foundation
import Testing

@testable import QuickAsk

@Test func splitsLinesAcrossChunksAndKeepsMultibyte() {
    var buffer = LineBuffer()
    let bytes = Array("{\"a\":\"é\"}\n{\"b\"".utf8)
    #expect(buffer.append(Data(bytes[0..<7])).isEmpty)  // cut inside "é"
    let lines = buffer.append(Data(bytes[7...]))
    #expect(lines.map { String(decoding: $0, as: UTF8.self) } == ["{\"a\":\"é\"}"])
    #expect(buffer.append(Data(":1}\n".utf8)).map { String(decoding: $0, as: UTF8.self) } == ["{\"b\":1}"])
}

@Test func skipsEmptyLines() {
    var buffer = LineBuffer()
    #expect(buffer.append(Data("\n\nx\n".utf8)).count == 1)
}
