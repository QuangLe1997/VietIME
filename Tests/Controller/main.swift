import Cocoa
import InputMethodKit

// Chạy controller thật trên một ô nhập giả. Ô nhập mô phỏng Telegram: Enter mà còn chữ tạm
// thì xuống dòng, không còn chữ tạm thì gửi tin. Chạy: make test

class FakeTextView: NSObject, IMKTextInput {
    var text = NSMutableString()
    var sel = NSRange(location: 0, length: 0)
    var marked: NSRange?
    var sent: [String] = []
    var bundleID = "test.fake"

    // MARK: IMKTextInput
    func insertText(_ string: Any!, replacementRange: NSRange) {
        let s = (string as? NSAttributedString)?.string ?? (string as? String) ?? ""
        let r = replacementRange.location != NSNotFound ? replacementRange : (marked ?? sel)
        text.replaceCharacters(in: r, with: s)
        sel = NSRange(location: r.location + (s as NSString).length, length: 0)
        marked = nil
    }
    func setMarkedText(_ string: Any!, selectionRange: NSRange, replacementRange: NSRange) {
        let s = (string as? NSAttributedString)?.string ?? (string as? String) ?? ""
        let r = replacementRange.location != NSNotFound ? replacementRange : (marked ?? sel)
        text.replaceCharacters(in: r, with: s)
        let n = (s as NSString).length
        marked = n == 0 ? nil : NSRange(location: r.location, length: n)
        sel = NSRange(location: r.location + selectionRange.location, length: 0)
    }
    func selectedRange() -> NSRange { sel }
    func markedRange() -> NSRange { marked ?? NSRange(location: NSNotFound, length: 0) }
    func attributedSubstring(from range: NSRange) -> NSAttributedString! {
        guard range.location != NSNotFound, NSMaxRange(range) <= text.length else { return nil }
        return NSAttributedString(string: text.substring(with: range))
    }
    func length() -> Int { text.length }
    func characterIndex(for point: NSPoint, tracking mappingMode: IMKLocationToOffsetMappingMode,
                        inMarkedRange: UnsafeMutablePointer<ObjCBool>!) -> Int { 0 }
    func attributes(forCharacterIndex index: Int, lineHeightRectangle: UnsafeMutablePointer<NSRect>!) -> [AnyHashable: Any]! { [:] }
    func validAttributesForMarkedText() -> [Any]! { [] }
    func overrideKeyboard(withKeyboardNamed keyboardUniqueName: String!) {}
    func selectMode(_ modeIdentifier: String!) {}
    func supportsUnicode() -> Bool { true }
    func bundleIdentifier() -> String! { bundleID }
    func windowLevel() -> CGWindowLevel { 0 }
    func supportsProperty(_ property: TSMDocumentPropertyTag) -> Bool { false }
    func uniqueClientIdentifierString() -> String! { "fake" }
    func string(from range: NSRange, actualRange: NSRangePointer!) -> String! { text.substring(with: range) }
    func firstRect(forCharacterRange aRange: NSRange, actualRange: NSRangePointer!) -> NSRect { .zero }

    // MARK: phím mà IME trả lại cho app
    func appHandles(_ ch: String) {
        if ch == "\r" {
            if marked != nil { insertText("\n", replacementRange: NSRange(location: NSNotFound, length: 0)) }
            else { sent.append(text as String); text = NSMutableString(); sel = NSRange(location: 0, length: 0) }
        } else if ch == "\u{7f}" {
            if sel.location > 0 { text.deleteCharacters(in: NSRange(location: sel.location - 1, length: 1)); sel.location -= 1 }
        } else {
            insertText(ch, replacementRange: NSRange(location: NSNotFound, length: 0))
        }
    }
}

let keyCodes: [Character: UInt16] = [" ": 49, "\r": 36, "\u{7f}": 51, "\u{1b}": 53]

