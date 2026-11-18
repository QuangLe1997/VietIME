import Carbon
import Cocoa
import InputMethodKit

// VietIME.app/Contents/MacOS/VietIME --register  → báo macOS có bộ gõ mới (dùng khi cài, không cần Xcode)
// VietIME.app/Contents/MacOS/VietIME --version
let args = CommandLine.arguments
if args.contains("--version") {
    print(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
    exit(0)
}
if args.contains("--register") {
    let status = TISRegisterInputSource(Bundle.main.bundleURL as CFURL)
    print(status == noErr ? "Đã đăng ký bộ gõ VietIME." : "TISRegisterInputSource lỗi \(status)")
    exit(status == noErr ? 0 : 1)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // không hiện Dock, vẫn được đặt biểu tượng trên thanh menu

let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String ?? "VietIME_1_Connection"
let server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
_ = server
_ = AppState.shared
DispatchQueue.global(qos: .utility).async { _ = EnglishWords.set }   // nạp từ điển sẵn (~80 ms)

app.run()
