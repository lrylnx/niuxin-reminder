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
func enterLine(_ conversation: String) -> String {
    "[app][EnterConversation][ bInit=true,m_appConversation=\(conversation) ][MessageDataSourceMessageDataCollector.cpp(41) OnEnterConversation]"
}
func feed(_ lines: String...) {
    for line in lines { reminder.consume(line) }
    reminder.refreshMessages()
}
feed(arrivalLine("first", convA))
checkUI(reminder.panel.isVisible && reminder.count == 1, "arrival shows card")
feed(enterLine(convB))
checkUI(reminder.panel.isVisible && reminder.count == 1, "unrelated conversation leaves card visible")
feed(enterLine(convA))
checkUI(!reminder.panel.isVisible && reminder.count == 0, "entering matching native conversation closes actual panel")
feed(arrivalLine("second", convA), arrivalLine("third", convB))
feed(enterLine(convB))
checkUI(reminder.panel.isVisible && reminder.latestID == "second" && reminder.card.heading.contains("1 条"), "other pending customer remains with updated count")
feed("[app][unread nty!][ info.ccode=\(convA),unReadNumber=0,this=0x123 ][AppConversationService.cpp(1632) DealConvUnreadNumUpdate]")
checkUI(!reminder.panel.isVisible, "zero unread closes actual panel")
feed(arrivalLine("fourth", convA), enterLine(convA))
checkUI(!reminder.panel.isVisible, "same-batch handled arrival stays hidden")
feed(arrivalLine("fifth", convA))
checkUI(reminder.panel.isVisible && reminder.count == 1, "fresh message after read shows card again")
reminder.dismiss()
feed(arrivalLine("fifth", convA))
checkUI(!reminder.panel.isVisible, "duplicate event never resurrects dismissed card")
print("All AppKit lifecycle checks passed.")
