import AppKit
import SwiftUI

@main
struct JarvisPCControlApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let controller = JarvisPCController()
    private var outsideClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "J"
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 440, height: 620)
        popover.contentViewController = NSHostingController(rootView: JarvisPCView(controller: controller))

        controller.onStatusTitleChange = { [weak self] title in
            DispatchQueue.main.async {
                self?.statusItem.button?.title = title
            }
        }
        controller.start()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hidePopover),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            hidePopover()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startOutsideClickMonitor()
        }
    }

    @objc private func hidePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    private func startOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.hidePopover()
            }
        }
    }
}

struct OllamaPSResponse: Decodable {
    let models: [LoadedModel]
}

struct LoadedModel: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let size: Int64
    let size_vram: Int64?
    let expires_at: Date?
    let context_length: Int?
}

struct PCStats: Decodable {
    let host: String
    let cpuName: String
    let cpuCores: Int
    let cpuThreads: Int
    let cpuMaxClockGHz: Double
    let cpuPercent: Double
    let memUsedPercent: Double
    let memFreeGB: Double
    let memTotalGB: Double
    let gpuName: String
    let cpuTempC: Double?
    let gpuLoadPercent: Double?
    let gpuMemoryLoadPercent: Double?
    let gpuDedicatedMemoryUsedGB: Double?
    let gpuTempC: Double?
    let gpuMemoryTempC: Double?
    let gpuHotspotTempC: Double?
    let gpuPowerW: Double?
    let gpuCoreClockMHz: Double?
    let gpuMemoryClockMHz: Double?
    let driveXFreeGB: Double
    let driveXTotalGB: Double
    let uptimeHours: Double
}

@MainActor
final class JarvisPCController: ObservableObject {
    @Published var isOnline = false
    @Published var isBusy = false
    @Published var lastError: String?
    @Published var loadedModels: [LoadedModel] = []
    @Published var pcStats: PCStats?
    @Published var lastUpdated: Date?
    @Published var wakeStatus: String?
    @Published var actionStatus: String?

    var onStatusTitleChange: ((String) -> Void)?

    private let pcHost = "100.117.254.71"
    private let sshHost = "jarvis-pc"
    private let modelName = "qwen3:14b"
    private var timer: Timer?