func press(_ ch: Character, _ ctl: VietIMEInputController, _ view: FakeTextView) {
    let s = String(ch)
    // Telegram: Enter khi không còn chữ tạm thì gửi luôn, IME không được hỏi.
    if ch == "\r" && view.marked == nil { view.appHandles("\r"); return }
    let ev = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                              context: nil, characters: s, charactersIgnoringModifiers: s, isARepeat: false,
                              keyCode: keyCodes[ch] ?? 0)!
    // Còn chữ tạm lúc bấm Enter: Telegram đã quyết định "không gửi" trước khi hỏi IME → xuống dòng.
    if ch == "\r" {
        if !ctl.handle(ev, client: view) { view.insertText("\n", replacementRange: NSRange(location: NSNotFound, length: 0)) }
        return
    }
    if !ctl.handle(ev, client: view) { view.appHandles(s) }
}

var failures = 0, total = 0

/// "<" = Backspace, "⏎" = Enter, "⎋" = Esc.
func run(_ keys: String, direct: Bool) -> FakeTextView {
    UserDefaults.standard.set(direct, forKey: "directMode")
    UserDefaults.standard.set([String](), forKey: "markedApps")
    let view = FakeTextView()
    let ctl = VietIMEInputController()
    ctl.activateServer(view)
    for k in keys {
        switch k {
        case "<": press("\u{7f}", ctl, view)
        case "⏎": press("\r", ctl, view)
        case "⎋": press("\u{1b}", ctl, view)
        default: press(k, ctl, view)
        }
    }
    ctl.commitComposition(view)
    return view
}

func check(_ keys: String, text want: String, sent wantSent: [String] = [], direct: Bool = true) {
    total += 1
    let v = run(keys, direct: direct)
    if v.text as String != want || v.sent != wantSent {
        failures += 1
        print("FAIL [\(direct ? "trực tiếp" : "chữ tạm")] \"\(keys)\" → text \"\(v.text)\" sent \(v.sent); muốn \"\(want)\" sent \(wantSent)")
    }
}

for direct in [true, false] {
    check("tieengs Vieetj", text: "tiếng Việt", direct: direct)
    check("tesst ", text: "test ", direct: direct)
    check("ass", text: "as", direct: direct)
    check("dduowngf nguowif", text: "đường người", direct: direct)
    check("windows", text: "windows", direct: direct)
    check("tieengs<", text: "tiến", direct: direct)
    check("hoaf<<<x", text: "x", direct: direct)
    check("Vieetj⎋", text: "Vieetj", direct: direct)
}
// Enter gửi tin ngay ở chế độ trực tiếp; chữ tạm thì xuống dòng (hành vi cũ).
check("xin chaof⏎", text: "", sent: ["xin chào"], direct: true)
check("xin chaof⏎", text: "xin chào\n", direct: false)
check("chaof ⏎", text: "", sent: ["chào "], direct: false)

// App bỏ qua replacementRange (chèn ở con trỏ): từ đầu bị hỏng một lần, sau đó tự sang chữ tạm.
final class BrokenView: FakeTextView {
    override func insertText(_ string: Any!, replacementRange: NSRange) {
        super.insertText(string, replacementRange: NSRange(location: NSNotFound, length: 0))
    }
}
do {
    total += 1
    UserDefaults.standard.set(true, forKey: "directMode")
    UserDefaults.standard.set([String](), forKey: "markedApps")
    let view = BrokenView()
    view.bundleID = "test.broken"
    let ctl = VietIMEInputController()
    ctl.activateServer(view)
    for k in "chaof " { press(k, ctl, view) }
    view.text = NSMutableString(); view.sel = NSRange(location: 0, length: 0)
    for k in "dduowngf⏎" { press(k == "⏎" ? "\r" : k, ctl, view) }
    let learned = UserDefaults.standard.stringArray(forKey: "markedApps") ?? []
    if !learned.contains("test.broken") || view.text as String != "đường\n" {
        failures += 1
        print("FAIL đường lui: markedApps \(learned), text \"\(view.text)\"")
    }
}

print(failures == 0 ? "Controller OK \(total)/\(total)" : "Controller \(failures) lỗi / \(total)")
exit(failures == 0 ? 0 : 1)
