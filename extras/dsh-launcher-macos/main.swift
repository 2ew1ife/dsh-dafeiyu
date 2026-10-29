import AppKit
import WebKit
import Darwin

final class Launcher: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate {
    var window: NSWindow!
    var web: WKWebView!
    var status: NSTextField!
    var overlay: NSView!
    var process: Process?
    var pipe: Pipe?
    var buffer = ""
    var loaded = false
    var quitting = false
    var timeout: DispatchWorkItem?
    let origin = "http://127.0.0.1:3080"

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let appItem = NSMenuItem(); menu.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "关于 DSH 启动器", action: #selector(about), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 DSH 启动器", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(); menu.addItem(editItem)
        let editMenu = NSMenu(title: "编辑"); editItem.submenu = editMenu
        for (label, action, key) in [("撤销", "undo:", "z"), ("剪切", "cut:", "x"), ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            editMenu.addItem(withTitle: label, action: Selector(action), keyEquivalent: key)
        }
        let viewItem = NSMenuItem(); menu.addItem(viewItem)
        let viewMenu = NSMenu(title: "窗口"); viewItem.submenu = viewMenu
        viewMenu.addItem(withTitle: "刷新 DSH", action: #selector(reload), keyEquivalent: "r")
        viewMenu.addItem(withTitle: "显示主窗口", action: #selector(showWindow), keyEquivalent: "0")
        NSApp.mainMenu = menu
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1160, height: 780), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "DeepSeek Harness · DSH"
        window.minSize = NSSize(width: 760, height: 540)
        window.isReleasedWhenClosed = false
        window.center()
        let configuration = WKWebViewConfiguration()
        web = WKWebView(frame: window.contentView!.bounds, configuration: configuration)
        web.autoresizingMask = [.width, .height]
        web.navigationDelegate = self; web.uiDelegate = self
        window.contentView!.addSubview(web)
        overlay = NSView(frame: window.contentView!.bounds)
        overlay.autoresizingMask = [.width, .height]
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor(calibratedRed: 0.094, green: 0.059, blue: 0.094, alpha: 1).cgColor
        let heading = NSTextField(labelWithString: "DSH")
        heading.font = .systemFont(ofSize: 34, weight: .semibold); heading.textColor = .white
        status = NSTextField(wrappingLabelWithString: "正在启动 DeepSeek Harness…")
        status.textColor = NSColor(calibratedWhite: 0.85, alpha: 1); status.alignment = .center
        status.preferredMaxLayoutWidth = 500
        let retry = NSButton(title: "重新启动", target: self, action: #selector(retryStart))
        let stack = NSStackView(views: [heading, status, retry]); stack.orientation = .vertical; stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(stack)
        NSLayoutConstraint.activate([stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor), stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor), stack.widthAnchor.constraint(lessThanOrEqualToConstant: 540)])
        window.contentView!.addSubview(overlay)
        showWindow()
        start()
    }

    @objc func about() {
        let alert = NSAlert(); alert.messageText = "DSH 独立启动器"
        alert.informativeText = "本机启动器使用系统 AppKit / WebKit，承载已安装的 DeepSeek Harness。\nDeepSeek Harness 归 DeepSeek 原作者；桌宠基于 QCYTSN/dsh-dafeiyu，启动主题基于 KylinQ01/dsh-startup-animation。\n此启动器为额外适配，非官方桌面客户端。"
        alert.runModal()
    }
    @objc func showWindow() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func reload() { if loaded { web.reload() } }
    @objc func retryStart() {
        guard process?.isRunning != true else { status.stringValue = "DSH 仍在启动，请稍候。若长时间无响应，请退出启动器后重开。"; return }
        start()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }

    func nativeModuleDirectory(_ home: URL) -> String? {
        let root = home.appendingPathComponent("Library/pnpm/store/v11/links/@/node-addon-require-builtin")
        let fm = FileManager.default
        for version in (try? fm.contentsOfDirectory(atPath: root.path)) ?? [] {
            let versionURL = root.appendingPathComponent(version)
            for hash in (try? fm.contentsOfDirectory(atPath: versionURL.path)) ?? [] {
                let modules = versionURL.appendingPathComponent(hash).appendingPathComponent("node_modules")
                if fm.fileExists(atPath: modules.appendingPathComponent("node-addon-require-builtin-darwin-arm64").path) { return modules.path }
            }
        }
        return nil
    }
    func start() {
        loaded = false; buffer = ""; overlay.isHidden = false
        status.stringValue = "正在启动 DSH 和狂三桌宠…"
        let home = FileManager.default.homeDirectoryForCurrentUser
        let executable = home.appendingPathComponent("Library/pnpm/bin/dsh")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else { status.stringValue = "没有找到已安装的 DSH。请先完成 DSH 安装。"; return }
        let child = Process(); let output = Pipe()
        var environment = ProcessInfo.processInfo.environment
        environment["PNPM_HOME"] = home.appendingPathComponent("Library/pnpm").path
        environment["PATH"] = home.appendingPathComponent("Library/pnpm/bin").path + ":/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        if let modules = nativeModuleDirectory(home) { environment["NODE_PATH"] = modules }
        environment["NO_COLOR"] = "1"
        child.executableURL = executable
        child.arguments = ["web", "--no-open", "--host", "127.0.0.1", "--port", "3080"]
        child.environment = environment; child.currentDirectoryURL = home
        child.standardOutput = output; child.standardError = output
        process = child; pipe = output
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = String(decoding: data, as: UTF8.self)
            DispatchQueue.main.async { self?.receive(text) }
        }
        child.terminationHandler = { [weak self] exited in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.timeout?.cancel()
                self.pipe?.fileHandleForReading.readabilityHandler = nil
                if self.quitting { NSApp.reply(toApplicationShouldTerminate: true); return }
                self.overlay.isHidden = false
                self.status.stringValue = "DSH 已停止（退出码 \(exited.terminationStatus)）。如原终端还在运行 DSH，请先在该终端按 Control+C，再点重新启动。"
            }
        }
        do { try child.run() } catch { status.stringValue = "DSH 启动失败，请检查本机安装后重试。"; return }
        let task = DispatchWorkItem { [weak self] in
            guard let self = self, !self.loaded else { return }
            self.status.stringValue = "DSH 启动时间较长。若此前已在终端打开 DSH，请关闭旧服务后重开启动器。"
        }
        timeout = task; DispatchQueue.main.asyncAfter(deadline: .now() + 90, execute: task)
    }
    func receive(_ text: String) {
        guard !loaded else { return }
        buffer += text
        if buffer.count > 131072 { buffer = String(buffer.suffix(65536)) }
        let lines = buffer.components(separatedBy: .newlines)
        for line in lines {
            guard let range = line.range(of: "dsh web: http://127.0.0.1:3080") else { continue }
            let raw = String(line[range.lowerBound...].dropFirst("dsh web: ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: raw), url.scheme == "http", url.host == "127.0.0.1", url.port == 3080, url.user == nil, url.password == nil else { continue }
            loaded = true; buffer = ""; timeout?.cancel()
            // The private process URL stays in memory and WKWebView; never log it.
            web.load(URLRequest(url: url))
            return
        }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { overlay.isHidden = true }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        overlay.isHidden = false; status.stringValue = "窗口连接暂时失败，可从菜单「窗口 → 刷新 DSH」重试。"
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        if url.scheme == "http", url.host == "127.0.0.1", url.port == 3080, url.user == nil, url.password == nil { decisionHandler(.allow); return }
        if action.navigationType == .linkActivated, ["https", "http"].contains(url.scheme ?? "") { NSWorkspace.shared.open(url) }
        decisionHandler(.cancel)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url {
            if url.host == "127.0.0.1", url.port == 3080 { webView.load(URLRequest(url: url)) }
            else if url.scheme == "https" { NSWorkspace.shared.open(url) }
        }
        return nil
    }
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.beginSheetModal(for: window) { result in completionHandler(result == .OK ? panel.urls : nil) }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let child = process, child.isRunning else { return .terminateNow }
        quitting = true; timeout?.cancel(); child.terminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            if child.isRunning { kill(child.processIdentifier, SIGKILL) }
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
let application = NSApplication.shared
let delegate = Launcher()
application.setActivationPolicy(.regular)
application.delegate = delegate
application.run()
