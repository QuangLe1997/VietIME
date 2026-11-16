import Cocoa
import InputMethodKit

// Cách làm: giữ từ đang gõ ở dạng "marked text" (chữ tạm của app), khi kết thúc từ thì
// insertText một lần. Không giả lập phím Backspace như các bộ gõ khác, nên không bị
// nhân đôi/mất chữ ở app Electron, Chrome, Telegram khi gõ nhanh.

@objc(VietIMEInputController)
final class VietIMEInputController: IMKInputController {
    private let engine = VietEngine()
    private let state = AppState.shared
    /// Đang giữ đúng tổ hợp phím tắt (⌃⇧ / ⌘⇧) và chưa bấm phím nào khác.
    private var shortcutArmed = false

    private func syncPrefs() {
        engine.method = state.method
        engine.modernTone = state.modernTone
        engine.autoRestore = state.autoRestore
    }

    override func activateServer(_ sender: Any!) {
        syncPrefs()
        engine.reset()
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

        // Phím tắt (⌘C, ⌃A, ⌥…) → chốt từ rồi để app xử lý.
        if !mods.intersection([.command, .control, .option]).isEmpty {
            commit(client)
            return false
        }

        switch event.keyCode {
        case 51: // Delete
            guard !engine.isEmpty else { return false }
            engine.backspace()
            showComposition(client)
            return true
        case 53: // Esc: bỏ dấu, trả nguyên phím đã gõ
            guard !engine.isEmpty else { return false }
            let rawText = engine.rawKeys
            engine.reset()
            client.insertText(rawText, replacementRange: Self.notFound)
            return true
        default:
            break
        }

        guard let s = event.characters, s.count == 1, let ch = s.first, engine.process(ch) else {
            // Space, Enter, Tab, dấu câu, phím mũi tên… → chốt từ trước, app nhận phím sau.
            commit(client)
            return false
        }
        showComposition(client)
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

    private func showComposition(_ client: IMKTextInput) {
        let text = engine.composed
        let attrs: [NSAttributedString.Key: Any] = [
            .underlineStyle: state.underline ? NSUnderlineStyle.single.rawValue : 0,
        ]
        client.setMarkedText(NSAttributedString(string: text, attributes: attrs),
                             selectionRange: NSRange(location: (text as NSString).length, length: 0),
                             replacementRange: Self.notFound)
    }

    private func commit(_ sender: Any?) {
        guard !engine.isEmpty else { return }
        let text = engine.commitText()
        guard let client = (sender as? IMKTextInput) ?? self.client() else { return }
        client.insertText(text, replacementRange: Self.notFound)
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
