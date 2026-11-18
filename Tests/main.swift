import Foundation

// Chạy: make test

var failures = 0
var total = 0

/// Gõ chuỗi phím; space/dấu câu kết thúc từ như khi gõ thật.
func type(_ keys: String, _ method: InputMethod = .telex, modern: Bool = true, w: Bool = false) -> String {
    let e = VietEngine(method: method)
    e.modernTone = modern
    e.standaloneW = w
    e.isEnglishWord = { ["affect", "coffee", "possible", "aromatize", "horary", "hertz", "barsom"].contains($0) }
    var out = ""
    for k in keys {
        if k == "<" { e.backspace(); continue }
        if !e.process(k) {
            out += e.commitText()
            out.append(k)
        }
    }
    return out + e.commitText()
}

func check(_ keys: String, _ want: String, _ method: InputMethod = .telex, modern: Bool = true, w: Bool = false) {
    total += 1
    let got = type(keys, method, modern: modern, w: w)
    if got != want {
        failures += 1
        print("FAIL [\(method)] \"\(keys)\" → \"\(got)\", muốn \"\(want)\"")
    }
}

// Telex cơ bản
check("tieengs Vieetj", "tiếng Việt")
check("dduowngf", "đường")
check("nguowif", "người")
check("Ddaay laf mootj caau", "Đây là một câu")
check("gios", "gió")
check("giuwx", "giữ")
check("gif", "gì")
check("quyeets", "quyết")
check("quas", "quá")
check("cuar", "của")
check("mias", "mía")
check("ngoaif", "ngoài")
check("xoays", "xoáy")
check("toans", "toán")
check("hoangf", "hoàng")
check("huyfnh", "huỳnh")
check("rwowuj", "rượu", w: true)
check("ruwowuj", "rượu")
check("muwa", "mưa")
check("muaw", "mưa")
// w đứng riêng: tắt (mặc định) thì giữ chữ w; bật thì thành ư, gõ ww trả lại w
check("w", "w")
check("web", "web")
check("nhw", "nhw")
check("nhw", "như", w: true)
check("w", "ư", w: true)
check("ww", "w", w: true)
check("nhww", "nhw", w: true)
check("Ww", "W", w: true)
check("wwas", "was", w: true)
check("what", "what", w: true)
check("tuwj", "tự")
check("ddi", "đi")
check("DDi", "Đi")
check("VIEETJ", "VIỆT")
check("hocj", "học")
check("cacs", "các")
check("khoer", "khoẻ")
check("thuyr", "thuỷ")
check("hoaf", "hoà")
check("hoaf", "hòa", modern: false)
check("thuyr", "thủy", modern: false)
check("trangw", "trăng")
check("ows", "ớ")
// Bỏ dấu giữa chừng, dấu thanh tự nhảy chỗ
check("hosa", "hoá")
check("tiengs", "tiengs")   // "tiéng" không hợp lệ → trả phím gốc
check("tiengse", "tiếng")
// Đổi / xoá dấu
check("asf", "à")
check("asz", "a")
// Gõ lặp để huỷ
check("ass", "as")
check("aaa", "aa")
check("ddd", "dd")
check("uww", "uw")
check("tesst", "test")
// Tiếng Anh tự khôi phục / không bị biến
check("windows", "windows")
check("class", "class")
check("string", "string")
check("hello", "hello")
check("what", "what")
// Dấu câu, số trong Telex
check("xin chaof, banj!", "xin chào, bạn!")
check("abc123", "abc123")
// Backspace
check("tieengs<", "tiến")
check("hoaf<", "ho")

// VNI
check("tie6ng1 Vie65t", "tiếng Việt", .vni)
check("d9u7o7ng2", "đường", .vni)
check("ngu7o7i2", "người", .vni)
check("a8n", "ăn", .vni)
check("a11", "a1", .vni)
check("so61 123", "số 123", .vni)
check("hoa2", "hoà", .vni)
check("1", "1", .vni)


// Rà soát 18/11: các lỗi cùng họ với "ww"
check("thuowr", "thuở")
check("huow", "huơ")
check("thuo73", "thuở", .vni)
check("quynhf", "quỳnh")
check("ddc ddk ddt", "đc đk đt")
check("affect", "affect")          // ff: f thứ hai huỷ dấu → mất chữ, từ điển trả lại
check("coffee", "coffee")
check("possible", "possible")
check("aromatize", "aromatize")    // z xoá dấu
check("horary", "horary")          // r lặp không liền nhau
check("hertz", "hertz")
check("barsom", "barsom")          // "ao" không đi với phụ âm cuối
check("ass", "as")                 // từ ngắn gõ lặp là chủ ý
check("tesst", "test")

