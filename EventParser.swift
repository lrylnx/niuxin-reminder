import Foundation

struct MessageDetail {
    let customer: String
    let account: String
    let customerID: String
    var conversationCode: String = ""
}

enum EventParser {
    private static let messagePattern = try! NSRegularExpression(pattern: #"msg\.msg\.code\.messageId=([^,\] ]+)"#)
    private static let portraitPattern = try! NSRegularExpression(pattern: #"target:(\d+):3, url:(https://img\.alicdn\.com/[^,\s\]]+)"#)

    private static func value(_ key: String, in line: String) -> String? {
        guard let start = line.range(of: key + "=") else { return nil }
        let value = line[start.upperBound...].prefix { !$0.isWhitespace && $0 != "," && $0 != "]" }
        return value.isEmpty ? nil : String(value)
    }

    static func arrivalConversation(_ line: String) -> String? {
        guard messageID(line) != nil else { return nil }
        return value("msg.msg.conversationCode", in: line)
    }

    // Require an explicit user click. Qianniu also enters conversations and
    // clears unread counts automatically on arrival, even without user input.
    static func handledConversation(_ line: String) -> String? {
        if line.contains("][CMessageMergeNotifyPresenter OnClicked]["),
           line.contains("MessageMergeNotifyPresenter.cpp("),
           line.contains(") OnTreeNodeOrTagClick]") {
            return value("ccode", in: line)
        }
        if line.contains("][OnClicked]["),
           line.contains("ChatContentPresenter.cpp("),
           line.contains(") OnClicked]") {
            return value("GetCurrentConversation().GetcCode()", in: line)
        }
        return nil
    }

    static func messageID(_ line: String) -> String? {
        guard line.contains("][OnMessageArrive]["), line.contains("ChatService.cpp"),
              let match = messagePattern.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else { return nil }
        return String(line[range])
    }

    static func details(_ line: String) -> [(String, MessageDetail)] {
        guard line.contains("strEvent=im.singlemsg.onShopRobotReceriveNewMsgs"),
              let start = line.range(of: "jsonStr="),
              let end = line.range(of: ",strEvent=", range: start.upperBound..<line.endIndex),
              let data = String(line[start.upperBound..<end.lowerBound]).data(using: .utf8),
              let events = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return [] }
        return events.flatMap { event -> [(String, MessageDetail)] in
            (event["newmsgs"] as? [[String: Any]] ?? []).compactMap { message in
                guard let code = message["mcode"] as? [String: Any], let id = code["messageId"] as? String else { return nil }
                let from = message["fromId"] as? [String: Any] ?? [:]
                let to = message["toId"] as? [String: Any] ?? [:]
                let conversation = event["cid"] as? [String: Any] ?? [:]
                return (id, MessageDetail(customer: from["nick"] as? String ?? "", account: to["nick"] as? String ?? "", customerID: from["targetId"] as? String ?? "", conversationCode: conversation["ccode"] as? String ?? ""))
            }
        }
    }

    static func portraits(_ line: String) -> [(String, String)] {
        guard line.contains("FetchProfilePortrait begin") else { return [] }
        return portraitPattern.matches(in: line, range: NSRange(line.startIndex..., in: line)).compactMap { match in
            guard let id = Range(match.range(at: 1), in: line), let url = Range(match.range(at: 2), in: line) else { return nil }
            return (String(line[id]), String(line[url]))
        }
    }
}
