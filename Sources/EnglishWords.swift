import Foundation

/// Từ điển tiếng Anh có sẵn của macOS, nạp một lần khi cần lần đầu.
enum EnglishWords {
    static let set: Set<String> = {
        guard let text = try? String(contentsOfFile: "/usr/share/dict/words", encoding: .utf8) else { return [] }
        var s = Set<String>()
        for line in text.split(separator: "\n") where line.count >= 4 {
            s.insert(line.lowercased())
        }
        return s
    }()

    static func contains(_ word: String) -> Bool { set.contains(word) }
}
