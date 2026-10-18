import Foundation

struct MessageDetail {
    let customer: String
    let account: String
    let customerID: String
}

enum EventParser {
    private static let messagePattern = try! NSRegularExpression(pattern: #"msg\.msg\.code\.messageId=([^,\] ]+)"#)
    private static let portraitPattern = try! NSRegularExpression(pattern: #"target:(\d+):3, url:(https://img\.alicdn\.com/[^,\s\]]+)"#)

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
                return (id, MessageDetail(customer: from["nick"] as? String ?? "", account: to["nick"] as? String ?? "", customerID: from["targetId"] as? String ?? ""))
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
