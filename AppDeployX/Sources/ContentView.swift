//
//  ContentView.swift
//  AppDeployX
//
//  Created by Daniel Hsieh on 2025/11/19.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers
import AppKit


struct Device: Identifiable, Hashable {
    let id: String      // UDID
    let name: String
    let osVersion: String
}

class AppState: ObservableObject {
    @Published var devices: [Device] = []
    @Published var selectedDevice: Device?
    @Published var appURL: URL? {
        didSet {
            saveLastAppURL()
            if let url = appURL {
                addRecentApp(url)
            }
        }
    }
    @Published var logText: String = ""
    @Published var isRefreshing: Bool = false
    @Published var isInstalling: Bool = false
    
    // Queue & buffer for handling logs
    private let logQueue = DispatchQueue(label: "AppDeployX.logQueue")
    private var pendingLog: String = ""
    private var isFlushScheduled: Bool = false
    // Maximum log length (adjustable as needed)
    private let maxLogLength = 20000
    
    // Currently running installation process
    private var currentInstallProcess: Process?
    
    // Recent 5 Apps
    @Published var recentAppURLs: [URL] = []

    // UserDefaults key
    private let lastAppPathKey = "LastAppBundlePath"
    private let recentAppsKey  = "RecentAppBundlePaths"
    
    // MARK: - Init
    init() {
        loadRecentApps()
        loadLastAppURL()
    }
    
    private func loadLastAppURL() {
        let defaults = UserDefaults.standard
        guard let path = defaults.string(forKey: lastAppPathKey) else { return }
        
        let url = URL(fileURLWithPath: path)
        let fm = FileManager.default
        
        if fm.fileExists(atPath: path), url.pathExtension == "app" {
            self.appURL = url
            appendLog("Loaded last selected App: \(path)")
        } else {
            defaults.removeObject(forKey: lastAppPathKey)
        }
    }
    
    private func saveLastAppURL() {
        let defaults = UserDefaults.standard
        if let url = appURL {
            defaults.set(url.path, forKey: lastAppPathKey)
        } else {
            defaults.removeObject(forKey: lastAppPathKey)
        }
    }
    
