import Carbon
import Cocoa

/// Phím tắt chuyển Anh ↔ Việt mà không đổi nguồn nhập (như Unikey/EVKey).
enum Shortcut: String, CaseIterable {
    case ctrlShift, cmdShift, optZ

    var title: String {
        switch self {
        case .ctrlShift: return "⌃⇧  Control + Shift"
        case .cmdShift: return "⌘⇧  Command + Shift"
        case .optZ: return "⌥Z  Option + Z"
        }
    }

    var symbol: String {
        switch self {
        case .ctrlShift: return "⌃⇧"
        case .cmdShift: return "⌘⇧"
        case .optZ: return "⌥Z"
        }
    }

    /// Tổ hợp chỉ gồm phím bổ trợ: bấm rồi thả, không kèm phím nào khác.
    var modifierOnly: NSEvent.ModifierFlags? {
        switch self {
        case .ctrlShift: return [.control, .shift]
        case .cmdShift: return [.command, .shift]
        case .optZ: return nil
        }
    }
}

/// Cài đặt dùng chung cho mọi ô nhập + biểu tượng V/E trên thanh menu.
final class AppState: NSObject {
    static let shared = AppState()

    private let d = UserDefaults.standard
    private var statusItem: NSStatusItem?
    private let forceStatus = ProcessInfo.processInfo.environment["VIETIME_FORCE_STATUS"] != nil

