//
//  EntryParser.swift
//  Accounting
//

import Foundation

struct ParsedEntry {
    var type: EntryType
    var date: Date
    var channel: PaymentChannel
    var amount: Decimal?
    var note: String
    var rawText: String

    var canSave: Bool {
        amount != nil && !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func makeEntry() -> LedgerEntry? {
        guard let amount else { return nil }
        return LedgerEntry(type: type, date: date, channel: channel, amount: amount, note: note, rawText: rawText)
    }
}

enum EntryParser {
    static func parse(_ text: String, now: Date = Date()) -> ParsedEntry {
        let normalized = text.replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "。", with: ",")
            .replacingOccurrences(of: "、", with: ",")

        let type = parseType(from: normalized)
        let channel = parseChannel(from: normalized)
        let amount = parseAmount(from: normalized)
        let note = parseNote(from: normalized, type: type)

        return ParsedEntry(type: type, date: now, channel: channel, amount: amount, note: note, rawText: text)
    }

    private static func parseType(from text: String) -> EntryType {
        let incomeWords = ["收入", "收到", "到账", "入账", "工资", "奖金", "报销", "转入", "收款", "赚"]
        if incomeWords.contains(where: text.contains) {
            return .income
        }
        return .expense
    }

    private static func parseChannel(from text: String) -> PaymentChannel {
        if text.contains("微信") { return .wechat }
        if text.contains("支付宝") || text.localizedCaseInsensitiveContains("alipay") { return .alipay }
        if text.contains("银行卡") || text.contains("银行") || text.contains("信用卡") || text.contains("储蓄卡") { return .bankCard }
        if text.contains("现金") { return .cash }
        return .other
    }

    private static func parseAmount(from text: String) -> Decimal? {
        let pattern = #"(\d+(?:\.\d+)?)\s*(?:元|块|人民币|rmb|RMB)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return Decimal(string: String(text[range]))
    }

    private static func parseNote(from text: String, type: EntryType) -> String {
        let markers = type == .income
            ? ["来自", "来源是", "来源", "作为", "工资", "奖金", "报销", "收入"]
            : ["用于购买", "用来购买", "用于", "买了", "购买", "买", "用于买"]

        for marker in markers where text.contains(marker) {
            let parts = text.components(separatedBy: marker)
            if let tail = parts.last {
                let cleaned = cleanNote(tail)
                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }

        if type == .income {
            if text.contains("工资") { return "工资" }
            if text.contains("奖金") { return "奖金" }
            if text.contains("报销") { return "报销" }
        }

        return type == .income ? "收入" : "日常消费"
    }

    private static func cleanNote(_ text: String) -> String {
        var result = text
        ["。", "，", ",", "元", "块"].forEach { result = result.replacingOccurrences(of: $0, with: " ") }
        result = result.replacingOccurrences(of: #"\d+(?:\.\d+)?"#, with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