    private func loadRecentApps() {
        let defaults = UserDefaults.standard
        guard let paths = defaults.array(forKey: recentAppsKey) as? [String] else { return }
        
        let fm = FileManager.default
        let urls = paths
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0) }
            .filter { $0.pathExtension == "app" && fm.fileExists(atPath: $0.path) }
        
        self.recentAppURLs = Array(urls.prefix(5))
    }
    
    private func saveRecentApps() {
        let defaults = UserDefaults.standard
        let paths = recentAppURLs.map { $0.path }
        defaults.set(paths, forKey: recentAppsKey)
    }
    
    private func addRecentApp(_ url: URL) {
        guard url.pathExtension == "app" else { return }
        
        // Remove existing path if present
        recentAppURLs.removeAll { $0.path == url.path }
        // Insert at the beginning
        recentAppURLs.insert(url, at: 0)
        // Keep only 5 items
        if recentAppURLs.count > 5 {
            recentAppURLs = Array(recentAppURLs.prefix(5))
        }
        saveRecentApps()
    }
    
    // MARK: - Log
    
    func appendLog(_ text: String) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            self.pendingLog += text + "\n"
            
            // Schedule flush if not already scheduled
            if !self.isFlushScheduled {
                self.isFlushScheduled = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.flushPendingLog()
                }
            }
        }
    }
    
    private func flushPendingLog() {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            let chunk = self.pendingLog
            self.pendingLog = ""
            self.isFlushScheduled = false
            
            guard !chunk.isEmpty else { return }
            
            DispatchQueue.main.async {
                // Append chunk to logText
                self.logText.append(contentsOf: chunk)
                
                // Keep only the last maxLogLength characters to prevent unlimited growth
                if self.logText.count > self.maxLogLength {
                    let overflow = self.logText.count - self.maxLogLength
                    let index = self.logText.index(self.logText.startIndex, offsetBy: overflow)
                    self.logText.removeSubrange(self.logText.startIndex..<index)
                }
            }
        }
    }
    
    func clearLog() {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            self.pendingLog = ""
            self.isFlushScheduled = false
        }
        DispatchQueue.main.async {
            self.logText = ""
        }
    }
    
    // MARK: - Refresh Devices
    
    func refreshDevices() {
        isRefreshing = true
        devices.removeAll()
        selectedDevice = nil
        appendLog("=== Refresh devices ===")
        
        let process: Process
        let pipe: Pipe
        
        do {
            (process, pipe) = try makeIOSDeployProcess(["-c"])
        } catch {
            isRefreshing = false
            appendLog("ERROR: Failed to create ios-deploy process - \(error.localizedDescription)")
            return
        }
        
        process.terminationHandler = { [weak self] proc in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isRefreshing = false
                self.appendLog(output)
                self.parseDevicesFromIOSDeploy(output)
            }
        }
        
        do {
            try process.run()
        } catch {
            isRefreshing = false
            appendLog("ERROR: Failed to execute ios-deploy - \(error.localizedDescription)")
        }
    }
    
    private func parseDevicesFromIOSDeploy(_ output: String) {
        /*
         Example output line:
         [....] Found 00008120-0000795A11D8C01E (D73AP, iPhone 14 Pro, iphoneos, arm64e, 18.6.2, 22G100) a.k.a. 'iPhone' connected through USB.
         */
        
        let lines = output.components(separatedBy: .newlines)
        var parsed: [Device] = []
        
        let pattern = #"\[.*\] Found ([0-9A-Fa-f-]+) \(([^)]*)\) a\.k\.a\. '([^']*)'"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            appendLog("ERROR: Failed to create ios-deploy regex")
            return
        }
        
        for line in lines {
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)
            
            guard let match = regex.firstMatch(in: line, options: [], range: range),
                  match.numberOfRanges == 4 else { continue }
            
            let udid = nsLine.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            
            let info = nsLine.substring(with: match.range(at: 2))
            // Parentheses contain: hardware ID, model name, platform, arch, OS version, build...
            let parts = info.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let modelName = parts.count >= 2 ? parts[1] : "Unknown Device"
            let osVersion = parts.count >= 5 ? parts[4] : "unknownOS"
            
            // Alias name after "a.k.a." (actual device name)
            let aliasName = nsLine.substring(with: match.range(at: 3))
            
            // Use alias as the primary display name
            let displayName = aliasName.isEmpty ? modelName : aliasName
            
            let device = Device(id: udid, name: displayName, osVersion: osVersion)
            parsed.append(device)
        }
        
        devices = parsed
        if let first = parsed.first {
            selectedDevice = first
        }
        
        if parsed.isEmpty {
            appendLog("No physical devices found.")
        } else {
            appendLog("Found \(parsed.count) device(s).")
        }
    }
    
    private func parseDevices(from output: String) {
        // Typical line format: iPhone 15 Pro (17.0) (00008110-0012345678901234)
        let lines = output.components(separatedBy: .newlines)
        
        var parsed: [Device] = []
        
        let pattern = #"^(.*?) \((.*?)\) \(([0-9A-Fa-f-]{8,})\)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            appendLog("ERROR: Failed to create regex")
            return
        }
        
        for line in lines {
            // Exclude simulators
            if line.contains("Simulator") { continue }
            if !(line.contains("iPhone") || line.contains("iPad") || line.contains("iPod")) {
                continue
            }
            
            let range = NSRange(location: 0, length: (line as NSString).length)
            if let match = regex.firstMatch(in: line, options: [], range: range),
               match.numberOfRanges == 4 {
                let name = (line as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                let os = (line as NSString).substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)
                let udid = (line as NSString).substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespaces)
                
                let device = Device(id: udid, name: name, osVersion: os)
                parsed.append(device)
            }
        }
        
        DispatchQueue.main.async {
            self.devices = parsed
            if let first = parsed.first {
                self.selectedDevice = first
            }
            if parsed.isEmpty {
                self.appendLog("No physical devices found.")
            } else {
                self.appendLog("Found \(parsed.count) device(s).")
            }
        }
    }
    
    private func makeIOSDeployProcess(_ arguments: [String]) throws -> (Process, Pipe) {
        
        let possiblePaths = [
            "/opt/homebrew/bin/ios-deploy",   // Apple Silicon
            "/usr/local/bin/ios-deploy"       // Intel
        ]
        
        let fm = FileManager.default
        let launchPath = possiblePaths.first(where: { fm.fileExists(atPath: $0) })
        
        guard let resolvedPath = launchPath else {
            appendLog("⚠️ ios-deploy not found")
            appendLog("Please install via Homebrew:")
            appendLog("    brew install ios-deploy")
            throw NSError(domain: "AppDeployX", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "ios-deploy not found"
            ])
        }
        
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: resolvedPath)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError  = pipe
        
        return (process, pipe)
    }
    
    // MARK: - Open Build Folder
    
    func openBuildFolder() {
        let fm = FileManager.default
        
        if let appURL = appURL {
            // If .app is selected, open the folder containing it
            let folderURL = appURL.deletingLastPathComponent()
            NSWorkspace.shared.activateFileViewerSelecting([folderURL])
            appendLog("Opening folder containing App: \(folderURL.path)")
        } else {
            // If no .app selected, open Xcode DerivedData root
            let derivedDataPath = ("~/Library/Developer/Xcode/DerivedData" as NSString).expandingTildeInPath
            if fm.fileExists(atPath: derivedDataPath) {
                let url = URL(fileURLWithPath: derivedDataPath, isDirectory: true)
                NSWorkspace.shared.open(url)
                appendLog("Opening Xcode DerivedData folder: \(derivedDataPath)")
            } else {
                appendLog("DerivedData folder not found: \(derivedDataPath)")
            }
        }
    }
    
    // MARK: - Install
    
    func installApp() {
        guard let appURL = appURL else {
            appendLog("Please select an .app file first.")
            return
        }
        guard let device = selectedDevice else {
            appendLog("Please select a device first.")
            return
        }
        
        isInstalling = true
        appendLog("=== Install to \(device.name) [\(device.id)] ===")
        appendLog("App: \(appURL.path)")
        
        let (process, pipe): (Process, Pipe)
        do {
            (process, pipe) = try makeIOSDeployProcess([
                "--id", device.id,
                "--bundle", appURL.path,
                "--no-wifi"
            ])
        } catch {
            isInstalling = false
            appendLog("ERROR: Failed to create ios-deploy process - \(error.localizedDescription)")
            return
        }
        currentInstallProcess = process
        
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { return }
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                self?.appendLog(text.trimmingCharacters(in: .newlines))
            }
        }
        
        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                self?.isInstalling = false
                self?.currentInstallProcess = nil
                self?.appendLog("=== Install finished, exitCode = \(proc.terminationStatus) ===")
            }
        }
        
        do {
            try process.run()
        } catch {
            isInstalling = false
            appendLog("ERROR: Failed to execute ios-deploy - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cancel Install
    
    func cancelInstall() {
        guard let process = currentInstallProcess else {
            appendLog("No installation in progress to cancel.")
            return
        }
        
        appendLog("=== Cancel install requested ===")
        
        if process.isRunning {
            process.terminate()   // Send SIGTERM to ios-deploy
        }
        
        // Update state first to avoid showing "installing" in UI
        DispatchQueue.main.async {
            self.isInstalling = false
        }
    }
    
}

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var isTargeted = false
    private let logBottomID = "LOG_BOTTOM"
    
    var body: some View {
        VStack(spacing: 0) {
            // Top section: left and right panels
            HStack(spacing: 0) {
                // Left side: device list
                deviceListView()
                    .frame(minWidth: 250)
                    .border(Color.gray.opacity(0.3))
                
                // Divider
                Divider()
                
                // Right side: App selection + installation
                appInstallView()
                    .frame(minWidth: 400)
                    .border(Color.gray.opacity(0.3))
            }
            .frame(maxHeight: .infinity)
            
            // Divider
            Divider()
            
            // Bottom section: Log view
            logView()
                .frame(height: 200)
        }
        .onAppear {
            // Auto-refresh devices on appear
            state.refreshDevices()
        }
    }
    
    // MARK: - Left Side: Device List
    
    @ViewBuilder
    private func deviceListView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Connected Devices")
                    .font(.headline)
                Spacer()
                Button {
                    state.refreshDevices()
                } label: {
                    if state.isRefreshing {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Refresh")
                    }
                }
                .disabled(state.isRefreshing)
            }
            .padding([.top, .horizontal])
            
            List {
                ForEach(state.devices) { device in
                    DeviceRow(
                        device: device,
                        isSelected: state.selectedDevice?.id == device.id
                    )
                    .contentShape(Rectangle()) // Make entire row tappable
                    .onTapGesture {
                        state.selectedDevice = device
                    }
                }
            }
            .listStyle(.plain)
        }
    }
    
    // MARK: - Right Side: App Selection + Installation
    
    @ViewBuilder
    private func appInstallView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("App Bundle")
                    .font(.headline)
                Spacer()
                Button("Open Build Folder") {
                    state.openBuildFolder()
                }
            }
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isTargeted ? Color.accentColor : Color.gray.opacity(0.4),
                            style: StrokeStyle(lineWidth: 2, dash: [6]))
                
                VStack(spacing: 8) {
                    Text("Drag & drop .app file here or select from Finder")
                        .font(.subheadline)
                    
                    if let url = state.appURL {
                        // App icon
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .shadow(radius: 2)
                        
                        // File name (prominent)
                        Text(url.lastPathComponent)
                            .font(.subheadline)
                        
                        // Full path
                        Text(url.path)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    } else {
                        Text("No App selected yet")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }
            .frame(height: 140)
            
            HStack(spacing: 12) {
                Button {
                    state.installApp()
                } label: {
                    HStack {
                        if state.isInstalling {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("Install to Selected Device")
                    }
                }
                .disabled(state.isInstalling || state.appURL == nil || state.selectedDevice == nil)
                
                if state.isInstalling {
                    Button("Cancel Install") {
                        state.cancelInstall()
                    }
                    .foregroundColor(.red)
                }
            }
            
            // Recent Apps section
            if !state.recentAppURLs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent 5 Apps")
                        .font(.subheadline)
                    
                    ForEach(state.recentAppURLs, id: \.self) { url in
                        Button {
                            state.appURL = url
                            state.appendLog("Selected App (recent): \(url.path)")
                        } label: {
                            HStack(alignment: .center, spacing: 8) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(url.lastPathComponent)
                                        .font(.caption)
                                    Text(url.path)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                            }
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            
            Spacer()
        }
        .padding()
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    if let data = item as? Data,
                       let url = NSURL(absoluteURLWithDataRepresentation: data, relativeTo: nil) as URL? {
                        // Check if it's an .app file
                        if url.pathExtension == "app" {
                            DispatchQueue.main.async {
                                state.appURL = url
                                state.appendLog("Selected App: \(url.path)")
                            }
                        } else {
                            DispatchQueue.main.async {
                                state.appendLog("Dropped file is not an .app: \(url.path)")
                            }
                        }
                    }
                }
                return true
            }
        }
        return false
    }
    
    // MARK: - Bottom: Log View
    
    @ViewBuilder
    private func logView() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Log")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    state.clearLog()
                }
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(state.logText.isEmpty ? "No logs yet" : state.logText)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                        
                        // Bottom anchor for auto-scrolling
                        Color.clear
                            .frame(height: 0)
                            .id(logBottomID)
                    }
                }
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(4)
                // Auto-scroll to bottom when logText changes
                .onChange(of: state.logText, {
                    guard !state.logText.isEmpty else { return }
                    // Defer to next runloop to avoid layout conflicts
                    DispatchQueue.main.async {
                        withAnimation(nil) {
                            proxy.scrollTo(logBottomID, anchor: .bottom)
                        }
                    }
                })
            }
        }
        .padding(8)
    }
    
}

struct DeviceRow: View {
    let device: Device
    let isSelected: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .imageScale(.small)
            } else {
                Image(systemName: "circle")
                    .imageScale(.small)
                    .opacity(0.3)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.body)
                Text("iOS \(device.osVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(device.id)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
    }
}
