import Cocoa
import InputMethodKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // không hiện Dock, vẫn được đặt biểu tượng trên thanh menu

let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String ?? "VietIME_1_Connection"
let server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
_ = server
_ = AppState.shared
DispatchQueue.global(qos: .utility).async { _ = EnglishWords.set }   // nạp từ điển sẵn (~80 ms)

app.run()
