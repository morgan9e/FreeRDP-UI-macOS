import SwiftUI
import AppKit
import Security

extension String: @retroactive Error {}

enum DisplayMode: String, Codable, CaseIterable, Identifiable {
    case fixed
    case dynamic
    case scale

    var id: String { rawValue }
    var label: String {
        switch self {
        case .fixed:   return "Fixed size"
        case .dynamic: return "Dynamic resolution"
        case .scale:   return "Scale to fit"
        }
    }
}

struct Connection: Codable, Equatable {
    var host = ""
    var port = "3389"
    var username = ""
    var password = ""
    var domain = ""

    var resolution = "1280x800"
    var displayMode = DisplayMode.dynamic
    var scale = 100
    var serverScale = 100
    var multiMonitor = false

    var ignoreCert = true
    var clipboard = true
    var audio = true
    var microphone = false
    var driveRedirect = false

    var extraArgs = ""

    static let resolutionPresets = [
        "Fullscreen", "2560x1440", "1920x1080", "1600x900",
        "1440x900", "1280x800", "1280x720", "1024x768",
    ]

    static let scaleValues = [100, 125, 133, 150, 166, 175, 200]

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func s(_ k: CodingKeys, _ d: String) -> String { (try? c.decode(String.self, forKey: k)) ?? d }
        func b(_ k: CodingKeys, _ d: Bool) -> Bool { (try? c.decode(Bool.self, forKey: k)) ?? d }
        func i(_ k: CodingKeys, _ d: Int) -> Int { (try? c.decode(Int.self, forKey: k)) ?? d }
        host = s(.host, "")
        port = s(.port, "3389")
        username = s(.username, "")
        password = s(.password, "")
        domain = s(.domain, "")
        resolution = s(.resolution, "1280x800")
        displayMode = (try? c.decode(DisplayMode.self, forKey: .displayMode)) ?? .dynamic
        scale = i(.scale, 100)
        serverScale = i(.serverScale, 100)
        multiMonitor = b(.multiMonitor, false)
        ignoreCert = b(.ignoreCert, true)
        clipboard = b(.clipboard, true)
        audio = b(.audio, true)
        microphone = b(.microphone, false)
        driveRedirect = b(.driveRedirect, false)
        extraArgs = s(.extraArgs, "")
    }

    var showsClientScale: Bool {
        (displayMode == .scale || resolution == "Fullscreen") && displayMode != .dynamic
    }

    static func sessionPx(_ windowPx: Int, _ pct: Int) -> Int {
        (windowPx * 100 / pct) & ~1
    }

    func buildArguments(screenW: Int = 0, screenH: Int = 0) -> Result<[String], String> {
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        guard !trimmedHost.isEmpty else { return .failure("Server address is required.") }

        var args: [String] = []

        let p = port.trimmingCharacters(in: .whitespaces)
        args.append(p.isEmpty || p == "3389" ? "/v:\(trimmedHost)" : "/v:\(trimmedHost):\(p)")

        let user = username.trimmingCharacters(in: .whitespaces)
        if !user.isEmpty { args.append("/u:\(user)") }

        let dom = domain.trimmingCharacters(in: .whitespaces)
        if !dom.isEmpty { args.append("/d:\(dom)") }

        if !password.isEmpty { args.append("/p:\(password)") }

        let cpct = max(scale, 100)
        let clientScale = showsClientScale
        if resolution == "Fullscreen" {
            args.append("/f")
            if clientScale {
                if cpct > 100 && screenW > 0 && screenH > 0 {
                    args.append("/smart-sizing:\(Connection.sessionPx(screenW, cpct))x\(Connection.sessionPx(screenH, cpct))")
                } else if displayMode == .scale {
                    args.append("/smart-sizing")
                }
            }
        } else {
            let parts = resolution.split(separator: "x")
            if parts.count == 2 {
                let w = Int(parts[0]) ?? 0
                let h = Int(parts[1]) ?? 0
                args.append("/size:\(w)x\(h)")
                if clientScale {
                    if cpct > 100 {
                        args.append("/smart-sizing:\(Connection.sessionPx(w, cpct))x\(Connection.sessionPx(h, cpct))")
                    } else {
                        args.append("/smart-sizing")
                    }
                }
            }
        }
        if displayMode == .dynamic { args.append("/dynamic-resolution") }
        let spct = max(serverScale, 100)
        if spct > 100 { args.append("/scale-desktop:\(spct)") }
        if multiMonitor { args.append("/multimon") }

        if ignoreCert { args.append("/cert:ignore") }
        if clipboard { args.append("+clipboard") }
        if audio { args.append("/sound:sys:mac") }
        if microphone { args.append("/microphone") }
        if driveRedirect { args.append("/drive:home,~") }

        let extras = extraArgs.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init)
        args.append(contentsOf: extras)

        return .success(args)
    }
}

