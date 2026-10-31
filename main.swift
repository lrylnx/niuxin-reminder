import AppKit

final class ReminderCard: NSView {
    var customer = "消息提醒"
    var account = "千牛补充提醒"
    var subtitle = "收到新消息，点击查看"
    var heading = "牛信提醒 · 新消息"
    var avatar: NSImage?
    var open: (() -> Void)?
    var close: (() -> Void)?
    private var dragStart = NSPoint.zero
    private var originStart = NSPoint.zero
    private var didDrag = false
    private var pressedClose = false
    private var headerDrag = false
    override var isFlipped: Bool { true }
    let blue = NSColor(srgbRed: 0.12, green: 0.47, blue: 1, alpha: 1)

    func text(_ value: String, _ rect: NSRect, _ size: CGFloat, _ color: NSColor, _ weight: NSFont.Weight = .regular) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        (value as NSString).draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: paragraph])
    }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: bounds, xRadius: 15, yRadius: 15).addClip()
        NSColor(srgbRed: 0.975, green: 0.982, blue: 0.995, alpha: 1).setFill()
        bounds.fill()
        blue.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 34).fill()
        text(heading, NSRect(x: 16, y: 8, width: 340, height: 20), 13, .white, .medium)
        text("×", NSRect(x: 372, y: 4, width: 24, height: 26), 21, NSColor.white.withAlphaComponent(0.9))
        let avatarRect = NSRect(x: 16, y: 52, width: 46, height: 46)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(ovalIn: avatarRect).addClip()
        NSColor(srgbRed: 0.88, green: 0.93, blue: 1, alpha: 1).setFill()
        avatarRect.fill()
        if let avatar = avatar {
            avatar.draw(in: avatarRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        } else {
            text(String(customer.prefix(1)), NSRect(x: 27, y: 60, width: 28, height: 30), 23, blue, .medium)
        }
        NSGraphicsContext.restoreGraphicsState()
        let nameWidth = min(CGFloat(126), max(CGFloat(74), (customer as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 15, weight: .semibold)]).width + 2))
        text(customer, NSRect(x: 76, y: 54, width: nameWidth, height: 23), 15, NSColor(srgbRed: 0.12, green: 0.16, blue: 0.23, alpha: 1), .semibold)
        let badge = account
        let badgeX = 76 + nameWidth + 12
        let badgeWidth = min(365 - badgeX, (badge as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 12)]).width + 16)
        NSColor(srgbRed: 0.9, green: 0.94, blue: 1, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: badgeX, y: 54, width: badgeWidth, height: 22), xRadius: 6, yRadius: 6).fill()
        text(badge, NSRect(x: badgeX + 8, y: 57, width: badgeWidth - 16, height: 18), 12, blue)
        text("›", NSRect(x: 376, y: 65, width: 18, height: 28), 24, .tertiaryLabelColor)
        text(subtitle, NSRect(x: 76, y: 83, width: 288, height: 20), 12, NSColor(srgbRed: 0.5, green: 0.55, blue: 0.62, alpha: 1))
        NSGraphicsContext.restoreGraphicsState()
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        pressedClose = point.x > 364 && point.y < 34
        headerDrag = point.y < 34 && !pressedClose
        if headerDrag {
            window?.performDrag(with: event)
            return
        }
        dragStart = NSEvent.mouseLocation
        originStart = window?.frame.origin ?? .zero
        didDrag = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard !pressedClose && !headerDrag else { return }
        let point = NSEvent.mouseLocation
        let dx = point.x - dragStart.x, dy = point.y - dragStart.y
        if hypot(dx, dy) >= 4 { didDrag = true }
        if didDrag { window?.setFrameOrigin(NSPoint(x: originStart.x + dx, y: originStart.y + dy)) }
    }
    override func mouseUp(with event: NSEvent) {
        guard !didDrag && !headerDrag else { return }
        let point = convert(event.locationInWindow, from: nil)
        if pressedClose {
            if point.x > 364 && point.y < 34 { close?() }
        } else { open?() }
    }

}

