import AppKit
import Foundation

struct ModifierShortcut {
    let id: String
    let name: String
    let flags: NSEvent.ModifierFlags
}

final class ModifierHotKeyMonitor {
    var activeShortcut: ModifierShortcut
    var isRunning: Bool {
        eventMonitor != nil
    }

    private let onTrigger: (ModifierShortcut) -> Void
    private var eventMonitor: Any?
    private var currentModifiers: NSEvent.ModifierFlags = []
    private var didTriggerForCurrentPress = false

    init(activeShortcut: ModifierShortcut, onTrigger: @escaping (ModifierShortcut) -> Void) {
        self.activeShortcut = activeShortcut
        self.onTrigger = onTrigger
    }

    @discardableResult
    func start() -> Bool {
        guard eventMonitor == nil else { return true }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event: event)
        }

        return eventMonitor != nil
    }

    func stop() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }

        eventMonitor = nil
        currentModifiers = []
        didTriggerForCurrentPress = false
    }

    func restart() {
        stop()
        _ = start()
    }

    private func handle(event: NSEvent) {
        let newModifiers = normalized(flags: event.modifierFlags)

        if newModifiers.isEmpty {
            didTriggerForCurrentPress = false
        }

        if newModifiers != currentModifiers,
           !didTriggerForCurrentPress,
           newModifiers.nonEmptyModifierCount == 2,
           activeShortcut.flags == newModifiers {
            didTriggerForCurrentPress = true
            onTrigger(activeShortcut)
        }

        currentModifiers = newModifiers
    }

    private func normalized(flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        flags.intersection([.shift, .control, .option, .command, .function])
    }
}

private extension NSEvent.ModifierFlags {
    var nonEmptyModifierCount: Int {
        var count = 0
        if contains(.shift) { count += 1 }
        if contains(.control) { count += 1 }
        if contains(.option) { count += 1 }
        if contains(.command) { count += 1 }
        if contains(.function) { count += 1 }
        return count
    }
}
