import Foundation

/// Splits a byte stream into newline-terminated lines, holding the unterminated tail until the next chunk.
/// Works on raw bytes, so a chunk boundary inside a multibyte UTF-8 character is harmless.
struct LineBuffer {
    private var pending = Data()

    /// Appends one chunk and returns every complete, non-empty line it finished, without the trailing newline.
    mutating func append(_ chunk: Data) -> [Data] {
        pending.append(chunk)
        var lines: [Data] = []
        var lineStart = pending.startIndex
        while let newline = pending[lineStart...].firstIndex(of: 0x0A) {
            if newline > lineStart {
                lines.append(Data(pending[lineStart..<newline]))
            }
            lineStart = pending.index(after: newline)
        }
        pending = Data(pending[lineStart...])
        return lines
    }
}
