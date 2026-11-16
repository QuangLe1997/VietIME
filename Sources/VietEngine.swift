import Foundation

// Bộ gõ tiếng Việt Telex / VNI — phần xử lý thuần, không phụ thuộc AppKit để test được.

public enum InputMethod: String {
    case telex, vni
}

public enum Tone: Int {
    case none = 0, sac, huyen, hoi, nga, nang

    var combining: String? {
        switch self {
        case .none: return nil
        case .sac: return "\u{0301}"
        case .huyen: return "\u{0300}"
        case .hoi: return "\u{0309}"
        case .nga: return "\u{0303}"
        case .nang: return "\u{0323}"
        }
    }
}

enum Mark {
    case none, hat, breve, horn, stroke

    var combining: String {
        switch self {
        case .hat: return "\u{0302}"
        case .breve: return "\u{0306}"
        case .horn: return "\u{031B}"
        default: return ""
        }
    }
}

struct VChar {
    var base: Character   // luôn là chữ thường (hoặc chữ số / ký tự literal)
    var mark: Mark = .none
    var upper: Bool

    var isVowel: Bool { "aeiouy".contains(base) }

    /// Ký tự hiển thị chưa có dấu thanh, chữ thường.
    var plain: String {
        if base == "d" && mark == .stroke { return "đ" }
        return (String(base) + mark.combining).precomposedStringWithCanonicalMapping
    }
}

public final class VietEngine {
    public var method: InputMethod
    /// true: hoà, thuỷ, khoẻ (kiểu mới). false: hòa, thủy, khỏe (kiểu cũ).
    public var modernTone: Bool = true
    /// Khi từ gõ ra không phải âm tiết tiếng Việt hợp lệ thì trả lại phím gốc (vd. "windows").
    public var autoRestore: Bool = true

    private(set) var chars: [VChar] = []
    private(set) var tone: Tone = .none
    private var raw = ""
    /// Sau khi gõ lặp để huỷ dấu (ss, aaa, ww…) thì các phím sau của từ này giữ nguyên.
    private var literalMode = false
    /// Đã sửa bằng backspace thì không tự khôi phục nữa.
    private var restorable = true

    public init(method: InputMethod = .telex) {
        self.method = method
    }

    public var isEmpty: Bool { chars.isEmpty }
    public var rawKeys: String { raw }

    public func reset() {
        chars = []
        tone = .none
        raw = ""
        literalMode = false
        restorable = true
    }

    // MARK: - Nhận phím

    /// Trả true nếu phím được đưa vào từ đang gõ; false nghĩa là phím không thuộc từ
    /// (space, dấu câu, Enter…) — bên gọi phải commit từ hiện tại rồi để app xử lý phím đó.
    @discardableResult
    public func process(_ key: Character) -> Bool {
        guard key.isASCII else { return false }
        let isLetter = key.isLetter
        let isVNIDigit = method == .vni && key.isNumber && !chars.isEmpty
        guard isLetter || isVNIDigit else { return false }

        raw.append(key)
        let lower = Character(key.lowercased())
        if !literalMode && transform(lower) { return true }
        chars.append(VChar(base: lower, upper: key.isUppercase))
        return true
    }

    public func backspace() {
        guard !chars.isEmpty else { return }
        let tonePos = tone == .none ? nil : tonePosition()
        chars.removeLast()
        if tonePos == chars.count { tone = .none }
        restorable = false
        if chars.isEmpty { reset() }
    }

    // MARK: - Biến đổi

    private func transform(_ k: Character) -> Bool {
        switch method {
        case .telex:
            switch k {
            case "s": return applyTone(.sac)
            case "f": return applyTone(.huyen)
            case "r": return applyTone(.hoi)
            case "x": return applyTone(.nga)
            case "j": return applyTone(.nang)
            case "z": return removeTone()
            case "a", "e", "o": return applyMark(.hat, candidates: hatCandidates(only: k))
            case "w": return applyW()
            case "d": return applyStroke()
            default: return false
            }
        case .vni:
            switch k {
            case "1": return applyTone(.sac)
            case "2": return applyTone(.huyen)
            case "3": return applyTone(.hoi)
            case "4": return applyTone(.nga)
            case "5": return applyTone(.nang)
            case "0": return removeTone()
            case "6": return applyMark(.hat, candidates: hatCandidates(only: nil))
            case "7": return applyMark(.horn, candidates: hornCandidates())
            case "8": return applyMark(.breve, candidates: breveCandidates())
            case "9": return applyStroke()
            default: return false
            }
        }
    }

