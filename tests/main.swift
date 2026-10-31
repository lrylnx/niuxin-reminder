import Foundation

func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    guard condition() else { fatalError("FAILED: \(name)") }
    print("PASS: \(name)")
}
let arrival = "[app][OnMessageArrive][ msg.msg.code.messageId=demo-42,msg.msg.msgType=101 ][ChatService.cpp(197) OnMessageArrive]"
check(EventParser.messageID(arrival) == "demo-42", "arrival ID")
check(EventParser.messageID("[MessageSDK][OnAddedMessages] demo-42") == nil, "ignore SDK duplicates")
check(EventParser.messageID("[app][OnMessageArrive][ malformed ][ChatService.cpp]") == nil, "malformed arrival")
let json = #"[{"newmsgs":[{"mcode":{"messageId":"demo-42"},"fromId":{"nick":"客户🌟","targetId":"123"},"toId":{"nick":"示例店:客服"}}]}]"#
let detailLine = "[app][ jsonStr=\(json),strEvent=im.singlemsg.onShopRobotReceriveNewMsgs ]"
let details = EventParser.details(detailLine)
check(details.count == 1 && details[0].0 == "demo-42", "metadata correlates by message ID")
check(details[0].1.customer == "客户🌟" && details[0].1.account == "示例店:客服", "Unicode names and account")
check(details[0].1.customerID == "123", "avatar identity")
check(EventParser.details("jsonStr={broken,strEvent=im.singlemsg.onShopRobotReceriveNewMsgs").isEmpty, "malformed JSON")
check(EventParser.details(detailLine.replacingOccurrences(of: "im.singlemsg", with: "im.imbamsg")).isEmpty, "ignore non-chat events")
let portraits = EventParser.portraits("[FetchProfilePortrait begin][ target:123:3, url:https://img.alicdn.com/example.jpg, type:0,target:456:3, url:https://img.alicdn.com/other.jpg, type:0]")
check(portraits.count == 2 && portraits[1].0 == "456", "multiple avatar identities")
check(EventParser.portraits("[FetchProfilePortrait begin] target:123:3, url:https://img.alicdn.com.evil.invalid/x, type:0").isEmpty, "exact avatar host")
let conversationA = "100.1-200.1#11001@cntaobao"
let conversationB = "300.1-200.1#11001@cntaobao"
let otherAccount = "100.1-400.1#11001@cntaobao"
let enter = "[app][EnterConversation][ bInit=true,m_appConversation=\(conversationA) ][MessageDataSourceMessageDataCollector.cpp(41) OnEnterConversation]"
let unread = "[app][unread nty!][ info.ccode=\(conversationA),unReadNumber=0,this=0x123 ][AppConversationService.cpp(1632) DealConvUnreadNumUpdate]"
check(EventParser.arrivalConversation(arrival.replacingOccurrences(of: "msg.msg.msgType=101", with: "msg.msg.msgType=101,msg.msg.conversationCode=\(conversationA)")) == conversationA, "arrival conversation identity")
check(EventParser.handledConversation(enter) == conversationA, "enter conversation")
check(EventParser.handledConversation(enter.replacingOccurrences(of: "bInit=true", with: "bInit=false")) == conversationA, "return to existing conversation")
check(EventParser.handledConversation(unread) == conversationA, "unread cleared")
check(EventParser.handledConversation(unread.replacingOccurrences(of: "unReadNumber=0", with: "unReadNumber=1")) == nil, "positive unread keeps reminder")
check(EventParser.handledConversation(unread.replacingOccurrences(of: "unReadNumber=0", with: "unReadNumber=01")) == nil, "require exact zero")
check(EventParser.handledConversation(enter.replacingOccurrences(of: "m_appConversation=\(conversationA)", with: "m_appConversation=")) == nil, "missing conversation ignored")
check(EventParser.handledConversation(enter.replacingOccurrences(of: "MessageDataSourceMessageDataCollector.cpp", with: "Other.cpp")) == nil, "ignore unrelated log source")
check(EventParser.handledConversation("[BCMessageImp.cpp@OnReadStatusChanged@309] dmsg.is_read=true,dmsg.cid=\(conversationA)") == nil, "buyer read receipts never dismiss reminders")
let correlatedJSON = json.replacingOccurrences(of: "\"newmsgs\":", with: "\"cid\":{\"ccode\":\"\(conversationA)\"},\"newmsgs\":")
check(EventParser.details("jsonStr=\(correlatedJSON),strEvent=im.singlemsg.onShopRobotReceriveNewMsgs").first?.1.conversationCode == conversationA, "metadata conversation fallback")

var reminders = PendingReminders()
reminders.add("a1", conversation: conversationA)
reminders.add("a2", conversation: conversationA)
reminders.add("b1", conversation: conversationB)
reminders.add("other-account", conversation: otherAccount)
reminders.add("a1", conversation: conversationA)
check(reminders.count == 4, "pending message deduplication")
check(reminders.handle(conversationA) && reminders.count == 2, "read clears all messages for only that conversation")
check(reminders.latestID == "other-account", "same buyer on another account remains")
check(!reminders.handle(conversationA), "repeated read event is harmless")
reminders.handle(otherAccount)
check(reminders.latestID == "b1" && reminders.count == 1, "fall back to older unhandled customer")
reminders.handle(conversationB)
check(reminders.latestID == nil && reminders.count == 0, "last conversation closes reminder")
reminders.add("new-a", conversation: conversationA)
check(reminders.count == 1, "new message after read still reminds")
reminders.add("unknown", conversation: "")
check(!reminders.handle(""), "unknown identity never clears reminders")
reminders.associate("unknown", conversation: conversationB)
reminders.handle(conversationB)
check(reminders.latestID == "new-a", "late metadata associates pending message")
reminders.clear()
check(reminders.count == 0, "manual dismissal clears pending state")
reminders.associate("new-a", conversation: conversationA)
check(reminders.count == 0, "late metadata never resurrects dismissed message")
for index in 0..<2001 { reminders.add("bounded-\(index)", conversation: conversationA) }
check(reminders.count == 2000 && reminders.latestID == "bounded-2000", "pending state stays bounded")
print("All parser and reminder lifecycle checks passed.")
