# VietIME — bộ gõ tiếng Việt Telex/VNI cho macOS

Bộ gõ InputMethodKit tự viết, ~600 dòng Swift, không phụ thuộc thư viện ngoài.

**Vì sao không lỗi như bộ gõ khác:** EVKey/OpenKey sửa chữ bằng cách gửi phím Backspace
giả rồi gõ lại; app Electron/Chrome/Telegram xử lý phím chậm nên hay nhân đôi hoặc mất chữ.
VietIME giữ từ đang gõ ở dạng chữ tạm (marked text) và chỉ chèn một lần khi hết từ.

## Cài

```bash
make install
```

Rồi System Settings → Keyboard → Input Sources → Edit… → **+** → Vietnamese → **VietIME**.
Lần đầu chưa thấy thì đăng xuất/đăng nhập lại. Gỡ: `make uninstall`.

## Dùng

- Telex: `s f r x j` dấu thanh, `z` xoá dấu, `aa ee oo` mũ, `aw ow uw` / `w` → ă ơ ư, `dd` → đ.
- VNI: `1–5` dấu thanh, `0` xoá dấu, `6` mũ, `7` móc, `8` trăng, `9` đ.
- Gõ lặp để huỷ: `ass` → as, `aaa` → aa. **Esc** trả nguyên phím đã gõ của từ đang gõ.
- Từ không phải tiếng Việt (windows, class, hello) tự giữ nguyên.
- **Chuyển Anh ↔ Việt:** bấm rồi thả **⌃⇧** (Control + Shift), mặc định. Đổi sang ⌘⇧ hoặc ⌥Z
  trong menu. Phím tắt chỉ tắt bỏ dấu, không đổi nguồn nhập (⌃Space của macOS thì đổi nguồn nhập).
- **Thanh menu:** chữ **V** (đang gõ Việt) / **E** (đang gõ Anh), bấm vào ra menu: bật/tắt tiếng Việt,
  Telex/VNI, phím tắt, kiểu bỏ dấu cũ/mới, tự khôi phục, gạch chân, ẩn/hiện chữ V/E.
  Chỉ hiện khi VietIME là nguồn nhập đang chọn. Menu này cũng có ở biểu tượng nguồn nhập của macOS.

## Phát triển

```bash
make test    # engine, không cần cài
make build   # build/VietIME.app (arm64 + x86_64, ký ad-hoc)
```

`Sources/VietEngine.swift` là phần xử lý thuần; `InputController.swift` nối với InputMethodKit.
Sau khi sửa code: `make install` (tự kill tiến trình cũ).
