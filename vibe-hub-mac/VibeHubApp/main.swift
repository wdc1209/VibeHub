import AppKit
import SwiftUI

extension Notification.Name {
    static let tokenCardToggleStatusWindow = Notification.Name("tokenCardToggleStatusWindow")
    static let tokenCardToggleHistoryWindow = Notification.Name("tokenCardToggleHistoryWindow")
    static let tokenCardToggleHelpWindow = Notification.Name("tokenCardToggleHelpWindow")
    static let tokenCardRawInputExpansionChanged = Notification.Name("tokenCardRawInputExpansionChanged")
    static let tokenCardPinnedChanged = Notification.Name("tokenCardPinnedChanged")
    static let tokenCardCompactModeChanged = Notification.Name("tokenCardCompactModeChanged")
}

@MainActor
final class WindowCoordinator {
    private var statusWindow: NSWindow?
    private var historyWindow: NSWindow?
    private var helpWindow: NSWindow?

    func toggleStatus() {
        toggle(window: &statusWindow, title: "Vibe Hub 状态面板", size: NSSize(width: 560, height: 760)) {
            AnyView(StatusPanelHostView())
        }
    }

    func toggleHistory() {
        toggle(window: &historyWindow, title: "Vibe Hub 发送历史", size: NSSize(width: 560, height: 760)) {
            AnyView(HistoryPanelHostView())
        }
    }

    func toggleHelp() {
        toggle(window: &helpWindow, title: "Vibe Hub 说明", size: NSSize(width: 420, height: 640)) {
            AnyView(HelpPanelHostView())
        }
    }

    private func toggle(window: inout NSWindow?, title: String, size: NSSize, rootView: () -> AnyView) {
        if let existing = window, existing.isVisible {
            existing.orderOut(nil)
            return
        }

        let hosting = NSHostingView(rootView: rootView())
        let newWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newWindow.title = title
        newWindow.titleVisibility = .hidden
        newWindow.titlebarAppearsTransparent = true
        newWindow.titlebarSeparatorStyle = .none
        newWindow.backgroundColor = .clear
        newWindow.isOpaque = false
        newWindow.isMovableByWindowBackground = true
        newWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newWindow.standardWindowButton(.zoomButton)?.isHidden = true
        newWindow.contentView = hosting
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        window = newWindow
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum DefaultsKey {
        static let pinned = "vibeHub.windowPinned"
        static let compactMode = "vibeHub.compactMode"
    }

    private var window: NSWindow?
    private let windowCoordinator = WindowCoordinator()
    private var observers: [NSObjectProtocol] = []
    private let collapsedWindowSize = NSSize(width: 980, height: 689)
    private let expandedWindowSize = NSSize(width: 980, height: 829)
    private let compactWindowSize = NSSize(width: 780, height: 306)

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()

        let contentView = VibeHubRootView()
        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: collapsedWindowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        let initialCompact = UserDefaults.standard.bool(forKey: DefaultsKey.compactMode)
        let initialSize = initialCompact ? compactWindowSize : collapsedWindowSize
        window.setContentSize(initialSize)
        window.center()
        window.title = "Vibe Hub"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.toolbar = nil
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        self.window = window
        applyPinnedState(UserDefaults.standard.bool(forKey: DefaultsKey.pinned))

        observers.append(NotificationCenter.default.addObserver(forName: .tokenCardToggleStatusWindow, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.windowCoordinator.toggleStatus() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .tokenCardToggleHistoryWindow, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.windowCoordinator.toggleHistory() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .tokenCardToggleHelpWindow, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.windowCoordinator.toggleHelp() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .tokenCardRawInputExpansionChanged, object: nil, queue: .main) { [weak self] note in
            let expanded = (note.userInfo?["expanded"] as? Bool) ?? false
            Task { @MainActor in
                self?.setMainWindowExpanded(expanded)
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .tokenCardPinnedChanged, object: nil, queue: .main) { [weak self] note in
            let pinned = (note.userInfo?["pinned"] as? Bool) ?? false
            UserDefaults.standard.set(pinned, forKey: DefaultsKey.pinned)
            Task { @MainActor in
                self?.applyPinnedState(pinned)
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .tokenCardCompactModeChanged, object: nil, queue: .main) { [weak self] note in
            let compact = (note.userInfo?["compact"] as? Bool) ?? false
            UserDefaults.standard.set(compact, forKey: DefaultsKey.compactMode)
            Task { @MainActor in
                self?.setCompactMode(compact)
            }
        })

        NSApp.activate(ignoringOtherApps: true)
    }

    private func setMainWindowExpanded(_ expanded: Bool) {
        guard let window else { return }
        guard !UserDefaults.standard.bool(forKey: DefaultsKey.compactMode) else { return }
        let targetSize = expanded ? expandedWindowSize : collapsedWindowSize
        var frame = window.frame
        let deltaHeight = targetSize.height - frame.size.height
        frame.origin.y -= deltaHeight
        frame.size = targetSize
        window.setFrame(frame, display: true, animate: true)
    }

    private func setCompactMode(_ compact: Bool) {
        guard let window else { return }
        let targetSize: NSSize
        if compact {
            targetSize = compactWindowSize
        } else {
            let rawExpanded = UserDefaults.standard.bool(forKey: "vibeHub.rawInputExpanded")
            targetSize = rawExpanded ? expandedWindowSize : collapsedWindowSize
        }
        var frame = window.frame
        let deltaHeight = targetSize.height - frame.size.height
        frame.origin.y -= deltaHeight
        frame.size = targetSize
        window.setFrame(frame, display: true, animate: true)
    }

    private func applyPinnedState(_ pinned: Bool) {
        guard let window else { return }
        window.level = pinned ? .statusBar : .normal
        window.collectionBehavior = pinned ? [.canJoinAllSpaces, .fullScreenAuxiliary] : []
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Vibe Hub", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
