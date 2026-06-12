import AppKit

protocol SettingsWindowControllerDelegate: AnyObject {
    func settingsWindowControllerAccessibilityStatus(_ controller: SettingsWindowController) -> Bool
    func settingsWindowControllerRequestAccessibility(_ controller: SettingsWindowController)
    func settingsWindowControllerSelectedShortcutID(_ controller: SettingsWindowController) -> String
    func settingsWindowController(_ controller: SettingsWindowController, didSelectShortcutID shortcutID: String)
    func settingsWindowControllerLaunchAtLogin(_ controller: SettingsWindowController) -> Bool
    func settingsWindowControllerSetLaunchAtLogin(_ controller: SettingsWindowController, enabled: Bool)
    func settingsWindowControllerShowStatusItem(_ controller: SettingsWindowController) -> Bool
    func settingsWindowControllerSetShowStatusItem(_ controller: SettingsWindowController, enabled: Bool)
    func settingsWindowControllerVersionText(_ controller: SettingsWindowController) -> String
    func settingsWindowControllerCheckForUpdates(_ controller: SettingsWindowController)
    func settingsWindowControllerStartApp(_ controller: SettingsWindowController)
    func settingsWindowControllerDidClose(_ controller: SettingsWindowController)
    func settingsWindowControllerQuitApp(_ controller: SettingsWindowController)
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let shortcuts: [ModifierShortcut]
    private weak var settingsDelegate: SettingsWindowControllerDelegate?

    private let accessibilityStatusLabel = NSTextField(labelWithString: "")
    private let accessibilityButton = NSButton(title: "Enable Accessibility Access", target: nil, action: nil)
    private let shortcutPopup = NSPopUpButton()
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private let showStatusItemCheckbox = NSButton(checkboxWithTitle: "Show status bar icon", target: nil, action: nil)
    private let versionLabel = NSTextField(labelWithString: "")
    private let updateButton = NSButton(title: "Check for Updates", target: nil, action: nil)
    private let quitButton = NSButton(title: "Quit", target: nil, action: nil)
    private let launchButton = NSButton(title: "Start", target: nil, action: nil)

    init(shortcuts: [ModifierShortcut], delegate: SettingsWindowControllerDelegate) {
        self.shortcuts = shortcuts
        self.settingsDelegate = delegate

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 350),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SLSwitch"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)

        buildContent()
        refresh()
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        nil
    }

    func refresh() {
        guard let settingsDelegate else { return }

        let accessibilityGranted = settingsDelegate.settingsWindowControllerAccessibilityStatus(self)
        accessibilityStatusLabel.stringValue = accessibilityGranted
            ? "Accessibility access is granted"
            : "Accessibility access is not granted"
        accessibilityStatusLabel.textColor = accessibilityGranted ? .systemGreen : .systemRed
        accessibilityButton.isEnabled = !accessibilityGranted

        let selectedShortcutID = settingsDelegate.settingsWindowControllerSelectedShortcutID(self)
        if let item = shortcutPopup.itemArray.first(where: { $0.representedObject as? String == selectedShortcutID }) {
            shortcutPopup.select(item)
        }

        launchAtLoginCheckbox.state = settingsDelegate.settingsWindowControllerLaunchAtLogin(self) ? .on : .off
        showStatusItemCheckbox.state = settingsDelegate.settingsWindowControllerShowStatusItem(self) ? .on : .off
        versionLabel.stringValue = settingsDelegate.settingsWindowControllerVersionText(self)
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 18
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
        ])

        let titleLabel = NSTextField(labelWithString: "SLSwitch")
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        root.addArrangedSubview(titleLabel)

        root.addArrangedSubview(makeAccessibilitySection())
        root.addArrangedSubview(makeShortcutSection())
        root.addArrangedSubview(launchAtLoginCheckbox)
        root.addArrangedSubview(showStatusItemCheckbox)
        root.addArrangedSubview(makeVersionSection())

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 4).isActive = true
        root.addArrangedSubview(spacer)

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 12
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        let buttonSpacer = NSView()
        buttonSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        buttonRow.addArrangedSubview(buttonSpacer)

        quitButton.bezelStyle = .rounded
        quitButton.target = self
        quitButton.action = #selector(quitApp)
        buttonRow.addArrangedSubview(quitButton)

        launchButton.bezelStyle = .rounded
        launchButton.keyEquivalent = "\r"
        launchButton.target = self
        launchButton.action = #selector(startApp)
        buttonRow.addArrangedSubview(launchButton)

        root.addArrangedSubview(buttonRow)
        buttonRow.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        accessibilityButton.target = self
        accessibilityButton.action = #selector(requestAccessibility)

        shortcutPopup.target = self
        shortcutPopup.action = #selector(selectShortcut)

        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(toggleLaunchAtLogin)

        showStatusItemCheckbox.target = self
        showStatusItemCheckbox.action = #selector(toggleShowStatusItem)

        updateButton.target = self
        updateButton.action = #selector(checkForUpdates)
    }

    private func makeAccessibilitySection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8

        let label = NSTextField(labelWithString: "Universal Access")
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(accessibilityStatusLabel)
        stack.addArrangedSubview(accessibilityButton)

        return stack
    }

    private func makeVersionSection() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        versionLabel.textColor = .secondaryLabelColor
        row.addArrangedSubview(versionLabel)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)

        updateButton.bezelStyle = .rounded
        row.addArrangedSubview(updateButton)

        row.widthAnchor.constraint(equalToConstant: 364).isActive = true
        return row
    }

    private func makeShortcutSection() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8

        let label = NSTextField(labelWithString: "Shortcut")
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        stack.addArrangedSubview(label)

        for shortcut in shortcuts {
            shortcutPopup.addItem(withTitle: shortcut.name)
            shortcutPopup.lastItem?.representedObject = shortcut.id
        }
        shortcutPopup.widthAnchor.constraint(equalToConstant: 220).isActive = true
        stack.addArrangedSubview(shortcutPopup)

        return stack
    }

    @objc private func requestAccessibility() {
        settingsDelegate?.settingsWindowControllerRequestAccessibility(self)
        refresh()
    }

    @objc private func selectShortcut() {
        guard let shortcutID = shortcutPopup.selectedItem?.representedObject as? String else { return }

        settingsDelegate?.settingsWindowController(self, didSelectShortcutID: shortcutID)
    }

    @objc private func toggleLaunchAtLogin() {
        settingsDelegate?.settingsWindowControllerSetLaunchAtLogin(
            self,
            enabled: launchAtLoginCheckbox.state == .on
        )
    }

    @objc private func toggleShowStatusItem() {
        settingsDelegate?.settingsWindowControllerSetShowStatusItem(
            self,
            enabled: showStatusItemCheckbox.state == .on
        )
    }

    @objc private func checkForUpdates() {
        settingsDelegate?.settingsWindowControllerCheckForUpdates(self)
    }

    @objc private func startApp() {
        settingsDelegate?.settingsWindowControllerStartApp(self)
    }

    @objc private func quitApp() {
        settingsDelegate?.settingsWindowControllerQuitApp(self)
    }

    func windowWillClose(_ notification: Notification) {
        settingsDelegate?.settingsWindowControllerDidClose(self)
    }
}