    private func applyTone(_ t: Tone) -> Bool {
        guard vowelRange() != nil, structureOK() else { return false }
        if tone == t {
            tone = .none
            literalMode = true
            return false   // phím được thêm như chữ thường: "ass"
        }
        if ["c", "ch", "p", "t"].contains(finalString()) && !(t == .sac || t == .nang) {
            return false
        }
        tone = t
        return true
    }

    private func removeTone() -> Bool {
        guard tone != .none else { return false }
        tone = .none
        return true
    }

    private func applyStroke() -> Bool {
        guard let first = chars.first, first.base == "d" else { return false }
        if first.mark == .stroke {
            chars[0].mark = .none
            literalMode = true
            return false
        }
        chars[0].mark = .stroke
        return true
    }

    /// Mỗi ứng viên là một nhóm (vị trí, dấu) áp cùng lúc.
    private typealias Edit = [(Int, Mark)]

    private func applyMark(_ mark: Mark, candidates: [Edit]) -> Bool {
        guard structureOK() else { return false }
        for edit in candidates {
            if edit.allSatisfy({ chars[$0.0].mark == $0.1 }) {
                // Gõ lặp: huỷ dấu, phím thành chữ thường ("aaa" → "aa").
                for (i, _) in edit { chars[i].mark = .none }
                literalMode = true
                return false
            }
            let saved = edit.map { chars[$0.0].mark }
            for (i, m) in edit { chars[i].mark = m }
            if clusterPlausible() { return true }
            for (n, (i, _)) in edit.enumerated() { chars[i].mark = saved[n] }
        }
        return false
    }

    private func applyW() -> Bool {
        if applyMark(.horn, candidates: wCandidates()) { return true }
        if literalMode { return false }
        // "w" đứng riêng → "ư" (vd. "nhw" → "như").
        guard vowelRange() == nil, initialPrefixOK(initialString(upTo: chars.count)) else { return false }
        chars.append(VChar(base: "u", mark: .horn, upper: raw.last?.isUppercase ?? false))
        return true
    }

    private func hatCandidates(only target: Character?) -> [Edit] {
        guard let r = vowelRange() else { return [] }
        return r.reversed().compactMap { i in
            let b = chars[i].base
            let ok = target.map { b == $0 } ?? "aeo".contains(b)
            return ok ? [(i, .hat)] : nil
        }
    }

    private func uoPair() -> Edit? {
        guard let r = vowelRange() else { return nil }
        for i in r where i + 1 < r.upperBound {
            if chars[i].base == "u" && chars[i + 1].base == "o" { return [(i, .horn), (i + 1, .horn)] }
        }
        return nil
    }

    private func hornCandidates() -> [Edit] {
        guard let r = vowelRange() else { return [] }
        var out: [Edit] = []
        if let p = uoPair() { out.append(p) }
        for i in r.reversed() where "ou".contains(chars[i].base) { out.append([(i, .horn)]) }
        return out
    }

    private func breveCandidates() -> [Edit] {
        guard let r = vowelRange() else { return [] }
        return r.reversed().compactMap { chars[$0].base == "a" ? [($0, .breve)] : nil }
    }

    private func wCandidates() -> [Edit] {
        guard let r = vowelRange() else { return [] }
        var out: [Edit] = []
        if let p = uoPair() { out.append(p) }
        for i in r.reversed() {
            switch chars[i].base {
            case "a": out.append([(i, .breve)])
            case "o", "u": out.append([(i, .horn)])
            default: break
            }
        }
        return out
    }

    // MARK: - Cấu trúc âm tiết

    static let initials: Set<String> = [
        "", "b", "c", "ch", "d", "đ", "g", "gh", "gi", "h", "k", "kh", "l", "m", "n", "ng", "ngh",
        "nh", "p", "ph", "q", "qu", "r", "s", "t", "th", "tr", "v", "x",
    ]
    static let finals: Set<String> = ["", "c", "ch", "m", "n", "ng", "nh", "p", "t"]
    static let clusters: Set<String> = [
        "a", "ă", "â", "e", "ê", "i", "o", "ô", "ơ", "u", "ư", "y",
        "ai", "ao", "au", "ay", "âu", "ây", "eo", "êu", "ia", "iê", "iu", "oa", "oă", "oe", "oi",
        "oo", "ôi", "ơi", "ua", "uâ", "uê", "ui", "uô", "uơ", "uy", "ưa", "ưi", "ươ", "ưu", "yê",
        "iêu", "oai", "oay", "oeo", "uây", "uôi", "uya", "uyê", "uyu", "ươi", "ươu", "yêu",
    ]
    static let clusterPrefixes: Set<String> = {
        var s = Set<String>()
        for c in clusters {
            var p = ""
            for ch in c { p.append(ch); s.insert(p) }
        }
        return s
    }()

