import Foundation

// Chạy: make test

var failures = 0
var total = 0

/// Gõ chuỗi phím; space/dấu câu kết thúc từ như khi gõ thật.
func type(_ keys: String, _ method: InputMethod = .telex, modern: Bool = true, w: Bool = false) -> String {
    let e = VietEngine(method: method)
    e.modernTone = modern
    e.standaloneW = w
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

print(failures == 0 ? "OK \(total)/\(total)" : "\(failures) lỗi / \(total)")
exit(failures == 0 ? 0 : 1)