// Danh sách từ tiếng Việt khó, gõ 4–5 kiểu
let vnWords = """
giường giữa giấy gì gìn già giếng giỏi giận quốc quyết quyền quý quà quạ quẹo khuya khuỷu người mười rượu hươu bướu
ngoài xoáy ngoằn ngoéo khuây tuổi chuối hiểu yêu yếu kêu đâu đấy hưu hữu gửi ngửi mới tối đói hai sao đau bay kéo
mía dịu của mưa túi thuế thuở huơ đường đẹp học thích chênh nghiêng nghĩ nghiệp khoẻ hoà thuỷ loè oải toả Việt Nam
Hà Nội Đà Nẵng Huế Sài Gòn Cần Thơ chuyện truyện khuyên Nguyễn xuyên uống muốn buồn luôn cuộc thuốc chương trường
hương mượn lưỡi cưới tươi nước bước được ước ướt ấy ở ừ ạ ơi à ồ ủa oà oan hoắc loắt ngoặt xoăn quăng khoăn tuần
khuất quân uể thuê huệ khuếch nguệch huých uỵch huỳnh quỳnh khuynh tuyệt chuyên luyện nguyện khuyết huyết quyển thuyền
yết yên yến yểu ý kỷ lý mỹ tỷ hy đi đã để đó đây đều điều điện đổi đồng được đứng vậy với vui vẻ xin chào cảm ơn
không những nhưng nhiều nhất phải phố phường gửi giờ gió giày giữ giúp giết giáo giọng quê quen quán quận quét
tiếng tiền tiếp tiêu biết biển miệng liệu nhiệm khiến chiều điểm
"""
    .split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init)

let toneKey: [UInt32: Character] = [0x301: "s", 0x300: "f", 0x309: "r", 0x303: "x", 0x323: "j"]
/// Mã hoá Telex từ chữ đúng: (phím gõ dấu thanh cuối từ, phím gõ dấu thanh ngay sau nguyên âm mang dấu)
func encode(_ w: String) -> (String, String) {
    var body = "", early = "", tone: Character? = nil
    for ch in w {
        if ch == "đ" || ch == "Đ" { let d = ch == "Đ" ? "D" : "d"; body += d + "d"; early += d + "d"; continue }
        let scalars = String(ch).decomposedStringWithCanonicalMapping.unicodeScalars
        var base = "", mod = "", t: Character? = nil
        for s in scalars {
            switch s.value {
            case 0x302: mod = base.lowercased()       // â ê ô: gõ lặp
            case 0x306, 0x31B: mod = "w"              // ă, ơ ư
            default: if let k = toneKey[s.value] { t = k } else { base += String(s) }
            }
        }
        body += base + mod; early += base + mod
        if let t { tone = t; early.append(t) }
    }
    return (tone.map { body + String($0) } ?? body, early)
}
func typeWord(_ keys: String, _ m: InputMethod = .telex) -> String { let e = VietEngine(method: m); e.isEnglishWord = EnglishWords.contains; for k in keys { _ = e.process(k) }; return e.commitText() }
let vniTone: [UInt32: Character] = [0x301: "1", 0x300: "2", 0x309: "3", 0x303: "4", 0x323: "5"]
/// VNI: chữ số ngay sau ký tự, dấu thanh cuối từ.
func encodeVNI(_ w: String) -> String {
    var body = "", tone: Character? = nil
    for ch in w {
        if ch == "đ" || ch == "Đ" { body += (ch == "Đ" ? "D" : "d") + "9"; continue }
        var base = "", mod = ""
        for s in String(ch).decomposedStringWithCanonicalMapping.unicodeScalars {
            switch s.value {
            case 0x302: mod = "6"; case 0x306: mod = "8"; case 0x31B: mod = "7"
            default: if let k = vniTone[s.value] { tone = k } else { base += String(s) }
            }
        }
        body += base + mod
    }
    return tone.map { body + String($0) } ?? body
}
/// Telex gõ chữ trơn trước, dấu thanh rồi dấu mũ/móc ở cuối (chỉ từ có đúng một chữ mang mũ/móc).
func encodeLateMod(_ w: String) -> String? {
    var body = "", mods = "", tone = "", count = 0
    for ch in w {
        if ch == "đ" || ch == "Đ" { return nil }
        var base = ""
        for s in String(ch).decomposedStringWithCanonicalMapping.unicodeScalars {
            switch s.value {
            case 0x302: count += 1; mods = base.lowercased()
            case 0x306, 0x31B: count += 1; mods = "w"
            default: if let k = toneKey[s.value] { tone = String(k) } else { base += String(s) }
            }
        }
        body += base
    }
    return count == 1 ? body + tone + mods : nil
}
for w in vnWords {
    let (late, early) = encode(w)
    var cases = [("cuối", late, InputMethod.telex), ("sớm", early, .telex), ("HOA", encode(w.uppercased()).0, .telex),
                 ("VNI", encodeVNI(w), .vni)]
    if let lm = encodeLateMod(w) { cases.append(("mũ-cuối", lm, .telex)) }
    for (label, keys, m) in cases {
        total += 1
        let want = label == "HOA" ? w.uppercased() : w
        let got = typeWord(keys, m)
        if got != want { failures += 1; print("FAIL [\(label)] \(keys) → \(got), muốn \(want)") }
    }
}

print(failures == 0 ? "OK \(total)/\(total)" : "\(failures) lỗi / \(total)")
exit(failures == 0 ? 0 : 1)
