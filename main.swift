import AppKit
import ServiceManagement
import UserNotifications

let intervalKey = "intervalMinutes"
let toastKey = "useToast"
let intervalPresets = [15, 20, 30, 45, 60]
let reminderTitle = "Uống nước thôi 💧"
let messagesFile = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("WaterReminder/messages.txt")
let defaultMessages = [
    "Nửa cốc nước (~200ml) nhé.",
    "Vài ngụm nước rồi đứng dậy vươn vai một phút.",
    "Mục tiêu hôm nay 2,5–3 lít, thêm nửa cốc nào.",
    "Uống đều trước khi khát, đừng đợi khát mới uống.",
    "Uống ngụm nước rồi nhìn ra xa 20 giây cho mắt nghỉ.",
    "Thèm trà sữa hay nước ngọt thì thay bằng nước lọc nhé.",
]

final class ToastView: NSVisualEffectView {
    var onClick: () -> Void = {}
    // The toast window never becomes active, so without this the first click would be swallowed.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onClick() }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let pauseItem = NSMenuItem(title: "Tạm dừng", action: #selector(togglePause), keyEquivalent: "p")
    private let loginItem = NSMenuItem(title: "Mở cùng macOS", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let intervalItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let customIntervalItem = NSMenuItem(title: "", action: #selector(chooseCustomInterval), keyEquivalent: "")
    private let toastItem = NSMenuItem(title: "Toast ở màn hình đang dùng", action: #selector(toggleToast), keyEquivalent: "")
    private var nextReminder = Date()
    private var paused = false
    private var messageIndex = 0
    private var toast: NSPanel?

    private var intervalMinutes: Int { UserDefaults.standard.integer(forKey: intervalKey) }
    private var useToast: Bool { UserDefaults.standard.bool(forKey: toastKey) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [intervalKey: 30])
        restartCountdown()

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        statusItem.button?.image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "Uống nước")
        statusItem.button?.imagePosition = .imageLeading

        createMessagesFileIfMissing()

        let drankItem = NSMenuItem(title: "Uống rồi", action: #selector(drank), keyEquivalent: "d")
        let editItem = NSMenuItem(title: "Sửa câu nhắc…", action: #selector(editMessages), keyEquivalent: "e")
        let intervalMenu = NSMenu()
        for minutes in intervalPresets {
            let item = NSMenuItem(title: "\(minutes) phút", action: #selector(choosePresetInterval(_:)), keyEquivalent: "")
            item.tag = minutes
            item.target = self
            intervalMenu.addItem(item)
        }
        intervalMenu.addItem(.separator())
        customIntervalItem.target = self
        intervalMenu.addItem(customIntervalItem)
        intervalItem.submenu = intervalMenu

        let menu = NSMenu()
        for item in [drankItem, pauseItem, .separator(), intervalItem, editItem, toastItem, loginItem] {
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem(title: "Thoát", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        // Checking a deadline instead of a single long timer keeps the reminder correct after the Mac sleeps.
        // Common modes keep it ticking while the status menu or a dialog is open.
        RunLoop.main.add(Timer(timeInterval: 1, target: self, selector: #selector(tick), userInfo: nil, repeats: true), forMode: .common)
        refresh()
        refreshIntervalMenu()
        refreshLoginItem()
        toastItem.state = useToast ? .on : .off
    }

    @objc private func tick() {
        guard !paused else { return }
        if Date() >= nextReminder {
            notify()
            restartCountdown()
        }
        refresh()
    }

    @objc private func drank() {
        restartCountdown()
        refresh()
    }

    @objc private func togglePause() {
        paused.toggle()
        if !paused { restartCountdown() }
        refresh()
    }

    private func restartCountdown() {
        nextReminder = Date().addingTimeInterval(TimeInterval(intervalMinutes * 60))
    }

    @objc private func choosePresetInterval(_ sender: NSMenuItem) {
        setInterval(sender.tag)
    }

    @objc private func chooseCustomInterval() {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.stringValue = String(intervalMinutes)
        let alert = NSAlert()
        alert.messageText = "Nhắc mỗi bao nhiêu phút?"
        alert.informativeText = "Nhập số phút từ 1 đến 240."
        alert.accessoryView = field
        alert.addButton(withTitle: "Lưu")
        alert.addButton(withTitle: "Huỷ")
        alert.window.initialFirstResponder = field
        // A menu-bar-only app is never frontmost, so without this the dialog opens behind other windows.
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        guard let minutes = Int(field.stringValue.trimmingCharacters(in: .whitespaces)), (1...240).contains(minutes) else {
            let error = NSAlert()
            error.messageText = "Số phút không hợp lệ"
            error.informativeText = "Nhập số phút từ 1 đến 240."
            error.runModal()
            return
        }
        setInterval(minutes)
    }

    private func setInterval(_ minutes: Int) {
        UserDefaults.standard.set(minutes, forKey: intervalKey)
        restartCountdown()
        refresh()
        refreshIntervalMenu()
    }

    private func refreshIntervalMenu() {
        let isPreset = intervalPresets.contains(intervalMinutes)
        intervalItem.title = "Nhắc mỗi \(intervalMinutes) phút"
        for item in intervalItem.submenu?.items ?? [] where item.tag > 0 {
            item.state = item.tag == intervalMinutes ? .on : .off
        }
        customIntervalItem.title = isPreset ? "Tuỳ chỉnh…" : "Tuỳ chỉnh (\(intervalMinutes) phút)…"
        customIntervalItem.state = isPreset ? .off : .on
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            NSAlert(error: error).runModal()
        }
        refreshLoginItem()
    }

    private func refresh() {
        let secondsLeft = max(Int(ceil(nextReminder.timeIntervalSinceNow)), 0)
        let countdown = secondsLeft <= 30 ? "\(secondsLeft)s" : "\(Int(ceil(Double(secondsLeft) / 60)))m"
        let title = paused ? " ⏸" : " \(countdown)"
        // Re-assigning an identical title still forces a menu bar redraw, which adds up on a 1-second tick.
        if statusItem.button?.title != title { statusItem.button?.title = title }
        pauseItem.title = paused ? "Tiếp tục" : "Tạm dừng"
    }

    private func refreshLoginItem() {
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func editMessages() {
        createMessagesFileIfMissing()
        NSWorkspace.shared.open(messagesFile)
    }

    private func createMessagesFileIfMissing() {
        guard !FileManager.default.fileExists(atPath: messagesFile.path) else { return }
        let header = "# Mỗi dòng là một câu nhắc, dùng lần lượt. Dòng bắt đầu bằng # sẽ bị bỏ qua.\n"
        try? FileManager.default.createDirectory(at: messagesFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? (header + defaultMessages.joined(separator: "\n") + "\n").write(to: messagesFile, atomically: true, encoding: .utf8)
    }

    private func loadMessages() -> [String] {
        let lines = ((try? String(contentsOf: messagesFile, encoding: .utf8)) ?? "")
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        return lines.isEmpty ? defaultMessages : lines
    }

    @objc private func toggleToast() {
        UserDefaults.standard.set(!useToast, forKey: toastKey)
        toastItem.state = useToast ? .on : .off
    }

    private func notify() {
        let messages = loadMessages()
        let message = messages[messageIndex % messages.count]
        messageIndex += 1
        if useToast { showToast(message) } else { postSystemNotification(message) }
    }

    private func postSystemNotification(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = reminderTitle
        content.body = message
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "drink-water", content: content, trigger: nil))
    }

    // macOS always shows system banners on the main display; a custom panel can follow the pointer to whichever screen is in use.
    private func showToast(_ message: String) {
        dismissToast()
        let size = NSSize(width: 360, height: 84)
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main!
        let origin = NSPoint(x: screen.visibleFrame.maxX - size.width - 16, y: screen.visibleFrame.maxY - size.height - 16)

        let panel = NSPanel(contentRect: NSRect(origin: origin, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        // macOS hides system notifications during screen sharing; this keeps the toast out of shares and recordings too.
        panel.sharingType = .none
        // Pinning the appearance keeps the text legible on the HUD material in light mode as well.
        panel.appearance = NSAppearance(named: .darkAqua)
        // The panel is owned by `toast`; letting AppKit also release it on close would over-release it.
        panel.isReleasedWhenClosed = false

        let view = ToastView(frame: NSRect(origin: .zero, size: size))
        view.material = .hudWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 16
        view.layer?.masksToBounds = true
        view.onClick = { [weak self] in
            self?.drank()
            self?.dismissToast()
        }

        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.frame = NSRect(x: 14, y: 18, width: 48, height: 48)
        let title = NSTextField(labelWithString: reminderTitle)
        title.font = .boldSystemFont(ofSize: 13)
        title.frame = NSRect(x: 74, y: 50, width: 272, height: 18)
        let body = NSTextField(wrappingLabelWithString: message)
        body.font = .systemFont(ofSize: 13)
        body.maximumNumberOfLines = 2
        body.cell?.truncatesLastVisibleLine = true
        body.frame = NSRect(x: 74, y: 12, width: 272, height: 36)
        for subview in [icon, title, body] { view.addSubview(subview) }

        panel.contentView = view
        panel.orderFrontRegardless()
        toast = panel
        NSSound.beep()

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            if self?.toast === panel { self?.dismissToast() }
        }
    }

    private func dismissToast() {
        toast?.close()
        toast = nil
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
