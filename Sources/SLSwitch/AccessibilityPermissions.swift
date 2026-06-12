import AppKit
import ApplicationServices
import Foundation

enum AccessibilityPermissions {
    static func isTrusted(prompt: Bool) -> Bool {
        guard prompt else {
            return AXIsProcessTrusted()
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrusted() || AXIsProcessTrustedWithOptions(options)
    }

    static func requestPermission() {
        _ = isTrusted(prompt: true)
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
