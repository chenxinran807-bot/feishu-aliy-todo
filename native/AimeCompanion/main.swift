import AppKit
import WebKit

final class NativeBridge: NSObject, WKScriptMessageHandler {
    weak var window: NSWindow?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard
            message.name == "aimeNative",
            let body = message.body as? [String: Any],
            let command = body["command"] as? String
        else {
            return
        }

        switch command {
        case "setWindowMode":
            let mode = body["mode"] as? String ?? "widget"
            resize(for: mode)
        case "openFullWindow":
            resize(for: "full")
        default:
            break
        }
    }

    private func resize(for mode: String) {
        guard let window else { return }

        let size: NSSize
        switch mode {
        case "peek":
            size = NSSize(width: 540, height: 700)
        case "full":
            size = NSSize(width: 980, height: 680)
        default:
            size = NSSize(width: 380, height: 260)
        }

        var frame = window.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        window.setFrame(frame, display: true, animate: true)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    private let bridge = NativeBridge()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let htmlPath = resolveHTMLPath()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(bridge, name: "aimeNative")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")

        window = NSWindow(
            contentRect: NSRect(x: 80, y: 720, width: 380, height: 260),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = webView
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovableByWindowBackground = true
        bridge.window = window

        webView.loadFileURL(URL(fileURLWithPath: htmlPath), allowingReadAccessTo: URL(fileURLWithPath: htmlPath).deletingLastPathComponent())
        window.makeKeyAndOrderFront(nil)

        createStatusItem()
    }

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Ai"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Widget", action: #selector(showWidget), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func showWidget() {
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func resolveHTMLPath() -> String {
        if CommandLine.arguments.count > 1 {
            return CommandLine.arguments[1]
        }

        let currentDirectory = FileManager.default.currentDirectoryPath
        return "\(currentDirectory)/dist/index.html"
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