struct Favorite: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var conn: Connection
}

enum Keychain {
    static let service = "RDPConnect"

    static func set(_ password: String, for id: UUID) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
        ]
        SecItemDelete(base as CFDictionary)
        guard !password.isEmpty, let data = password.data(using: .utf8) else { return }
        var add = base
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    static func get(for id: UUID) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, let str = String(data: data, encoding: .utf8)
        else { return "" }
        return str
    }

    static func delete(for id: UUID) {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
        ] as CFDictionary)
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var conn = Connection()
    @Published var favorites: [Favorite] = []
    @Published var selectedID: UUID? = nil

    @Published var status = "Ready."
    @Published var log = ""
    @Published var isRunning = false

    private var process: Process?
    private let binary = AppState.findBinary()
    private let storeURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RDPConnect", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("favorites.json")
    }()

    init() { loadFavorites() }

    static func findBinary() -> String? {
        ["/opt/homebrew/bin/sdl-freerdp", "/usr/local/bin/sdl-freerdp",
         "/opt/homebrew/bin/sdl-freerdp3", "/usr/bin/sdl-freerdp"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func screenPixels() -> (Int, Int) {
        guard let screen = NSScreen.main else { return (0, 0) }
        let scale = screen.backingScaleFactor
        return (Int(screen.frame.width * scale), Int(screen.frame.height * scale))
    }

    func loadFavorites() {
        guard let data = try? Data(contentsOf: storeURL),
              let list = try? JSONDecoder().decode([Favorite].self, from: data) else { return }
        favorites = list
    }

    private func persistFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            try? data.write(to: storeURL)
        }
    }

    func apply(_ fav: Favorite) {
        var c = fav.conn
        c.password = Keychain.get(for: fav.id)
        conn = c
        selectedID = fav.id
        status = "Loaded “\(fav.name)”."
    }

    func newConnection() {
        conn = Connection()
        selectedID = nil
        status = "New connection."
    }

    func saveFavorite(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        var stored = conn
        let password = stored.password
        stored.password = ""

        if let idx = favorites.firstIndex(where: { $0.name == trimmed }) {
            favorites[idx].conn = stored
            Keychain.set(password, for: favorites[idx].id)
            selectedID = favorites[idx].id
        } else {
            let fav = Favorite(name: trimmed, conn: stored)
            favorites.append(fav)
            Keychain.set(password, for: fav.id)
            selectedID = fav.id
        }
        favorites.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persistFavorites()
        status = "Saved “\(trimmed)”."
    }

    func deleteSelected() {
        guard let id = selectedID, let idx = favorites.firstIndex(where: { $0.id == id }) else { return }
        let name = favorites[idx].name
        Keychain.delete(for: favorites[idx].id)
        favorites.remove(at: idx)
        persistFavorites()
        selectedID = nil
        status = "Deleted “\(name)”."
    }

    var selectedName: String? { favorites.first { $0.id == selectedID }?.name }

    private func append(_ line: String) { log += line + "\n" }

    func connect() {
        guard !isRunning else { return }
        guard let binary else {
            status = "sdl-freerdp not found."
            append("❌ sdl-freerdp not found. Install it with: brew install freerdp")
            return
        }
        let (sw, sh) = AppState.screenPixels()
        switch conn.buildArguments(screenW: sw, screenH: sh) {
        case .failure(let msg):
            status = msg
        case .success(let args):
            launch(binary: binary, args: args)
        }
    }

    private func launch(binary: String, args: [String]) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binary)
        proc.arguments = args

        let shown = args.map { $0.hasPrefix("/p:") ? "/p:••••••" : $0 }
        append("▶ \(binary) \(shown.joined(separator: " "))")

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in self.append(text.trimmingCharacters(in: .newlines)) }
        }
        proc.terminationHandler = { p in
            Task { @MainActor in
                self.isRunning = false
                self.process = nil
                pipe.fileHandleForReading.readabilityHandler = nil
                self.status = "Session ended (exit \(p.terminationStatus))."
                self.append("■ session ended (exit code \(p.terminationStatus))")
            }
        }
        do {
            try proc.run()
            process = proc
            isRunning = true
            status = "Connected to \(conn.host)."
        } catch {
            status = "Failed to launch."
            append("❌ failed to launch: \(error.localizedDescription)")
        }
    }

    func disconnect() { process?.terminate() }
}

