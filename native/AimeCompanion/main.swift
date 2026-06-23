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
        case "console":
            let level = body["level"] as? String ?? "log"
            let message = body["message"] as? String ?? ""
            print("Aime WebView \(level): \(message)")
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
        NSApp.setActivationPolicy(.regular)

        let htmlPath = resolveHTMLPath()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(consoleBridgeScript())
        configuration.userContentController.add(bridge, name: "aimeNative")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")

        window = NSWindow(
            contentRect: initialWidgetFrame(),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = webView
        window.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.96)
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovableByWindowBackground = true
        window.title = "Aime"
        bridge.window = window

        webView.loadFileURL(URL(fileURLWithPath: htmlPath), allowingReadAccessTo: URL(fileURLWithPath: htmlPath).deletingLastPathComponent())
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        createStatusItem()
    }

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Aime"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Widget", action: #selector(showWidget), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func showWidget() {
        window.setFrame(initialWidgetFrame(), display: true, animate: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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

    private func initialWidgetFrame() -> NSRect {
        let size = NSSize(width: 380, height: 260)
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSRect(
            x: visibleFrame.maxX - size.width - 32,
            y: visibleFrame.maxY - size.height - 48,
            width: size.width,
            height: size.height
        )
    }

    private func consoleBridgeScript() -> WKUserScript {
        let source = """
        (function () {
          function send(level, message) {
            try {
              window.webkit.messageHandlers.aimeNative.postMessage({
                command: 'console',
                level: level,
                message: String(message)
              });
            } catch (_) {}
          }
          ['log', 'warn', 'error'].forEach(function (level) {
            var original = console[level];
            console[level] = function () {
              send(level, Array.prototype.map.call(arguments, String).join(' '));
              original.apply(console, arguments);
            };
          });
          window.addEventListener('error', function (event) {
            send('error', event.message + ' @ ' + event.filename + ':' + event.lineno + ':' + event.colno);
          });
          window.addEventListener('unhandledrejection', function (event) {
            send('error', 'Unhandled promise rejection: ' + event.reason);
          });
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
