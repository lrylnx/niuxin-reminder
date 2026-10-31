// Appended to main.swift (without its app.run entry point) by test-appkit.sh.
func checkUI(_ condition: @autoclosure () -> Bool, _ name: String) {
    guard condition() else { fatalError("FAILED: \(name)") }
    print("PASS: \(name)")
}
let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
let reminder = Reminder()
reminder.panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 124), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
reminder.card = ReminderCard(frame: NSRect(x: 0, y: 0, width: 400, height: 124))
reminder.panel.contentView = reminder.card
let convA = "100.1-200.1#11001@cntaobao"
let convB = "300.1-200.1#11001@cntaobao"
func arrivalLine(_ id: String, _ conversation: String) -> String {
    "[app][OnMessageArrive][ msg.msg.code.messageId=\(id),msg.msg.conversationCode=\(conversation) ][ChatService.cpp(197) OnMessageArrive]"
}
func clickLine(_ conversation: String) -> String {
    "[app][CMessageMergeNotifyPresenter OnClicked][ ccode=\(conversation),identifier=3#200 ][MessageMergeNotifyPresenter.cpp(674) OnTreeNodeOrTagClick]"
}
func autoEnterLine(_ conversation: String) -> String {
    "[app][EnterConversation][ bInit=true,m_appConversation=\(conversation) ][MessageDataSourceMessageDataCollector.cpp(41) OnEnterConversation]"
}
func unreadZeroLine(_ conversation: String) -> String {
    "[app][unread nty!][ info.ccode=\(conversation),unReadNumber=0,this=0x123 ][AppConversationService.cpp(1632) DealConvUnreadNumUpdate]"
}
func feed(_ lines: String...) {
    for line in lines { reminder.consume(line) }
    reminder.refreshMessages()
}
feed(arrivalLine("first", convA))
checkUI(reminder.panel.isVisible && reminder.count == 1, "arrival shows card")
feed(clickLine(convB))
checkUI(reminder.panel.isVisible && reminder.count == 1, "unrelated conversation leaves card visible")
feed(autoEnterLine(convA), unreadZeroLine(convA))
checkUI(reminder.panel.isVisible && reminder.count == 1, "automatic entry and unread zero keep actual panel visible")
feed(clickLine(convA))
checkUI(!reminder.panel.isVisible && reminder.count == 0, "clicking matching native reminder closes actual panel")
feed(arrivalLine("second", convA), arrivalLine("third", convB))
feed(clickLine(convB))
checkUI(reminder.panel.isVisible && reminder.latestID == "second" && reminder.card.heading.contains("1 条"), "other pending customer remains with updated count")
feed("[app][OnClicked][ GetCurrentConversation().GetcCode()=\(convA),(int)type=0 ][ChatContentPresenter.cpp(1944) OnClicked]")
checkUI(!reminder.panel.isVisible, "explicit chat content click closes actual panel")
feed(arrivalLine("fourth", convA), autoEnterLine(convA), unreadZeroLine(convA))
checkUI(reminder.panel.isVisible && reminder.count == 1, "regression: arrival plus background read in same batch still shows panel")
feed(clickLine(convA))
checkUI(!reminder.panel.isVisible, "explicit click after automatic read still closes panel")
feed(arrivalLine("fifth", convA))
checkUI(reminder.panel.isVisible && reminder.count == 1, "fresh message after read shows card again")
reminder.dismiss()
feed(arrivalLine("fifth", convA))
checkUI(!reminder.panel.isVisible, "duplicate event never resurrects dismissed card")
print("All AppKit lifecycle checks passed.")

// Optional local replay: no customer details, avatars, IDs or raw logs are printed
// or stored in fixtures. Exercises the real app's parser, state and panel together.
if let index = CommandLine.arguments.firstIndex(of: "--replay-log"), CommandLine.arguments.count > index + 1 {
    let logData = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
    let log = String(decoding: logData, as: UTF8.self)
    reminder.dismiss()
    var arrivals = 0, automaticEvents = 0, matchingClicks = 0
    for rawLine in log.split(separator: "\n") {
        let line = String(rawLine)
        if let id = EventParser.messageID(line), !reminder.seen.contains(id) {
            feed(line)
            guard reminder.panel.isVisible else { fatalError("Replay: new arrival did not display panel") }
            arrivals += 1
        } else if let conversation = EventParser.handledConversation(line) {
            let matched = reminder.reminders.entries.contains { $0.conversation == conversation }
            feed(line)
            guard !reminder.reminders.entries.contains(where: { $0.conversation == conversation }) else {
                fatalError("Replay: explicit click did not remove matching reminder")
            }
            if matched { matchingClicks += 1 }
        } else if line.contains(") OnEnterConversation]") || line.contains(") DealConvUnreadNumUpdate]") {
            let previous = reminder.count
            feed(line)
            guard reminder.count == previous else { fatalError("Replay: automatic event removed reminder") }
            automaticEvents += 1
        }
    }
    reminder.dismiss()
    checkUI(arrivals > 0 && automaticEvents > 0 && matchingClicks > 0, "real log replay exercised arrivals, automatic updates and user clicks")
    print("Replay passed: \(arrivals) arrivals displayed; \(automaticEvents) automatic updates preserved reminders; \(matchingClicks) matching clicks handled.")
}