    /// Khoảng nguyên âm chính, đã bỏ "u" của "qu" và "i" của "gi".
    func vowelRange() -> Range<Int>? {
        guard var start = chars.firstIndex(where: { $0.isVowel }) else { return nil }
        let nextIsVowel = start + 1 < chars.count && chars[start + 1].isVowel
        if start > 0 && nextIsVowel {
            let prev = chars[start - 1].base
            if (prev == "q" && chars[start].base == "u") || (prev == "g" && chars[start].base == "i" && start == 1) {
                start += 1
            }
        }
        var end = start
        while end < chars.count && chars[end].isVowel { end += 1 }
        return start..<end
    }

    private func initialString(upTo n: Int) -> String {
        chars[0..<n].map { $0.plain }.joined()
    }

    private func initialPrefixOK(_ s: String) -> Bool {
        VietEngine.initials.contains { $0.hasPrefix(s) }
    }

    private func finalString() -> String {
        guard let r = vowelRange() else { return "" }
        return chars[r.upperBound...].map { $0.plain }.joined()
    }

    private func clusterString() -> String {
        guard let r = vowelRange() else { return "" }
        return chars[r].map { $0.plain }.joined()
    }

    /// Phụ âm đầu và phụ âm cuối hợp lệ (cho phép đang gõ dở).
    private func structureOK() -> Bool {
        guard let r = vowelRange() else { return initialPrefixOK(initialString(upTo: chars.count)) }
        let ini = initialString(upTo: r.lowerBound)
        // "qu"/"gi" đã bị tách khỏi khoảng nguyên âm nên vẫn nằm trong ini.
        return VietEngine.initials.contains(ini) && VietEngine.finals.contains(finalString())
    }

    private func clusterPlausible() -> Bool {
        VietEngine.clusterPrefixes.contains(clusterString())
    }

    /// Âm tiết hoàn chỉnh hợp lệ — dùng để quyết định khôi phục phím gốc khi commit.
    func isValidSyllable() -> Bool {
        if chars.contains(where: { !$0.base.isLetter }) { return false }
        guard let r = vowelRange() else { return initialPrefixOK(initialString(upTo: chars.count)) }
        guard VietEngine.initials.contains(initialString(upTo: r.lowerBound)),
              VietEngine.clusters.contains(clusterString())
        else { return false }
        let fin = finalString()
        guard VietEngine.finals.contains(fin) else { return false }
        if ["c", "ch", "p", "t"].contains(fin) && !(tone == .none || tone == .sac || tone == .nang) { return false }
        return true
    }

    // MARK: - Vị trí dấu thanh

    func tonePosition() -> Int? {
        guard let r = vowelRange() else { return nil }
        let idx = Array(r)
        if let marked = idx.last(where: { [.hat, .breve, .horn].contains(chars[$0].mark) }) {
            return marked
        }
        if idx.count == 1 { return idx[0] }
        if r.upperBound < chars.count { return idx.last }   // có phụ âm cuối: toán, hoàng
        if idx.count == 3 { return idx[1] }                  // ngoài, xoáy
        let pair = String(idx.map { chars[$0].base })
        if modernTone && ["oa", "oe", "uy"].contains(pair) { return idx[1] }
        return idx[0]                                        // của, mía, hai
    }

    // MARK: - Xuất chữ

    public var composed: String {
        let tp = tone == .none ? nil : tonePosition()
        var s = ""
        for (i, c) in chars.enumerated() {
            var t: String
            if c.base == "d" && c.mark == .stroke {
                t = "đ"
            } else {
                t = String(c.base) + c.mark.combining
                if i == tp, let comb = tone.combining { t += comb }
                t = t.precomposedStringWithCanonicalMapping
            }
            s += c.upper ? t.uppercased() : t
        }
        return s
    }

    private var hasDiacritics: Bool {
        tone != .none || chars.contains { $0.mark != .none }
    }

    /// Chuỗi để chèn khi kết thúc từ; reset bộ đệm.
    public func commitText() -> String {
        defer { reset() }
        let out = composed
        if autoRestore && restorable && hasDiacritics && !isValidSyllable() {
            return raw
        }
        return out
    }
}
