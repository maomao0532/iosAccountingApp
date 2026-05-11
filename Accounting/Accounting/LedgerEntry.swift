//
//  LedgerEntry.swift
//  Accounting
//

import Foundation
import SwiftUI

enum EntryType: String, Codable, CaseIterable, Identifiable {
    case expense = "支出"
    case income = "收入"

    var id: String { rawValue }

    var tint: Color {
        switch self {
        case .expense: return .red
        case .income: return .green
        }
    }

    var sign: String {
        switch self {
        case .expense: return "-"
        case .income: return "+"
        }
    }
}

enum PaymentChannel: String, Codable, CaseIterable, Identifiable {
    case wechat = "微信"
    case alipay = "支付宝"
    case bankCard = "银行卡"
    case cash = "现金"
    case other = "其他"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .wechat: return "message.fill"
        case .alipay: return "a.circle.fill"
        case .bankCard: return "creditcard.fill"
        case .cash: return "banknote.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .wechat: return .green
        case .alipay: return .blue
        case .bankCard: return .purple
        case .cash: return .orange
        case .other: return .gray
        }
    }
}

struct LedgerEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: EntryType
    var date: Date
    var channel: PaymentChannel
    var amount: Decimal
    var note: String
    var rawText: String?

    var amountDouble: Double {
        NSDecimalNumber(decimal: amount).doubleValue
    }
}

extension Decimal {
    var currencyText: String {
        let number = NSDecimalNumber(decimal: self)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: number) ?? "¥0"
    }

    var inputText: String {
        NSDecimalNumber(decimal: self).stringValue
    }
}

extension Date {
    var ledgerText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: self)
    }
}
