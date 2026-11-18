import Cocoa
import InputMethodKit

// Hai cách đưa chữ vào app, đều không giả lập phím Backspace như EVKey/OpenKey:
//
// 1. Gõ trực tiếp (mặc định): chèn chữ thật vào ô nhập, mỗi lần thêm dấu thì thay cả từ
//    bằng insertText(_:replacementRange:). Không có chữ tạm nên Enter trong Telegram,
//    Messenger… gửi tin ngay.
// 2. Chữ tạm (marked text): từ đang gõ là chữ tạm, hết từ mới chèn. Dùng khi tắt gõ trực
//    tiếp, hoặc tự chuyển sang khi app không cho thay chữ theo vùng (một số terminal, app Java).

@objc(VietIMEInputController)
final class VietIMEInputController: IMKInputController {
    private let engine = VietEngine()
    private let state = AppState.shared
    /// Đang giữ đúng tổ hợp phím tắt (⌃⇧ / ⌘⇧) và chưa bấm phím nào khác.
    private var shortcutArmed = false

    // Từ đang gõ ở chế độ trực tiếp: vị trí bắt đầu trong ô nhập, độ dài UTF-16 và nội dung
    // VietIME đã chèn (để kiểm con trỏ chưa bị dời trước khi thay).
    private var wordStart: Int?
    private var wordLen = 0
    private var wordText: String?
    /// Từ hiện tại đang dùng chữ tạm.
    private var markedWord = false

    private func syncPrefs() {
        engine.method = state.method
        engine.modernTone = state.modernTone
        engine.autoRestore = state.autoRestore
        engine.standaloneW = state.standaloneW
    }

    private func clearWord() {
        wordStart = nil
        wordLen = 0
        wordText = nil
        markedWord = false
    }

    override func activateServer(_ sender: Any!) {
        syncPrefs()
        engine.reset()
        clearWord()
        shortcutArmed = false
        state.refreshStatus()
    }

    override func deactivateServer(_ sender: Any!) {
        commit(sender)
    }

