import AppKit
import SwiftUI
import os

/// Owns the menu bar icon: a left click toggles the glass panel,
/// a right click (or Control-click) shows the Settings/Quit menu.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let openSettings: () -> Void
    private var panel: PanelWindow?
    private var outsideClickMonitor: Any?

    init(openSettings: @escaping () -> Void) {
        self.openSettings = openSettings
        super.init()
        configureButton()
        configureMenu()
    }

    var isPanelShown: Bool { panel?.isVisible ?? false }

    func togglePanel() {
        isPanelShown ? closePanel() : showPanel()
    }

    // MARK: - Button

    private func configureButton() {
        guard let button = statusItem.button else { return }
        // Placeholder until the station logo arrives (SPEC, step S4).
        button.image = NSImage(systemSymbolName: "cloud.fill", accessibilityDescription: nil)
        button.setAccessibilityLabel("Серебряный Дождь")
        button.target = self
        button.action = #selector(buttonPressed(_:))
        button.sendAction(on: [.leftMouseDown, .rightMouseDown])
    }

    @objc private func buttonPressed(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseDown || event?.modifierFlags.contains(.control) == true
        wantsMenu ? showMenu() : togglePanel()
    }

    // MARK: - Menu

    private func configureMenu() {
        let settings = NSMenuItem(title: "Настройки…", action: #selector(settingsChosen), keyEquivalent: ",")
        settings.target = self
        let quit = NSMenuItem(title: "Выйти", action: #selector(quitChosen), keyEquivalent: "q")
        quit.target = self
        menu.items = [settings, .separator(), quit]
    }

    private func showMenu() {
        closePanel()
        // Assigning the menu only for this click keeps the left click free for the panel.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func settingsChosen() {
        openSettings()
    }

    @objc private func quitChosen() {
        NSApp.terminate(nil)
    }

    // MARK: - Panel

    private func showPanel() {
        guard let button = statusItem.button else { return }
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.show(below: button)
        button.highlight(true)
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.closePanel() }
        }
        Logger.menuBar.debug("Panel shown")
    }

    private func closePanel() {
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
        statusItem.button?.highlight(false)
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        outsideClickMonitor = nil
        Logger.menuBar.debug("Panel closed")
    }

    private func makePanel() -> PanelWindow {
        let panel = PanelWindow(rootView: PanelView(collapse: { [weak self] in self?.closePanel() }))
        panel.onCancel = { [weak self] in self?.closePanel() }
        return panel
    }
}