    private override init() {
        super.init()
        d.register(defaults: [
            "vietnamese": true,
            "method": InputMethod.telex.rawValue,
            "modernTone": true,
            "autoRestore": true,
            "underline": false,
            "showStatusIcon": true,
            "directMode": true,
            "markedApps": [String](),
            "shortcut": Shortcut.ctrlShift.rawValue,
        ])
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(inputSourceChanged),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, suspensionBehavior: .deliverImmediately)
        refreshStatus()
    }

    // MARK: - Cài đặt

    var vietnamese: Bool {
        get { d.bool(forKey: "vietnamese") }
        set { d.set(newValue, forKey: "vietnamese"); refreshStatus() }
    }
    var method: InputMethod {
        get { InputMethod(rawValue: d.string(forKey: "method") ?? "") ?? .telex }
        set { d.set(newValue.rawValue, forKey: "method"); refreshStatus() }
    }
    var shortcut: Shortcut {
        get { Shortcut(rawValue: d.string(forKey: "shortcut") ?? "") ?? .ctrlShift }
        set { d.set(newValue.rawValue, forKey: "shortcut"); refreshStatus() }
    }
    var modernTone: Bool { d.bool(forKey: "modernTone") }
    var autoRestore: Bool { d.bool(forKey: "autoRestore") }
    var underline: Bool { d.bool(forKey: "underline") }
    var showStatusIcon: Bool { d.bool(forKey: "showStatusIcon") }
    var directMode: Bool { d.bool(forKey: "directMode") }
    /// App không cho thay chữ theo vùng → luôn dùng chữ tạm.
    var markedApps: [String] { d.stringArray(forKey: "markedApps") ?? [] }

    func addMarkedApp(_ bundleID: String) {
        guard !bundleID.isEmpty, !markedApps.contains(bundleID) else { return }
        d.set(markedApps + [bundleID], forKey: "markedApps")
        NSLog("VietIME: %@ không hỗ trợ gõ trực tiếp, chuyển sang chữ tạm", bundleID)
    }

    private func flip(_ key: String) {
        d.set(!d.bool(forKey: key), forKey: key)
        refreshStatus()
    }

    // MARK: - Hành động menu (controller chuyển tiếp các selector này về đây)

    @objc func toggleVietnamese(_ sender: Any?) { vietnamese.toggle() }
    @objc func selectTelex(_ sender: Any?) { method = .telex }
    @objc func selectVNI(_ sender: Any?) { method = .vni }
    @objc func toggleModernTone(_ sender: Any?) { flip("modernTone") }
    @objc func toggleAutoRestore(_ sender: Any?) { flip("autoRestore") }
    @objc func toggleUnderline(_ sender: Any?) { flip("underline") }
    @objc func toggleStatusIcon(_ sender: Any?) { flip("showStatusIcon") }
    /// Bật/tắt lại thì xoá danh sách app đã tự chuyển sang chữ tạm, để thử lại.
    @objc func toggleDirectMode(_ sender: Any?) {
        d.set([String](), forKey: "markedApps")
        flip("directMode")
    }
    @objc func shortcutCtrlShift(_ sender: Any?) { shortcut = .ctrlShift }
    @objc func shortcutCmdShift(_ sender: Any?) { shortcut = .cmdShift }
    @objc func shortcutOptZ(_ sender: Any?) { shortcut = .optZ }

    static let actions: Set<Selector> = [
        #selector(toggleVietnamese(_:)), #selector(selectTelex(_:)), #selector(selectVNI(_:)),
        #selector(toggleModernTone(_:)), #selector(toggleAutoRestore(_:)), #selector(toggleUnderline(_:)),
        #selector(toggleStatusIcon(_:)), #selector(toggleDirectMode(_:)), #selector(shortcutCtrlShift(_:)), #selector(shortcutCmdShift(_:)),
        #selector(shortcutOptZ(_:)),
    ]

    func buildMenu(target: AnyObject) -> NSMenu {
        let menu = NSMenu(title: "VietIME")
        func item(_ title: String, _ action: Selector?, _ on: Bool = false, indent: Bool = false) {
            let it = NSMenuItem(title: title, action: action, keyEquivalent: "")
            it.target = action == nil ? nil : target
            it.state = on ? .on : .off
            it.isEnabled = action != nil
            if indent { it.indentationLevel = 1 }
            menu.addItem(it)
        }
        item("Gõ tiếng Việt   (\(shortcut.symbol))", #selector(toggleVietnamese(_:)), vietnamese)
        menu.addItem(.separator())
        item("Telex", #selector(selectTelex(_:)), method == .telex)
        item("VNI", #selector(selectVNI(_:)), method == .vni)
        menu.addItem(.separator())
        item("Phím tắt chuyển Anh/Việt", nil)
        item(Shortcut.ctrlShift.title, #selector(shortcutCtrlShift(_:)), shortcut == .ctrlShift, indent: true)
        item(Shortcut.cmdShift.title, #selector(shortcutCmdShift(_:)), shortcut == .cmdShift, indent: true)
        item(Shortcut.optZ.title, #selector(shortcutOptZ(_:)), shortcut == .optZ, indent: true)
        menu.addItem(.separator())
        item("Gõ trực tiếp (Enter gửi tin ngay)", #selector(toggleDirectMode(_:)), directMode)
        item("Bỏ dấu kiểu mới (hoà, thuỷ)", #selector(toggleModernTone(_:)), modernTone)
        item("Tự khôi phục từ tiếng Anh", #selector(toggleAutoRestore(_:)), autoRestore)
        item("Gạch chân chữ tạm", #selector(toggleUnderline(_:)), underline)
        item("Hiện V/E trên thanh menu", #selector(toggleStatusIcon(_:)), showStatusIcon)
        return menu
    }

    // MARK: - Biểu tượng V/E

    @objc private func inputSourceChanged() {
        DispatchQueue.main.async { self.refreshStatus() }
    }

    private func ourSourceSelected() -> Bool {
        guard let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(src, kTISPropertyInputSourceID)
        else { return false }
        let id = Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
        return id.hasPrefix(Bundle.main.bundleIdentifier ?? "local.inputmethod.VietIME")
    }

    /// Chỉ hiện khi VietIME đang là nguồn nhập; đổi sang ABC thì ẩn.
    func refreshStatus() {
        guard forceStatus || (showStatusIcon && ourSourceSelected()) else {
            if let s = statusItem { NSStatusBar.system.removeStatusItem(s) }
            statusItem = nil
            return
        }
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }
        statusItem?.button?.attributedTitle = NSAttributedString(
            string: vietnamese ? "V" : "E",
            attributes: [.font: NSFont.systemFont(ofSize: 14, weight: .bold)])
        statusItem?.button?.toolTip = vietnamese ? "VietIME: tiếng Việt" : "VietIME: tiếng Anh"
        statusItem?.menu = buildMenu(target: self)
    }
}
