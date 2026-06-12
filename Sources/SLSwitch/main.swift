import AppKit
import ApplicationServices
import Foundation

private enum LaunchMode {
    case automatic
    case background
    case showSettings

    static func current(arguments: [String] = CommandLine.arguments) -> LaunchMode {
        let flags = Set(arguments.dropFirst())

        if flags.contains("--show-settings") || flags.contains("--settings") {
            return .showSettings
        }

        if flags.contains("--background")
            || flags.contains("--login-item")
            || flags.contains("--launch-at-login") {
            return .background
        }

        return .automatic
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let shortcutDefaultsKey = "activeShortcutID"
    private let showStatusItemDefaultsKey = "showStatusItem"
    private let setupCompletedDefaultsKey = "setupCompleted"
    private let lastUpdateCheckDefaultsKey = "lastUpdateCheckDate"
    private let shortcuts = [
        ModifierShortcut(id: "shift-command", name: "Shift + Command", flags: [.shift, .command]),
        ModifierShortcut(id: "shift-option", name: "Shift + Option", flags: [.shift, .option]),
        ModifierShortcut(id: "shift-control", name: "Shift + Control", flags: [.shift, .control]),
    ]
    private var statusItem: NSStatusItem?
    private let inputSourceController = InputSourceController()
    private let updateController = GitHubUpdateController()
    private var hotKeyRetryTimer: Timer?
    private var statusRefreshTimer: Timer?
    private var settingsWindowController: SettingsWindowController?
    private var lastKnownAccessibilityStatus: Bool?
    private var lastKnownHotKeyRunningStatus: Bool?
    private var isCheckingForUpdates = false
    private lazy var hotKeyMonitor = ModifierHotKeyMonitor(
        activeShortcut: activeShortcut,
        onTrigger: { [weak self] shortcut in
            self?.handleTrigger(shortcut: shortcut)
        }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        let launchMode = LaunchMode.current()

        let startsInBackground = shouldStartInBackground(launchMode: launchMode)
        NSApp.setActivationPolicy(startsInBackground ? .accessory : .regular)

        applyStatusItemVisibility()
        startStatusRefreshTimer()
        startHotKeyMonitorIfPossible()
        scheduleHotKeyRetryIfNeeded()
        checkForUpdatesAutomaticallyIfNeeded()

        if startsInBackground {
            updateMenu()
        } else {
            showSettingsWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyRetryTimer?.invalidate()
        statusRefreshTimer?.invalidate()
        hotKeyMonitor.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.setActivationPolicy(.regular)
        showSettingsWindow()
        return true
    }

    private func applyStatusItemVisibility() {
        if shouldShowStatusItem {
            if statusItem == nil {
                statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                configureStatusItem()
            } else {
                updateMenu()
            }
        } else if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func configureStatusItem() {
        guard let statusItem else { return }
        guard let button = statusItem.button else { return }
        if let image = NSImage(named: "StatusBarIconTemplate") {
            image.isTemplate = true
            image.size = NSSize(width: 22, height: 22)
            button.image = image
            button.imagePosition = .imageOnly
        } else {
            button.title = "SL"
        }
        button.toolTip = "SLSwitch"
        statusItem.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: L10n.format("menu.version", AppVersion.short), action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: L10n.format("menu.current_source", inputSourceController.currentSourceName()), action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: L10n.format("menu.active_shortcut", activeShortcut.name), action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: accessibilityStatusTitle(), action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: hotKeyStatusTitle(), action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: L10n.string("menu.settings"), action: #selector(openSettingsWindow), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let switchItem = NSMenuItem(title: L10n.string("menu.switch_input_source"), action: #selector(switchInputSource), keyEquivalent: "")
        switchItem.target = self
        menu.addItem(switchItem)

        let shortcutItem = NSMenuItem(title: L10n.string("menu.active_shortcut_title"), action: nil, keyEquivalent: "")
        shortcutItem.submenu = makeShortcutMenu()
        menu.addItem(shortcutItem)

        let launchAtLoginItem = NSMenuItem(title: launchAtLoginTitle(), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = LaunchAtLoginController.isEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        let showStatusItem = NSMenuItem(title: L10n.string("menu.show_status_icon"), action: #selector(toggleStatusItemVisibility), keyEquivalent: "")
        showStatusItem.target = self
        showStatusItem.state = shouldShowStatusItem ? .on : .off
        menu.addItem(showStatusItem)

        let permissionsItem = NSMenuItem(title: L10n.string("menu.open_accessibility_settings"), action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permissionsItem.target = self
        menu.addItem(permissionsItem)

        let refreshItem = NSMenuItem(title: L10n.string("menu.refresh"), action: #selector(refreshMenu), keyEquivalent: "")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let updateItem = NSMenuItem(title: L10n.string("menu.check_updates"), action: #selector(checkForUpdatesFromMenu), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: L10n.string("menu.quit"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func showSettingsWindow() {
        NSApp.setActivationPolicy(.regular)
        let controller = settingsWindowController ?? SettingsWindowController(
            shortcuts: shortcuts,
            delegate: self
        )
        settingsWindowController = controller
        controller.refresh()
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func startStatusRefreshTimer() {
        statusRefreshTimer?.invalidate()
        statusRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }

            let accessibilityGranted = AccessibilityPermissions.isTrusted(prompt: false)
            if accessibilityGranted, !self.hotKeyMonitor.isRunning {
                self.startHotKeyMonitorIfPossible()
            }

            let hotKeyRunning = self.hotKeyMonitor.isRunning
            let statusChanged = accessibilityGranted != self.lastKnownAccessibilityStatus
                || hotKeyRunning != self.lastKnownHotKeyRunningStatus

            self.lastKnownAccessibilityStatus = accessibilityGranted
            self.lastKnownHotKeyRunningStatus = hotKeyRunning

            if self.settingsWindowController?.window?.isVisible == true {
                self.settingsWindowController?.refresh()
            }

            if statusChanged {
                self.updateMenu()
            }
        }
    }

    private func scheduleHotKeyRetryIfNeeded() {
        guard !hotKeyMonitor.isRunning, hotKeyRetryTimer == nil else { return }

        hotKeyRetryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            guard AccessibilityPermissions.isTrusted(prompt: false) else { return }

            self.startHotKeyMonitorIfPossible()
            if self.hotKeyMonitor.isRunning {
                timer.invalidate()
                self.hotKeyRetryTimer = nil
                self.updateMenu()
            }
        }
    }

    private func startHotKeyMonitorIfPossible() {
        guard AccessibilityPermissions.isTrusted(prompt: false) else { return }

        hotKeyMonitor.restart()
    }

    private var activeShortcut: ModifierShortcut {
        let savedID = UserDefaults.standard.string(forKey: shortcutDefaultsKey)
        return shortcuts.first(where: { $0.id == savedID }) ?? shortcuts[0]
    }

    private var shouldShowStatusItem: Bool {
        if UserDefaults.standard.object(forKey: showStatusItemDefaultsKey) == nil {
            return true
        }

        return UserDefaults.standard.bool(forKey: showStatusItemDefaultsKey)
    }

    private var isSetupCompleted: Bool {
        UserDefaults.standard.bool(forKey: setupCompletedDefaultsKey)
    }

    private func shouldStartInBackground(launchMode: LaunchMode) -> Bool {
        switch launchMode {
        case .background:
            return true
        case .showSettings:
            return false
        case .automatic:
            return isSetupCompleted && isLikelyLaunchAtLoginStart
        }
    }

    private var isLikelyLaunchAtLoginStart: Bool {
        LaunchAtLoginController.isEnabled && ProcessInfo.processInfo.systemUptime < 240
    }

    private func makeShortcutMenu() -> NSMenu {
        let menu = NSMenu()

        for shortcut in shortcuts {
            let item = NSMenuItem(title: shortcut.name, action: #selector(selectShortcut(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = shortcut.id
            item.state = shortcut.id == activeShortcut.id ? .on : .off
            menu.addItem(item)
        }

        return menu
    }

    private func launchAtLoginTitle() -> String {
        if LaunchAtLoginController.needsApproval {
            return L10n.string("menu.launch_at_login_approval_needed")
        }

        return L10n.string("menu.launch_at_login")
    }

    private func accessibilityStatusTitle() -> String {
        AccessibilityPermissions.isTrusted(prompt: false)
            ? L10n.string("status.accessibility_granted")
            : L10n.string("status.accessibility_not_granted")
    }

    private func hotKeyStatusTitle() -> String {
        if !AccessibilityPermissions.isTrusted(prompt: false) {
            return L10n.string("status.hotkeys_needs_accessibility")
        }

        return hotKeyMonitor.isRunning
            ? L10n.string("status.hotkeys_active")
            : L10n.string("status.hotkeys_reconnecting")
    }

    private func updateMenu() {
        lastKnownAccessibilityStatus = AccessibilityPermissions.isTrusted(prompt: false)
        lastKnownHotKeyRunningStatus = hotKeyMonitor.isRunning
        statusItem?.menu = makeMenu()
    }

    private func checkForUpdatesAutomaticallyIfNeeded() {
        if let lastCheck = UserDefaults.standard.object(forKey: lastUpdateCheckDefaultsKey) as? Date,
           Date().timeIntervalSince(lastCheck) < 12 * 60 * 60 {
            return
        }

        checkForUpdates(userInitiated: false)
    }

    private func checkForUpdates(userInitiated: Bool) {
        guard !isCheckingForUpdates else { return }

        isCheckingForUpdates = true
        UserDefaults.standard.set(Date(), forKey: lastUpdateCheckDefaultsKey)

        updateController.checkForUpdates { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isCheckingForUpdates = false

                switch result {
                case .success(.upToDate):
                    if userInitiated {
                        self.showUpdateMessage(
                            title: L10n.string("updates.up_to_date.title"),
                            message: L10n.format("updates.up_to_date.message", AppVersion.display)
                        )
                    }
                case .success(.available(let release)):
                    if userInitiated {
                        self.showUpdateAvailableAlert(release)
                    } else {
                        UserNotificationPresenter.shared.show(message: L10n.format("updates.available.notification", release.version))
                    }
                case .failure(let error):
                    if userInitiated {
                        self.showUpdateMessage(
                            title: L10n.string("updates.check_failed.title"),
                            message: error.localizedDescription
                        )
                    }
                }
            }
        }
    }

    private func showUpdateAvailableAlert(_ release: GitHubRelease) {
        let alert = NSAlert()
        alert.messageText = L10n.format("updates.available.title", release.version)
        alert.informativeText = L10n.format("updates.available.message", AppVersion.short)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.string("updates.button.download"))
        alert.addButton(withTitle: L10n.string("updates.button.open_release_page"))
        alert.addButton(withTitle: L10n.string("updates.button.later"))

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            downloadAndOpenInstaller(for: release)
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(release.pageURL)
        default:
            break
        }
    }

    private func downloadAndOpenInstaller(for release: GitHubRelease) {
        updateController.downloadInstaller(for: release) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let installerURL):
                    NSWorkspace.shared.open(installerURL)
                case .failure(let error):
                    self?.showUpdateMessage(
                        title: L10n.string("updates.download_failed.title"),
                        message: error.localizedDescription
                    )
                }
            }
        }
    }

    private func showUpdateMessage(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.string("common.ok"))
        alert.runModal()
    }

    private func handleTrigger(shortcut: ModifierShortcut) {
        guard AccessibilityPermissions.isTrusted(prompt: false) else {
            AccessibilityPermissions.requestPermission()
            NSSound.beep()
            return
        }

        inputSourceController.selectNextSource()
        updateMenu()
        UserNotificationPresenter.shared.show(message: L10n.format("notification.switched_by", shortcut.name))
    }

    @objc private func switchInputSource() {
        inputSourceController.selectNextSource()
        updateMenu()
    }

    @objc private func selectShortcut(_ sender: NSMenuItem) {
        guard let shortcutID = sender.representedObject as? String,
              let shortcut = shortcuts.first(where: { $0.id == shortcutID }) else {
            return
        }

        UserDefaults.standard.set(shortcut.id, forKey: shortcutDefaultsKey)
        hotKeyMonitor.activeShortcut = shortcut
        settingsWindowController?.refresh()
        updateMenu()
    }

    @objc private func requestAccessibilityPermission() {
        AccessibilityPermissions.requestPermission()
        startHotKeyMonitorIfPossible()
        scheduleHotKeyRetryIfNeeded()
        updateMenu()
    }

    @objc private func openAccessibilitySettings() {
        AccessibilityPermissions.openSettings()
        settingsWindowController?.refresh()
        updateMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        if LaunchAtLoginController.needsApproval {
            LaunchAtLoginController.openLoginItemsSettings()
            settingsWindowController?.refresh()
            return
        }

        do {
            try LaunchAtLoginController.setEnabled(!LaunchAtLoginController.isEnabled)
        } catch {
            LaunchAtLoginController.openLoginItemsSettings()
            NSSound.beep()
        }

        settingsWindowController?.refresh()
        updateMenu()
    }

    @objc private func toggleStatusItemVisibility() {
        UserDefaults.standard.set(!shouldShowStatusItem, forKey: showStatusItemDefaultsKey)
        applyStatusItemVisibility()
        settingsWindowController?.refresh()
    }

    @objc private func openSettingsWindow() {
        showSettingsWindow()
    }

    @objc private func refreshMenu() {
        startHotKeyMonitorIfPossible()
        scheduleHotKeyRetryIfNeeded()
        updateMenu()
    }

    @objc private func checkForUpdatesFromMenu() {
        checkForUpdates(userInitiated: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: SettingsWindowControllerDelegate {
    func settingsWindowControllerAccessibilityStatus(_ controller: SettingsWindowController) -> Bool {
        AccessibilityPermissions.isTrusted(prompt: false)
    }

    func settingsWindowControllerRequestAccessibility(_ controller: SettingsWindowController) {
        requestAccessibilityPermission()
    }

    func settingsWindowControllerSelectedShortcutID(_ controller: SettingsWindowController) -> String {
        activeShortcut.id
    }

    func settingsWindowController(_ controller: SettingsWindowController, didSelectShortcutID shortcutID: String) {
        guard let shortcut = shortcuts.first(where: { $0.id == shortcutID }) else { return }

        UserDefaults.standard.set(shortcut.id, forKey: shortcutDefaultsKey)
        hotKeyMonitor.activeShortcut = shortcut
        updateMenu()
        controller.refresh()
    }

    func settingsWindowControllerLaunchAtLogin(_ controller: SettingsWindowController) -> Bool {
        LaunchAtLoginController.isEnabled
    }

    func settingsWindowControllerSetLaunchAtLogin(_ controller: SettingsWindowController, enabled: Bool) {
        do {
            try LaunchAtLoginController.setEnabled(enabled)
        } catch {
            LaunchAtLoginController.openLoginItemsSettings()
            NSSound.beep()
        }

        controller.refresh()
        updateMenu()
    }

    func settingsWindowControllerShowStatusItem(_ controller: SettingsWindowController) -> Bool {
        shouldShowStatusItem
    }

    func settingsWindowControllerSetShowStatusItem(_ controller: SettingsWindowController, enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: showStatusItemDefaultsKey)
        applyStatusItemVisibility()
        controller.refresh()
    }

    func settingsWindowControllerVersionText(_ controller: SettingsWindowController) -> String {
        AppVersion.display
    }

    func settingsWindowControllerCheckForUpdates(_ controller: SettingsWindowController) {
        checkForUpdates(userInitiated: true)
    }

    func settingsWindowControllerStartApp(_ controller: SettingsWindowController) {
        UserDefaults.standard.set(true, forKey: setupCompletedDefaultsKey)
        applyStatusItemVisibility()
        startHotKeyMonitorIfPossible()
        scheduleHotKeyRetryIfNeeded()
        updateMenu()
        controller.close()
    }

    func settingsWindowControllerDidClose(_ controller: SettingsWindowController) {
        NSApp.setActivationPolicy(.accessory)
    }

    func settingsWindowControllerQuitApp(_ controller: SettingsWindowController) {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
