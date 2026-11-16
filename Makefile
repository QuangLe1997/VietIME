APP     := build/VietIME.app
DEST    := $(HOME)/Library/Input Methods
SOURCES := $(wildcard Sources/*.swift)

.PHONY: build test install uninstall clean

build: $(APP)

$(APP): $(SOURCES) Resources/Info.plist scripts/make-icon.swift
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	swiftc -O -target arm64-apple-macos12 $(SOURCES) -o build/VietIME-arm64
	swiftc -O -target x86_64-apple-macos12 $(SOURCES) -o build/VietIME-x86_64
	lipo -create build/VietIME-arm64 build/VietIME-x86_64 -output $(APP)/Contents/MacOS/VietIME
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	swift scripts/make-icon.swift $(APP)/Contents/Resources/icon.tiff
	codesign --force --sign - $(APP)

test:
	mkdir -p build
	swiftc Sources/VietEngine.swift Tests/main.swift -o build/tests
	./build/tests

install: build
	-pkill -x VietIME
	rm -rf "$(DEST)/VietIME.app"
	mkdir -p "$(DEST)"
	cp -R $(APP) "$(DEST)/"
	swift scripts/register.swift "$(DEST)/VietIME.app"
	@echo ""
	@echo "Xong. Vào System Settings → Keyboard → Input Sources → Edit… → + → Vietnamese → VietIME."
	@echo "Lần đầu nếu chưa thấy thì đăng xuất/đăng nhập lại."

uninstall:
	-pkill -x VietIME
	rm -rf "$(DEST)/VietIME.app"

clean:
	rm -rf build