struct ContentView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openWindow) private var openWindow

    @State private var showOptions = false
    @State private var showSaveSheet = false
    @State private var saveName = ""

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("Favorite", selection: favoriteBinding) {
                        Text("New Connection…").tag(UUID?.none)
                        if !state.favorites.isEmpty { Divider() }
                        ForEach(state.favorites) { fav in
                            Text(fav.name).tag(Optional(fav.id))
                        }
                    }
                    HStack {
                        Button("Save…") { saveName = state.selectedName ?? state.conn.host; showSaveSheet = true }
                        Button("Delete") { state.deleteSelected() }
                            .disabled(state.selectedID == nil)
                        Spacer()
                    }
                }

                Section("Connection") {
                    TextField("Server", text: $state.conn.host, prompt: Text("hostname or IP"))
                    TextField("Username", text: $state.conn.username)
                    SecureField("Password", text: $state.conn.password)
                }

                Section("Display") {
                    Picker("Resolution", selection: $state.conn.resolution) {
                        ForEach(Connection.resolutionPresets, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Mode", selection: $state.conn.displayMode) {
                        ForEach(DisplayMode.allCases) { Text($0.label).tag($0) }
                    }
                    if state.conn.showsClientScale {
                        Picker("Client-side scale", selection: $state.conn.scale) {
                            ForEach(Connection.scaleValues, id: \.self) { Text("\($0) %").tag($0) }
                        }
                    }
                    Picker("Server-side scale", selection: $state.conn.serverScale) {
                        ForEach(Connection.scaleValues, id: \.self) { Text("\($0) %").tag($0) }
                    }
                }

                Section(isExpanded: $showOptions) {
                    TextField("Port", text: $state.conn.port)
                    TextField("Domain", text: $state.conn.domain)
                    Toggle("Use all monitors", isOn: $state.conn.multiMonitor)
                    Toggle("Ignore certificate", isOn: $state.conn.ignoreCert)
                    Toggle("Share clipboard", isOn: $state.conn.clipboard)
                    Toggle("Forward audio", isOn: $state.conn.audio)
                    Toggle("Forward microphone", isOn: $state.conn.microphone)
                    Toggle("Share home folder", isOn: $state.conn.driveRedirect)
                    TextField("Extra arguments", text: $state.conn.extraArgs, prompt: Text("e.g. /gfx /rfx"))
                } header: {
                    Text("Options")
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack(spacing: 10) {
                Text(state.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Button { openWindow(id: "log") } label: {
                    Image(systemName: "text.alignleft")
                }
                .help("Show log")
                .buttonStyle(.borderless)

                if state.isRunning {
                    Button("Disconnect", role: .destructive) { state.disconnect() }
                } else {
                    Button("Connect") { state.connect() }
                        .keyboardShortcut(.return, modifiers: [])
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 420)
        .frame(minHeight: 480)
        .sheet(isPresented: $showSaveSheet) { saveSheet }
    }

    private var favoriteBinding: Binding<UUID?> {
        Binding(
            get: { state.selectedID },
            set: { newID in
                if let id = newID, let fav = state.favorites.first(where: { $0.id == id }) {
                    state.apply(fav)
                } else {
                    state.newConnection()
                }
            }
        )
    }

    private var saveSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Save Favorite").font(.headline)
            TextField("Name", text: $saveName)
                .frame(width: 240)
            HStack {
                Spacer()
                Button("Cancel") { showSaveSheet = false }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    state.saveFavorite(name: saveName)
                    showSaveSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(saveName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
    }
}

struct LogView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(state.log.isEmpty ? "No output yet." : state.log)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(8)
                        .id("logEnd")
                }
                .onChange(of: state.log) { proxy.scrollTo("logEnd", anchor: .bottom) }
            }
            Divider()
            HStack {
                Spacer()
                Button("Clear") { state.log = "" }
            }
            .padding(8)
        }
        .frame(minWidth: 480, minHeight: 320)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct RDPConnectApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var state = AppState()

    var body: some Scene {
        Window("RDPConnect", id: "main") {
            ContentView().environmentObject(state)
        }
        .windowResizability(.contentSize)

        Window("Log", id: "log") {
            LogView().environmentObject(state)
        }
        .defaultSize(width: 560, height: 360)
    }
}