    func start() {
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func refresh() async {
        isBusy = true
        defer { isBusy = false }

        do {
            let models = try await fetchOllamaPS()
            loadedModels = models
            isOnline = true
            lastError = nil

            do {
                pcStats = try await fetchPCStats()
            } catch {
                pcStats = nil
                lastError = "PC stats unavailable: \(shortError(error))"
            }

            lastUpdated = Date()
            updateMenuTitle()
        } catch {
            isOnline = false
            loadedModels = []
            pcStats = nil
            lastError = shortError(error)
            lastUpdated = Date()
            updateMenuTitle()
        }
    }

    func warmModel() async {
        await runModelAction(keepAlive: "12h", prompt: "Reply with OK only.")
        await refresh()
    }

    func offloadModel() async {
        isBusy = true
        defer { isBusy = false }

        do {
            let models = try await fetchOllamaPS()
            let names = models.isEmpty ? [modelName] : models.map(\.name)
            for name in names {
                try await unloadModel(name)
            }
            lastError = nil
        } catch {
            lastError = shortError(error)
        }
        await refresh()
    }

    func wakePC() async {
        isBusy = true
        wakeStatus = "Sending wake packet..."
        defer { isBusy = false }

        do {
            let output = try await runProcess(
                "/Users/georgekarangioules/.local/bin/jarvis-pc-wake",
                arguments: [],
                timeout: 8
            )
            wakeStatus = output.isEmpty ? "Wake packet sent" : output
            lastError = nil
        } catch {
            wakeStatus = nil
            lastError = "Wake failed: \(shortError(error))"
        }
    }

    func sleepJarvisVoice() async {
        isBusy = true
        actionStatus = "Stopping Jarvis voice/TTS..."
        defer { isBusy = false }

        do {
            let output = try await runProcess(
                "/Users/georgekarangioules/.local/bin/jarvis-pc-sleep-voice",
                arguments: [],
                timeout: 20
            )
            actionStatus = output.isEmpty ? "Jarvis voice/TTS asleep." : output
            lastError = nil
            await refresh()
        } catch {
            actionStatus = nil
            lastError = "Sleep Jarvis failed: \(shortError(error))"
        }
    }

    func startJarvisVoice() async {
        isBusy = true
        actionStatus = "Starting Jarvis voice/TTS..."
        defer { isBusy = false }

        do {
            let output = try await runProcess(
                "/Users/georgekarangioules/.local/bin/jarvis-pc-start-voice",
                arguments: [],
                timeout: 45
            )
            actionStatus = output.isEmpty ? "Jarvis voice/TTS awake." : output
            lastError = nil
            await refresh()
        } catch {
            actionStatus = nil
            lastError = "Start voice failed: \(shortError(error))"
        }
    }

    func openRemoteDesktop() {
        NSWorkspace.shared.open(URL(string: "https://remotedesktop.google.com/access")!)
    }

    func openTerminalSSH() {
        let script = """
        tell application "Terminal"
            activate
            do script "ssh jarvis-pc"
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    private func fetchOllamaPS() async throws -> [LoadedModel] {
        let url = URL(string: "http://\(pcHost):11434/api/ps")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 4

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw RuntimeError("Ollama did not return OK")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601WithFractionalSeconds
        return try decoder.decode(OllamaPSResponse.self, from: data).models
    }

    private func fetchPCStats() async throws -> PCStats {
        let output = try await runProcess(
            "/Users/georgekarangioules/.local/bin/jarvis-pc-stats",
            arguments: [],
            timeout: 10
        )
        guard let data = output.data(using: .utf8) else {
            throw RuntimeError("Could not decode PC stats")
        }
        return try JSONDecoder().decode(PCStats.self, from: data)
    }

    private func runModelAction(keepAlive: String, prompt: String) async {
        isBusy = true
        defer { isBusy = false }

        do {
            let url = URL(string: "http://\(pcHost):11434/api/generate")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 180
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let payload: [String: Any] = [
                "model": modelName,
                "prompt": prompt,
                "stream": false,
                "keep_alive": keepAlive,
                "options": ["num_predict": 4]
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            _ = try await URLSession.shared.data(for: request)
            lastError = nil
        } catch {
            lastError = shortError(error)
        }
    }

    private func unloadModel(_ name: String) async throws {
        let url = URL(string: "http://\(pcHost):11434/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "model": name,
            "stream": false,
            "keep_alive": 0
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw RuntimeError("Ollama did not unload \(name)")
        }
    }

    private func updateMenuTitle() {
        onStatusTitleChange?("J")
    }

    private func shortError(_ error: Error) -> String {
        let text = String(describing: error)
        return text.count > 180 ? String(text.prefix(180)) + "..." : text
    }
}

struct JarvisPCView: View {
    @ObservedObject var controller: JarvisPCController

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    ollamaCard
                    pcStatsCard
                    controls
                    actionStatusPanel
                    wakeStatusPanel
                    errorPanel
                }
                .padding(16)
            }
        }
        .frame(width: 440, height: 620)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Jarvis PC")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(controller.pcStats?.host ?? "GEORGEKGAMING")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            Spacer()
            StatusPill(isOnline: controller.isOnline, isBusy: controller.isBusy)
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(Circle().fill(Color.red.opacity(0.9)))
        }
    }

    private var ollamaCard: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Ollama", icon: "brain.head.profile")

                if controller.loadedModels.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: controller.isOnline ? "snowflake" : "wifi.slash")
                            .foregroundStyle(controller.isOnline ? .blue : .red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(controller.isOnline ? "No model loaded" : "Not reachable")
                                .font(.system(size: 15, weight: .semibold))
                            Text(controller.isOnline ? "Press Warm to load qwen3:14b." : "Check Tailscale, PC power, or Ollama.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    ForEach(controller.loadedModels) { model in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.name)
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                    if let expires = model.expires_at {
                                        Text("Warm until \(expires.formatted(date: .omitted, time: .shortened))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(formatBytes(model.size_vram ?? model.size))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.green.opacity(0.14)))
                            }
                            if let context = model.context_length {
                                Label("\(context) context", systemImage: "rectangle.and.text.magnifyingglass")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var pcStatsCard: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Remote PC", icon: "desktopcomputer")

                if let stats = controller.pcStats {
                    VStack(spacing: 10) {
                        MetricBar(
                            title: "CPU",
                            value: "\(fmt(stats.cpuPercent))%",
                            progress: stats.cpuPercent / 100,
                            tint: .cyan,
                            detail: "\(stats.cpuCores)c/\(stats.cpuThreads)t · \(shortCPUName(stats.cpuName))"
                        )
                        MetricBar(
                            title: "Memory",
                            value: "\(fmt(stats.memUsedPercent))%",
                            progress: stats.memUsedPercent / 100,
                            tint: .orange,
                            detail: "\(fmt(stats.memFreeGB)) / \(fmt(stats.memTotalGB)) GB free"
                        )
                        MetricBar(
                            title: "GPU",
                            value: "\(fmt(stats.gpuLoadPercent ?? 0))%",
                            progress: (stats.gpuLoadPercent ?? 0) / 100,
                            tint: .purple,
                            detail: gpuDetail(stats)
                        )
                        MetricBar(
                            title: "X: Drive",
                            value: "\(fmt(diskUsedPercent(stats)))%",
                            progress: diskUsedPercent(stats) / 100,
                            tint: .green,
                            detail: "\(fmt(stats.driveXFreeGB)) / \(fmt(stats.driveXTotalGB)) GB free"
                        )
                    }

                    Divider().opacity(0.45)

                    HStack(spacing: 8) {
                        InfoChip(icon: "thermometer.medium", title: "GPU Temp", value: tempSummary(stats), compact: true)
                        InfoChip(icon: "bolt.fill", title: "GPU Power", value: stats.gpuPowerW.map { "\(fmt($0)) W" } ?? "-")
                    }

                    HStack(spacing: 8) {
                        InfoChip(icon: "cpu", title: "GPU", value: shortGPUName(stats.gpuName))
                        InfoChip(icon: "clock", title: "Uptime", value: "\(fmt(stats.uptimeHours))h")
                    }
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Stats unavailable")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var errorPanel: some View {
        Group {
            if let error = controller.lastError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Connection issue")
                            .font(.caption.weight(.semibold))
                        Text(friendlyError(error))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.08)))
            } else if let date = controller.lastUpdated {
                Text("Updated \(date.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ControlButton(title: "Refresh", icon: "arrow.clockwise") {
                    Task { await controller.refresh() }
                }
                ControlButton(title: "Warm", icon: "flame.fill") {
                    Task { await controller.warmModel() }
                }
                ControlButton(title: "Offload", icon: "power") {
                    Task { await controller.offloadModel() }
                }
            }
            .disabled(controller.isBusy)

            HStack(spacing: 10) {
                ControlButton(title: "Wake", icon: "power.circle.fill") {
                    Task { await controller.wakePC() }
                }
                ControlButton(title: "Remote Desktop", icon: "display") {
                    controller.openRemoteDesktop()
                }
                ControlButton(title: "SSH", icon: "terminal") {
                    controller.openTerminalSSH()
                }
            }

            HStack(spacing: 10) {
                ControlButton(title: "Sleep Jarvis", icon: "moon.zzz.fill") {
                    Task { await controller.sleepJarvisVoice() }
                }
                ControlButton(title: "Start Voice", icon: "waveform") {
                    Task { await controller.startJarvisVoice() }
                }
            }
            .disabled(controller.isBusy)
        }
    }

    private var actionStatusPanel: some View {
        Group {
            if let actionStatus = controller.actionStatus {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(actionStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.08)))
            }
        }
    }

    private var wakeStatusPanel: some View {
        Group {
            if let wakeStatus = controller.wakeStatus {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "power.circle.fill")
                        .foregroundStyle(.green)
                    Text(wakeStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.08)))
            }
        }
    }
}

struct DashboardCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

struct StatusPill: View {
    let isOnline: Bool
    let isBusy: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isOnline ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(isBusy ? "Syncing" : (isOnline ? "Online" : "Offline"))
                .font(.system(size: 12, weight: .bold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill((isOnline ? Color.green : Color.red).opacity(0.15)))
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
                .font(.system(size: 15, weight: .bold))
            Spacer()
        }
    }
}

struct MetricBar: View {
    let title: String
    let value: String
    let progress: Double
    let tint: Color
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: max(6, proxy.size.width * min(max(progress, 0), 1)))
                }
            }
            .frame(height: 8)

            Text(detail)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

struct InfoChip: View {
    let icon: String
    let title: String
    let value: String
    var compact = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: compact ? 11 : 12, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.10)))
    }
}

struct ControlButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
        }
        .buttonStyle(.bordered)
    }
}

func diskUsedPercent(_ stats: PCStats) -> Double {
    guard stats.driveXTotalGB > 0 else { return 0 }
    return ((stats.driveXTotalGB - stats.driveXFreeGB) / stats.driveXTotalGB) * 100
}

func gpuDetail(_ stats: PCStats) -> String {
    var parts: [String] = []
    if let used = stats.gpuDedicatedMemoryUsedGB {
        parts.append("\(fmt(used)) GB VRAM")
    }
    if let memLoad = stats.gpuMemoryLoadPercent {
        parts.append("\(fmt(memLoad))% memory load")
    }
    if let core = stats.gpuCoreClockMHz, core > 0 {
        parts.append("\(Int(core)) MHz core")
    }
    if let memory = stats.gpuMemoryClockMHz, memory > 0 {
        parts.append("\(Int(memory)) MHz mem")
    }
    return parts.isEmpty ? stats.gpuName : parts.joined(separator: " · ")
}

func tempSummary(_ stats: PCStats) -> String {
    var parts: [String] = []
    if let core = stats.gpuTempC {
        parts.append("Core \(fmt(core))°")
    }
    if let hotspot = stats.gpuHotspotTempC {
        parts.append("Hot \(fmt(hotspot))°")
    }
    if let memory = stats.gpuMemoryTempC {
        parts.append("Mem \(fmt(memory))°")
    }
    if parts.isEmpty, let cpu = stats.cpuTempC {
        parts.append("CPU \(fmt(cpu))°")
    }
    return parts.isEmpty ? "-" : parts.joined(separator: " · ")
}

func shortCPUName(_ name: String) -> String {
    name
        .replacingOccurrences(of: "AMD Ryzen 7 ", with: "Ryzen 7 ")
        .replacingOccurrences(of: " 8-Core Processor", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func shortGPUName(_ name: String) -> String {
    name
        .replacingOccurrences(of: "AMD Radeon ", with: "Radeon ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func friendlyError(_ error: String) -> String {
    if error.contains("NSURLErrorDomain Code=-1022") {
        return "macOS blocked the local HTTP request. Relaunch the updated app."
    }
    if error.lowercased().contains("timed out") {
        return "The PC did not respond quickly. Check Tailscale, power, or Ollama."
    }
    return error
}

struct RuntimeError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) {
        self.description = description
    }
}

func formatBytes(_ bytes: Int64) -> String {
    let gb = Double(bytes) / 1_000_000_000
    return String(format: "%.1f GB", gb)
}

func fmt(_ value: Double) -> String {
    String(format: "%.1f", value)
}

func runProcess(_ executable: String, arguments: [String], timeout: TimeInterval) async throws -> String {
    try await Task.detached {
        let process = Process()
        let output = Pipe()
        let error = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = error

        try process.run()
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
            throw RuntimeError("Process timed out after \(Int(timeout))s")
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: data, encoding: .utf8) ?? ""
        let stderr = String(data: errorData, encoding: .utf8) ?? ""

        if process.terminationStatus == 0 {
            return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        throw RuntimeError(stderr.isEmpty ? "Process failed" : stderr)
    }.value
}

extension JSONDecoder.DateDecodingStrategy {
    static let iso8601WithFractionalSeconds = custom { decoder in
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
    }
}
