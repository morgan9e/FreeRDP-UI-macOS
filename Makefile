UNAME_S := $(shell uname -s)

APP_NAME  := RDPConnect
BUNDLE_ID := com.example.RDPConnect
VERSION   := 1.0

PREFIX    ?= $(HOME)/.local
BINDIR    ?= $(PREFIX)/bin
DATADIR   ?= $(PREFIX)/share
APPDIR    ?= $(HOME)/Applications
ICON_SIZE := 256x256

.ONESHELL:
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

ifeq ($(UNAME_S),Darwin)
all: macos
else
all: linux
endif

macos: $(APP_NAME).app

$(APP_NAME).app: main.swift
	swiftc -O -parse-as-library -o $(APP_NAME) main.swift
	rm -rf $(APP_NAME).app
	mkdir -p $(APP_NAME).app/Contents/MacOS $(APP_NAME).app/Contents/Resources
	mv $(APP_NAME) $(APP_NAME).app/Contents/MacOS/$(APP_NAME)
	ICON_KEY=""
	if [ -f AppIcon.icns ]; then
		cp AppIcon.icns $(APP_NAME).app/Contents/Resources/AppIcon.icns
		ICON_KEY="    <key>CFBundleIconFile</key>        <string>AppIcon</string>"
	fi
	cat > $(APP_NAME).app/Contents/Info.plist <<-PLIST
	<?xml version="1.0" encoding="UTF-8"?>
	<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
	<plist version="1.0">
	<dict>
	    <key>CFBundleName</key>            <string>RDPConnect</string>
	    <key>CFBundleDisplayName</key>     <string>RDPConnect</string>
	    <key>CFBundleIdentifier</key>      <string>$(BUNDLE_ID)</string>
	    <key>CFBundleExecutable</key>      <string>$(APP_NAME)</string>
	$$ICON_KEY
	    <key>CFBundlePackageType</key>     <string>APPL</string>
	    <key>CFBundleShortVersionString</key> <string>$(VERSION)</string>
	    <key>CFBundleVersion</key>         <string>$(VERSION)</string>
	    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
	    <key>LSApplicationCategoryType</key> <string>public.app-category.utilities</string>
	    <key>NSHighResolutionCapable</key> <true/>
	</dict>
	</plist>
	PLIST
	codesign --force --identifier "$(BUNDLE_ID)" --sign - $(APP_NAME).app

linux: rdpconnect

rdpconnect: main.vala
	valac --pkg gtk4 --pkg libadwaita-1 --pkg libsecret-1 --pkg json-glib-1.0 --pkg posix \
	      -X -O2 -X -w \
	      -o rdpconnect main.vala

ifeq ($(UNAME_S),Darwin)
install: macos
	mkdir -p "$(APPDIR)"
	rm -rf "$(APPDIR)/$(APP_NAME).app"
	cp -R $(APP_NAME).app "$(APPDIR)/$(APP_NAME).app"

uninstall:
	rm -rf "$(APPDIR)/$(APP_NAME).app"
else
install: linux
	install -Dm755 rdpconnect "$(BINDIR)/rdpconnect"
	install -Dm644 com.example.RDPConnect.desktop "$(DATADIR)/applications/$(BUNDLE_ID).desktop"
	install -Dm644 icon.png "$(DATADIR)/icons/hicolor/$(ICON_SIZE)/apps/rdpconnect.png"
	update-desktop-database "$(DATADIR)/applications" 2>/dev/null || true
	gtk-update-icon-cache -f -t "$(DATADIR)/icons/hicolor" 2>/dev/null || true

uninstall:
	rm -f "$(BINDIR)/rdpconnect"
	rm -f "$(DATADIR)/applications/$(BUNDLE_ID).desktop"
	rm -f "$(DATADIR)/icons/hicolor/$(ICON_SIZE)/apps/rdpconnect.png"
	update-desktop-database "$(DATADIR)/applications" 2>/dev/null || true
endif

clean:
	rm -rf $(APP_NAME).app $(APP_NAME) rdpconnect

.PHONY: all macos linux install uninstall clean
