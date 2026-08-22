import Cocoa
import SwiftUI
import Combine
import QuartzCore

final class RoundedHostingView: NSView {
    override func layout() {
        super.layout()
        wantsLayer = true
        layer?.cornerRadius = 22
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
    }
}

final class InteractivePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = AppStore()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var panel: NSPanel?
    private var refreshTimers: [String: Timer] = [:]
    private var cycleTimer: Timer?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    private let panelSize = NSSize(width: 480, height: 680)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPanel()
        observeStore()
        restartTimers()
        store.refreshAll()
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimers.values.forEach { $0.invalidate() }
        cycleTimer?.invalidate()
        stopEventMonitors()
    }

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = nil
        button.imagePosition = .noImage
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        button.target = self
        button.action = #selector(togglePanel(_:))
        button.toolTip = "Status Bar"
        updateStatusItem()
    }

    private func setupPanel() {
        let root = MainView(store: store, onQuit: { NSApp.terminate(nil) })
        let host = NSHostingController(rootView: root)
        let panel = InteractivePanel(contentRect: NSRect(origin: .zero, size: panelSize), styleMask: [.nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        let container = RoundedHostingView()
        host.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: container.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        panel.contentView = container
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.panel = panel
    }

    private func observeStore() {
        store.$snapshots.sink { [weak self] _ in self?.updateStatusItem() }.store(in: &cancellables)
        store.$cycleMetricID.sink { [weak self] _ in self?.updateStatusItem() }.store(in: &cancellables)
        store.$settings.sink { [weak self] _ in
            self?.updateStatusItem()
            self?.restartTimers()
        }.store(in: &cancellables)
    }

    private func restartTimers() {
        refreshTimers.values.forEach { $0.invalidate() }
        refreshTimers.removeAll()
        cycleTimer?.invalidate()
        cycleTimer = nil
        for providerID in store.providerIDs {
            let timer = Timer.scheduledTimer(withTimeInterval: store.refreshInterval(for: providerID), repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.store.refresh(providerID) }
            }
            refreshTimers[providerID] = timer
        }
        if store.selectedMetric == .cycle {
            cycleTimer = Timer.scheduledTimer(withTimeInterval: store.settings.cycleDisplayInterval, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.store.advanceCycle()
                    self?.updateStatusItem()
                }
            }
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let id = store.activeMetricID
        let snapshot = store.selectedSnapshot
        let prefix: String = {
            switch id {
            case StatusMetricID.codex.rawValue: return "CDX"
            case StatusMetricID.lightsail.rawValue: return "LS"
            default: return ""
            }
        }()
        if snapshot?.state == .failed {
            button.title = prefix.isEmpty ? "!" : "\(prefix) !"
        } else if snapshot?.state == .unavailable || snapshot == nil {
            button.title = prefix.isEmpty ? "—" : "\(prefix) —"
        } else if let value = snapshot?.value {
            switch id {
            case StatusMetricID.codex.rawValue: button.title = "CDX \(value)"
            case StatusMetricID.lightsail.rawValue: button.title = "LS \(Fmt.percent(snapshot?.progress))"
            default: button.title = value.replacingOccurrences(of: " ", with: "")
            }
        }
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
    }

    @objc private func togglePanel(_ sender: Any?) {
        if panel?.isVisible == true { hidePanel() } else { showPanel() }
    }

    private func showPanel() {
        guard let panel, let button = statusItem.button, let window = button.window, let screen = window.screen ?? NSScreen.main else { return }
        let buttonRect = window.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = screen.visibleFrame
        let x = max(visible.minX + 8, min(buttonRect.maxX - panelSize.width, visible.maxX - panelSize.width - 8))
        let y = max(visible.minY + 8, visible.maxY - panelSize.height - 8)
        let finalFrame = NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height)
        panel.setFrame(finalFrame.offsetBy(dx: 0, dy: 8), display: false)
        panel.alphaValue = 0
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.transform = CATransform3DMakeScale(0.97, 0.97, 1)
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(finalFrame, display: true)
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.18)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
            panel.contentView?.layer?.transform = CATransform3DIdentity
            CATransaction.commit()
        }
        startEventMonitors()
    }

    private func hidePanel() {
        stopEventMonitors()
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1
        }
    }

    private func startEventMonitors() {
        stopEventMonitors()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async { self?.hidePanel() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            if event.window === self.panel || event.window === self.statusItem.button?.window { return event }
            self.hidePanel()
            return event
        }
    }

    private func stopEventMonitors() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor); self.globalMonitor = nil }
        if let localMonitor { NSEvent.removeMonitor(localMonitor); self.localMonitor = nil }
    }
}