final class Reminder: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let logURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Aliworkbench/System/log/app.log")
    var file: FileHandle?
    var inode: UInt64 = 0
    var offset: UInt64 = 0
    var pending = Data()
    var seen = Set<String>()
    var order: [String] = []
    var timer: Timer?
    var panel: NSPanel!
    var card: ReminderCard!
    var status: NSStatusItem!
    var pauseItem: NSMenuItem!
    var isPaused = false
    var reminders = PendingReminders()
    var count: Int { reminders.count }
    var latestID: String? { reminders.latestID }
    var needsMessageRefresh = false
    var details: [String: MessageDetail] = [:]
    var portraitURLs: [String: String] = [:]
    let imageCache = NSCache<NSString, NSImage>()
    var loading = Set<String>()
    var displayedCustomerID = ""
    var detailOrder: [String] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let preview = CommandLine.arguments.contains("--preview")
        if !preview, let identifier = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: identifier).contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.image = menuBarIcon()
        status.button?.toolTip = "牛信提醒 · 正在监听千牛消息"
        let menu = NSMenu()
        for (title, action) in [("打开千牛", #selector(openApp)), ("预览提醒样式", #selector(test)), ("暂停提醒", #selector(togglePause)), ("关于牛信提醒", #selector(about)), ("退出牛信提醒", #selector(quit))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
            if title == "暂停提醒" { pauseItem = item }
        }
        status.menu = menu
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 124), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "牛信提醒"
        panel.delegate = self
        panel.isMovable = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.appearance = NSAppearance(named: .aqua)
        card = ReminderCard(frame: NSRect(x: 0, y: 0, width: 400, height: 124))
        card.open = { [weak self] in self?.openApp() }
        card.close = { [weak self] in self?.dismiss() }
        card.setAccessibilityElement(true)
        card.setAccessibilityRole(.button)
        card.setAccessibilityLabel("牛信提醒，点击打开千牛")
        panel.contentView = card
        imageCache.countLimit = 100
        if let index = CommandLine.arguments.firstIndex(of: "--preview"), CommandLine.arguments.count > index + 1 {
            card.customer = "客户昵称"
            card.account = "示例店铺:客服小玲"
            card.heading = "牛信提醒 · 2 条新消息"
            card.subtitle = "独立提醒 · 不影响当前操作"
            let rep = card.bitmapImageRepForCachingDisplay(in: card.bounds)!
            card.cacheDisplay(in: card.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
            NSApp.terminate(nil)
            return
        }
        if CommandLine.arguments.contains("--window-preview") { test(); return }
        seedPortraits()
        attach(skipExisting: true)
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.poll() }
    }

    func menuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { _ in
            NSColor.black.setStroke()
            let bubble = NSBezierPath(roundedRect: NSRect(x: 3.5, y: 3.5, width: 13, height: 12), xRadius: 4, yRadius: 4)
            bubble.lineWidth = 1.6
            bubble.stroke()
            let horns = NSBezierPath()
            horns.move(to: NSPoint(x: 6, y: 14))
            horns.curve(to: NSPoint(x: 1.5, y: 18), controlPoint1: NSPoint(x: 2, y: 14), controlPoint2: NSPoint(x: 1.5, y: 16))
            horns.move(to: NSPoint(x: 14, y: 14))
            horns.curve(to: NSPoint(x: 18.5, y: 18), controlPoint1: NSPoint(x: 18, y: 14), controlPoint2: NSPoint(x: 18.5, y: 16))
            horns.move(to: NSPoint(x: 7, y: 3.5))
            horns.line(to: NSPoint(x: 4, y: 1))
            horns.lineWidth = 1.6
            horns.lineCapStyle = .round
            horns.stroke()
            NSColor.black.setFill()
            for x in [7.0, 11.5] { NSBezierPath(ovalIn: NSRect(x: x, y: 8, width: 1.8, height: 1.8)).fill() }
            return true
        }
        image.isTemplate = true
        return image
    }

    @objc func togglePause() {
        isPaused.toggle()
        pauseItem.title = isPaused ? "恢复提醒" : "暂停提醒"
        status.button?.appearsDisabled = isPaused
        status.button?.toolTip = isPaused ? "牛信提醒 · 已暂停" : "牛信提醒 · 正在监听千牛消息"
        if isPaused { dismiss() }
    }

    @objc func about() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "牛信提醒",
            .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.2",
            .credits: NSAttributedString(string: "千牛 macOS 独立消息提醒\n开源项目 · 非阿里巴巴官方应用\ngithub.com/lrylnx/niuxin-reminder\n© 2026 lrylnx · MIT License")
        ])
    }

    func attach(skipExisting: Bool) {
        file?.closeFile()
        file = nil
        pending.removeAll()
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: logURL.path),
              let handle = try? FileHandle(forReadingFrom: logURL) else {
            status.button?.toolTip = "牛信提醒 · 等待千牛日志，请先登录千牛"
            return
        }
        inode = (attrs[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
        file = handle
        offset = skipExisting ? handle.seekToEndOfFile() : 0
        handle.seek(toFileOffset: offset)
        status.button?.toolTip = isPaused ? "牛信提醒 · 已暂停" : "牛信提醒 · 正在监听千牛消息"
    }

    func poll() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: logURL.path) else {
            status.button?.toolTip = "牛信提醒 · 等待千牛日志，请先登录千牛"
            return
        }
        let currentInode = (attrs[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
        let size = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
        if file == nil { attach(skipExisting: true) }
        else if currentInode != inode || size < offset { attach(skipExisting: false) }
        guard let file = file else { return }
        do {
            let data = try file.read(upToCount: 1024 * 1024) ?? Data()
            offset += UInt64(data.count)
            pending.append(data)
            while let newline = pending.firstIndex(of: 10) {
                let line = String(decoding: pending[..<newline], as: UTF8.self)
                pending.removeSubrange(...newline)
                consume(line)
            }
            if pending.count > 2 * 1024 * 1024 { pending.removeAll() }
            // Render once per batch so messages already read in the same batch
            // do not briefly flash a stale reminder.
            refreshMessages()
        } catch {
            attach(skipExisting: true)
        }
    }

    func refreshMessages() {
        guard needsMessageRefresh else { return }
        needsMessageRefresh = false
        if let id = latestID { showMessage(id) }
        else { dismiss() }
    }

    func consume(_ line: String) {
        recordPortraits(line)
        for (id, detail) in EventParser.details(line) {
            if details[id] == nil { detailOrder.append(id) }
            details[id] = detail
            if detailOrder.count > 2000 { details.removeValue(forKey: detailOrder.removeFirst()) }
            reminders.associate(id, conversation: detail.conversationCode)
            if latestID == id { needsMessageRefresh = true }
        }
        if let conversation = EventParser.handledConversation(line), reminders.handle(conversation) {
            needsMessageRefresh = true
        }
        guard !isPaused, let id = EventParser.messageID(line) else { return }
        guard seen.insert(id).inserted else { return }
        order.append(id)
        if order.count > 2000 { seen.remove(order.removeFirst()) }
        reminders.add(id, conversation: EventParser.arrivalConversation(line) ?? details[id]?.conversationCode ?? "")
        needsMessageRefresh = true
    }

    func showMessage(_ id: String) {
        card.heading = "牛信提醒 · \(count) 条新消息"
        card.subtitle = "正文请打开千牛查看"
        card.avatar = nil
        displayedCustomerID = ""
        if let detail = details[id], !detail.customer.isEmpty {
            let account = detail.account.isEmpty ? "未知账号" : detail.account
            card.customer = detail.customer
            card.account = account
            displayedCustomerID = detail.customerID
            loadAvatar(detail.customerID)
        } else {
            card.customer = "收到新消息"
            card.account = "千牛接待账号"
        }
        card.setAccessibilityLabel("\(card.heading)，客户\(card.customer)，接待账号\(card.account)，点击打开千牛")
        show()
    }

    func show() {
        card.needsDisplay = true
        // New messages and avatar refreshes retain the user's chosen position.
        if !panel.isVisible { restorePosition() }
        panel.orderFrontRegardless()
    }

    func restorePosition() {
        let size = panel.frame.size
        let saved = UserDefaults.standard.dictionary(forKey: "reminderWindowPosition")
        let point: NSPoint?
        if let x = saved?["x"] as? NSNumber, let y = saved?["y"] as? NSNumber {
            point = NSPoint(x: x.doubleValue, y: y.doubleValue)
        } else { point = nil }
        let screens = NSScreen.screens
        let screen = point.flatMap { p in screens.first { $0.visibleFrame.contains(NSPoint(x: p.x + size.width/2, y: p.y + size.height/2)) } } ?? NSScreen.main ?? screens.first
        guard let screen else { return }
        let rect = screen.visibleFrame
        let desired = point ?? NSPoint(x: rect.maxX-size.width-18, y: rect.maxY-size.height-18)
        panel.setFrameOrigin(NSPoint(x: min(max(desired.x, rect.minX+8), max(rect.minX+8, rect.maxX-size.width-8)),
                                     y: min(max(desired.y, rect.minY+8), max(rect.minY+8, rect.maxY-size.height-8))))
    }

    func windowDidMove(_ notification: Notification) {
        UserDefaults.standard.set(["x": panel.frame.minX, "y": panel.frame.minY], forKey: "reminderWindowPosition")
    }

    @objc func test() {
        dismiss()
        displayedCustomerID = ""
        card.avatar = nil
        card.heading = "牛信提醒 · 样式预览"
        card.customer = "提醒已就绪"
        card.account = "等待客户消息"
        card.subtitle = "拖动蓝色标题栏，位置自动记忆"
        show()
    }
    func seedPortraits() {
        guard let reader = try? FileHandle(forReadingFrom: logURL) else { return }
        defer { reader.closeFile() }
        let size = reader.seekToEndOfFile()
        reader.seek(toFileOffset: size > 16_000_000 ? size - 16_000_000 : 0)
        let data = reader.readDataToEndOfFile()
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") where line.contains("FetchProfilePortrait begin") {
            recordPortraits(String(line))
        }
    }
    func recordPortraits(_ line: String) {
        for (id, address) in EventParser.portraits(line) {
            if portraitURLs.count >= 5000 && portraitURLs[id] == nil { portraitURLs.removeAll() }
            portraitURLs[id] = address
            if displayedCustomerID == id { loadAvatar(id) }
        }
    }
    func loadAvatar(_ id: String) {
        guard let address = portraitURLs[id], let url = URL(string: address), url.host == "img.alicdn.com", url.scheme == "https" else { return }
        if let image = imageCache.object(forKey: address as NSString) {
            card.avatar = image
            card.needsDisplay = true
            return
        }
        guard loading.insert(address).inserted else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.httpShouldHandleCookies = false
        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.loading.remove(address)
                guard let data = data, data.count < 2_000_000, (response as? HTTPURLResponse)?.statusCode == 200,
                      let image = NSImage(data: data) else { return }
                self.imageCache.setObject(image, forKey: address as NSString)
                if self.displayedCustomerID == id && self.portraitURLs[id] == address {
                    self.card.avatar = image
                    self.card.needsDisplay = true
                }
            }
        }.resume()
    }
    @objc func dismiss() {
        reminders.clear()
        needsMessageRefresh = false
        displayedCustomerID = ""
        panel.orderOut(nil)
    }
    @objc func openApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.taobao.Aliworkbench") else {
            card.subtitle = "未找到千牛，请先安装并登录"
            show()
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if error == nil { self.dismiss() }
                else { self.card.subtitle = "千牛打开失败，请手动打开"; self.show() }
            }
        }
    }
    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = Reminder()
app.delegate = delegate
app.run()
