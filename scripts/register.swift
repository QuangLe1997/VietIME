// Báo cho macOS biết có bộ gõ mới ở ~/Library/Input Methods (không tự bật).
// swift scripts/register.swift <path-to-VietIME.app>
import Carbon
import Foundation

let url = URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL
let status = TISRegisterInputSource(url)
print(status == noErr ? "Đã đăng ký bộ gõ." : "TISRegisterInputSource lỗi \(status)")
