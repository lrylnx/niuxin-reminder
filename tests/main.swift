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
print("All 10 parser checks passed.")