    /// App gọi khi người dùng click chỗ khác, đổi ô nhập…
    override func commitComposition(_ sender: Any!) {
        commit(sender)
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.union(.flagsChanged).rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, let client = sender as? IMKTextInput else { return false }

        if event.type == .flagsChanged {
            handleModifiers(event, client)
            return false
        }
        guard event.type == .keyDown else { return false }
        shortcutArmed = false
        syncPrefs()

        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])

        // ⌥Z
        if state.shortcut == .optZ && mods == .option && event.keyCode == 6 {
            toggleLanguage(client)
            return true
        }

        guard state.vietnamese else {
            commit(client)
            return false
        }

        // Con trỏ đã bị dời (click chuột, app tự sửa chữ) → bỏ từ cũ, coi như từ mới.
        if !engine.isEmpty && !markedWord && !directWordStillValid(client) {
            engine.reset()
            clearWord()
        }

        // Phím tắt (⌘C, ⌃A, ⌥…) → chốt từ rồi để app xử lý.
        if !mods.intersection([.command, .control, .option]).isEmpty {
            commit(client)
            return false
        }

        switch event.keyCode {
        case 51: // Delete
            guard !engine.isEmpty else { return false }
            engine.backspace()
            render(client)
            if engine.isEmpty { clearWord() }
            return true
        case 53: // Esc: bỏ dấu, trả nguyên phím đã gõ
            guard !engine.isEmpty else { return false }
            let rawText = engine.rawKeys
            engine.reset()
            write(rawText, client)
            clearWord()
            return true
        default:
            break
        }

        let wasEmpty = engine.isEmpty
        guard let s = event.characters, s.count == 1, let ch = s.first, engine.process(ch) else {
            // Space, Enter, Tab, dấu câu, phím mũi tên… → chốt từ trước, app nhận phím sau.
            commit(client)
            return false
        }
        if wasEmpty { beginWord(client) }
        render(client)
        return true
    }

    /// ⌃⇧ / ⌘⇧: bấm đủ tổ hợp rồi thả hết, giữa chừng không bấm phím nào khác.
    private func handleModifiers(_ event: NSEvent, _ client: IMKTextInput) {
        guard let target = state.shortcut.modifierOnly else { return }
        let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if mods.isEmpty {
            if shortcutArmed { toggleLanguage(client) }
            shortcutArmed = false
        } else if mods == target {
            shortcutArmed = true
        } else if !target.isSuperset(of: mods) {
            shortcutArmed = false
        }
    }

    private func toggleLanguage(_ client: IMKTextInput) {
        commit(client)
        state.vietnamese.toggle()
    }

    // MARK: - Ghi ra app

    private static let notFound = NSRange(location: NSNotFound, length: NSNotFound)

    /// Chọn cách hiển thị cho từ mới.
    private func beginWord(_ client: IMKTextInput) {
        clearWord()
        let app = client.bundleIdentifier() ?? ""
        guard state.directMode, !state.markedApps.contains(app) else {
            markedWord = true
            return
        }
        let sel = client.selectedRange()
        guard sel.location != NSNotFound else {
            markedWord = true
            return
        }
        // App không đọc được chữ trước con trỏ thì cũng không thay chữ theo vùng được.
        if sel.location > 0 && client.attributedSubstring(from: NSRange(location: sel.location - 1, length: 1)) == nil {
            state.addMarkedApp(app)
            markedWord = true
            return
        }
        wordStart = sel.location
        wordLen = sel.length   // đang bôi đen thì chữ gõ vào thay phần bôi đen
    }

    private func directWordStillValid(_ client: IMKTextInput) -> Bool {
        guard let start = wordStart, let text = wordText else { return false }
        let sel = client.selectedRange()
        guard sel.location == start + wordLen, sel.length == 0 else { return false }
        return client.attributedSubstring(from: NSRange(location: start, length: wordLen))?.string == text
    }

    private func render(_ client: IMKTextInput) {
        if markedWord {
            showMarked(client)
            return
        }
        guard let start = wordStart else { return }
        let text = engine.composed
        client.insertText(text, replacementRange: NSRange(location: start, length: wordLen))
        let n = (text as NSString).length
        let readBack = n == 0 ? "" : client.attributedSubstring(from: NSRange(location: start, length: n))?.string
        if readBack == text {
            wordLen = n
            wordText = text
        } else {
            // App không làm đúng việc thay chữ: lần sau dùng chữ tạm cho app này.
            state.addMarkedApp(client.bundleIdentifier() ?? "")
            engine.reset()
            clearWord()
        }
    }

    private func showMarked(_ client: IMKTextInput) {
        let text = engine.composed
        let attrs: [NSAttributedString.Key: Any] = [
            .underlineStyle: state.underline ? NSUnderlineStyle.single.rawValue : 0,
        ]
        client.setMarkedText(NSAttributedString(string: text, attributes: attrs),
                             selectionRange: NSRange(location: (text as NSString).length, length: 0),
                             replacementRange: Self.notFound)
    }

    /// Ghi chuỗi cuối cùng của từ (đã chốt) ra app.
    private func write(_ final: String, _ client: IMKTextInput) {
        if markedWord {
            client.insertText(final, replacementRange: Self.notFound)
        } else if let start = wordStart, final != wordText, directWordStillValid(client) {
            client.insertText(final, replacementRange: NSRange(location: start, length: wordLen))
        }
    }

    private func commit(_ sender: Any?) {
        defer { clearWord() }
        guard !engine.isEmpty else { return }
        let final = engine.commitText()
        guard let client = (sender as? IMKTextInput) ?? self.client() else { return }
        write(final, client)
    }

    // MARK: - Menu của biểu tượng nguồn nhập (cùng nội dung với menu V/E)

    override func menu() -> NSMenu! {
        state.buildMenu(target: self)
    }

    // IMK gửi action của menu về controller; chuyển tiếp sang AppState.
    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || AppState.actions.contains(aSelector)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if AppState.actions.contains(aSelector) {
            commit(nil)
            return state
        }
        return super.forwardingTarget(for: aSelector)
    }
}
