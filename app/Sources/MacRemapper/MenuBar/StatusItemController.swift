import SwiftUI
import AppKit
import Combine
import MacRemapperCore

/// The menu bar icon and its menu, built directly with AppKit: a native `NSMenu` (so the
/// system handles positioning and styling) with a custom SwiftUI header and rich profile rows,
/// which SwiftUI's `MenuBarExtra` menu style can't render.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let appState: AppState
    private let showSettings: () -> Void
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let headerItem = NSMenuItem()
    private var isMenuOpen = false
    private var cancellables: Set<AnyCancellable> = []

    init(appState: AppState, showSettings: @escaping () -> Void) {
        self.appState = appState
        self.showSettings = showSettings
        super.init()

        let header = NSHostingView(rootView: MenuHeaderView().environmentObject(appState))
        header.frame.size = header.fittingSize
        header.autoresizingMask = [.width]
        headerItem.view = header

        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu

        updateIcon()
        rebuildItems()

        // objectWillChange fires before the new values land; apply them on the next pass
        // (in common modes, so it also runs while the menu is open and tracking).
        appState.objectWillChange
            .sink { [weak self] _ in
                RunLoop.main.perform(inModes: [.common]) { self?.stateDidChange() }
            }
            .store(in: &cancellables)
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildItems()
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
    }

    // MARK: - Building

    private func stateDidChange() {
        updateIcon()
        // Keeps the open menu in sync, e.g. hiding profiles when the header switch turns remapping off.
        if isMenuOpen {
            rebuildItems()
        }
    }

    private func updateIcon() {
        let isActive = appState.isRemappingEnabled && appState.accessibilityPermission.isTrusted
        let image = NSImage(systemSymbolName: isActive ? "keyboard" : "keyboard.badge.ellipsis",
                            accessibilityDescription: "Mac Remapper")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    private func rebuildItems() {
        // Keep the header item in place so its switch isn't torn down mid-interaction.
        if menu.items.first !== headerItem {
            menu.removeAllItems()
            menu.addItem(headerItem)
        }
        while menu.items.count > 1 {
            menu.removeItem(at: 1)
        }
        menu.addItem(.separator())

        if appState.hasRunningMacros {
            let item = actionItem("Stop Running Macros", action: #selector(stopMacros))
            item.image = NSImage(systemSymbolName: "stop.circle.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(paletteColors: [.systemRed]))
            menu.addItem(item)
            menu.addItem(.separator())
        }

        let isTrusted = appState.accessibilityPermission.isTrusted
        if !isTrusted {
            let item = actionItem("Grant Accessibility Access…", action: #selector(openSettings))
            item.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(paletteColors: [.systemOrange]))
            menu.addItem(item)
            menu.addItem(.separator())
        }

        // Profile status is meaningless while remapping is off or can't run, so hide it.
        if appState.isRemappingEnabled && isTrusted {
            menu.addItem(sectionHeader("Profiles"))
            if appState.profileStatuses.isEmpty {
                let item = NSMenuItem(title: "No enabled profiles", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            } else {
                for status in appState.profileStatuses {
                    menu.addItem(profileItem(for: status))
                }
            }
            menu.addItem(.separator())
        }

        menu.addItem(actionItem("Open Settings…", action: #selector(openSettings), key: ","))
        let quit = NSMenuItem(title: "Quit Mac Remapper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    private func actionItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func sectionHeader(_ title: String) -> NSMenuItem {
        if #available(macOS 14.0, *) {
            return .sectionHeader(title: title)
        }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    /// A two-line row: bold profile name over a smaller status line, with a colored dot.
    private func profileItem(for status: ProfileStatus) -> NSMenuItem {
        let item = actionItem(status.name, action: #selector(openSettings))
        let title = NSMutableAttributedString(
            string: status.name,
            attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)]
        )
        title.append(NSAttributedString(
            string: "\n" + detail(for: status),
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
        ))
        item.attributedTitle = title
        item.image = dot(color: status.isActive ? .systemGreen : .tertiaryLabelColor)
        return item
    }

    private func detail(for status: ProfileStatus) -> String {
        if status.isActive { return "Active now" }
        guard case .apps(let ids) = status.scope, !ids.isEmpty else { return "No apps selected" }
        return "Only in " + ids.map(AppInfo.displayName(for:)).joined(separator: ", ")
    }

    private func dot(color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 10, height: 10), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    @objc private func stopMacros() {
        appState.stopAllMacros()
    }

    @objc private func openSettings() {
        showSettings()
    }
}
