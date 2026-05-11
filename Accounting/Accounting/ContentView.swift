//
//  ContentView.swift
//  Accounting
//
//  Created by LiuDC on 2026/4/26.
//

import Charts
import SwiftUI

struct ContentView: View {
    @StateObject private var store = LedgerStore()

    var body: some View {
        TabView {
            HomeView(store: store)
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }

            StatisticsView(store: store)
                .tabItem {
                    Label("统计", systemImage: "chart.bar.xaxis")
                }
        }
        .environment(\.locale, Locale(identifier: "zh_CN"))
    }
}

private struct HomeView: View {
    @ObservedObject var store: LedgerStore
    @State private var isShowingManualEntry = false
    @State private var isShowingVoiceEntry = false
    @State private var editingEntry: LedgerEntry?
    @State private var openedEntryID: UUID?
    @State private var isSelectingRecent = false
    @State private var selectedRecentIDs = Set<UUID>()

    private var monthRange: DateInterval { store.currentMonthRange }
    private var monthIncome: Decimal { store.total(for: .income, in: monthRange) }
    private var monthExpense: Decimal { store.total(for: .expense, in: monthRange) }
    private var monthBalance: Decimal { monthIncome - monthExpense }
    private var recentEntries: [LedgerEntry] { Array(store.entries.prefix(12)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("本月概览")
                            .font(.title2.bold())

                        HStack(spacing: 12) {
                            SummaryTile(title: "收入", amount: monthIncome, tint: .green)
                            SummaryTile(title: "支出", amount: monthExpense, tint: .red)
                        }

                        SummaryTile(title: "结余", amount: monthBalance, tint: monthBalance >= 0 ? .blue : .orange)
                    }

                    HStack(spacing: 12) {
                        Button {
                            isShowingVoiceEntry = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("语音记账", systemImage: "mic.fill")
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            isShowingManualEntry = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("手动输入", systemImage: "square.and.pencil")
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("最近明细")
                                .font(.headline)
                            Spacer()
                            if !recentEntries.isEmpty {
                                if isSelectingRecent {
                                    Button("删除") {
                                        store.delete(ids: selectedRecentIDs)
                                        selectedRecentIDs.removeAll()
                                        isSelectingRecent = false
                                    }
                                    .disabled(selectedRecentIDs.isEmpty)
                                    .foregroundStyle(selectedRecentIDs.isEmpty ? Color.secondary : Color.red)

                                    Button("取消") {
                                        selectedRecentIDs.removeAll()
                                        isSelectingRecent = false
                                    }
                                } else {
                                    Button("选择") {
                                        openedEntryID = nil
                                        isSelectingRecent = true
                                    }
                                }
                            }
                        }

                        if recentEntries.isEmpty {
                            ContentUnavailableView("还没有账目", systemImage: "tray", description: Text("可以先用语音或手动添加一笔"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 28)
                        } else {
                            ForEach(recentEntries) { entry in
                                EditableEntryRow(
                                    entry: entry,
                                    openedEntryID: $openedEntryID,
                                    isSelecting: isSelectingRecent,
                                    selectedIDs: $selectedRecentIDs
                                ) {
                                    editingEntry = entry
                                } onDelete: {
                                    store.delete(entry)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("极简记账")
            .sheet(isPresented: $isShowingManualEntry) {
                ManualEntryView(store: store)
            }
            .sheet(isPresented: $isShowingVoiceEntry) {
                VoiceEntryView(store: store)
            }
            .sheet(item: $editingEntry) { entry in
                ManualEntryView(store: store, entry: entry)
            }
        }
    }
}

private struct StatisticsView: View {
    @ObservedObject var store: LedgerStore
    @State private var rangeMode: RangeMode = .currentMonth
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var customEnd = Date()
    @State private var editingEntry: LedgerEntry?
    @State private var isSelectingDetails = false
    @State private var selectedDetailIDs = Set<UUID>()

    private var range: DateInterval {
        let calendar = Calendar.current
        switch rangeMode {
        case .currentMonth:
            return calendar.dateInterval(of: .month, for: Date())!
        case .lastMonth:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            return calendar.dateInterval(of: .month, for: lastMonth)!
        case .currentYear:
            return calendar.dateInterval(of: .year, for: Date())!
        case .custom:
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEnd)) ?? customEnd
            return DateInterval(start: calendar.startOfDay(for: customStart), end: end)
        }
    }

    private var filteredEntries: [LedgerEntry] { store.entries(in: range) }
    private var income: Decimal { store.total(for: .income, in: range) }
    private var expense: Decimal { store.total(for: .expense, in: range) }
    private var categorySpending: [CategorySpend] {
        ExpenseCategory.summary(from: filteredEntries)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("时间", selection: $rangeMode) {
                        ForEach(RangeMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if rangeMode == .custom {
                        DatePicker("开始", selection: $customStart, displayedComponents: .date)
                        DatePicker("结束", selection: $customEnd, displayedComponents: .date)
                    }
                }

                Section {
                    SummaryLine(title: "收入", amount: income, tint: .green)
                    SummaryLine(title: "支出", amount: expense, tint: .red)
                    SummaryLine(title: "结余", amount: income - expense, tint: income - expense >= 0 ? .blue : .orange)
                }

                Section("支出分类") {
                    if categorySpending.isEmpty {
                        ContentUnavailableView("这个时间段没有支出", systemImage: "chart.pie")
                    } else {
                        ExpenseCategoryChart(items: categorySpending)
                    }
                }

                Section {
                    if filteredEntries.isEmpty {
                        ContentUnavailableView("这个时间段没有账目", systemImage: "calendar")
                    } else {
                        ForEach(filteredEntries) { entry in
                            if isSelectingDetails {
                                HStack(spacing: 10) {
                                    SelectionIndicator(isSelected: selectedDetailIDs.contains(entry.id))
                                    EntryRow(entry: entry)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedDetailIDs.contains(entry.id) {
                                        selectedDetailIDs.remove(entry.id)
                                    } else {
                                        selectedDetailIDs.insert(entry.id)
                                    }
                                }
                            } else {
                                EntryRow(entry: entry)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            store.delete(entry)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }

                                        Button {
                                            editingEntry = entry
                                        } label: {
                                            Label("编辑", systemImage: "square.and.pencil")
                                        }
                                        .tint(.blue)
                                    }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("明细")
                        Spacer()
                        if !filteredEntries.isEmpty {
                            if isSelectingDetails {
                                Button("删除") {
                                    store.delete(ids: selectedDetailIDs)
                                    selectedDetailIDs.removeAll()
                                    isSelectingDetails = false
                                }
                                .disabled(selectedDetailIDs.isEmpty)
                                .foregroundStyle(selectedDetailIDs.isEmpty ? Color.secondary : Color.red)

                                Button("取消") {
                                    selectedDetailIDs.removeAll()
                                    isSelectingDetails = false
                                }
                            } else {
                                Button("选择") {
                                    isSelectingDetails = true
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("统计")
            .sheet(item: $editingEntry) { entry in
                ManualEntryView(store: store, entry: entry)
            }
        }
    }
}

private struct CategorySpend: Identifiable {
    var category: ExpenseCategory
    var amount: Decimal

    var id: ExpenseCategory { category }
    var amountDouble: Double { NSDecimalNumber(decimal: amount).doubleValue }
}

private enum ExpenseCategory: String, CaseIterable, Identifiable {
    case food = "餐饮"
    case shopping = "购物"
    case transport = "交通"
    case housing = "居住"
    case entertainment = "娱乐"
    case medical = "医疗"
    case learning = "学习办公"
    case social = "人情"
    case other = "其他"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .food: return .orange
        case .shopping: return .pink
        case .transport: return .blue
        case .housing: return .purple
        case .entertainment: return .cyan
        case .medical: return .red
        case .learning: return .indigo
        case .social: return .green
        case .other: return .gray
        }
    }

    static func category(for note: String) -> ExpenseCategory {
        let normalized = note.lowercased()
        let rules: [(ExpenseCategory, [String])] = [
            (.food, ["早餐", "早饭", "午餐", "午饭", "晚餐", "晚饭", "饭", "外卖", "餐", "吃", "咖啡", "奶茶", "水果", "零食", "超市买菜", "买菜", "菜"]),
            (.shopping, ["购物", "衣服", "鞋", "包", "日用品", "淘宝", "京东", "拼多多", "超市", "便利店", "物品"]),
            (.transport, ["交通", "地铁", "公交", "打车", "出租车", "滴滴", "高铁", "火车", "机票", "加油", "停车", "高速"]),
            (.housing, ["房租", "租金", "水电", "电费", "水费", "燃气", "物业", "宽带", "网费", "居住"]),
            (.entertainment, ["电影", "游戏", "旅游", "健身", "聚会", "娱乐", "演唱会", "门票", "会员"]),
            (.medical, ["药", "医院", "挂号", "体检", "医疗", "牙", "疫苗"]),
            (.learning, ["书", "课程", "学习", "文具", "办公", "打印", "软件", "订阅"]),
            (.social, ["红包", "礼物", "请客", "转账", "人情", "份子钱"])
        ]

        for (category, keywords) in rules where keywords.contains(where: normalized.contains) {
            return category
        }
        return .other
    }

    static func summary(from entries: [LedgerEntry]) -> [CategorySpend] {
        let grouped = entries
            .filter { $0.type == .expense }
            .reduce(into: [ExpenseCategory: Decimal]()) { result, entry in
                let category = ExpenseCategory.category(for: entry.note)
                result[category, default: .zero] += entry.amount
            }

        return ExpenseCategory.allCases.compactMap { category in
            guard let amount = grouped[category], amount > .zero else { return nil }
            return CategorySpend(category: category, amount: amount)
        }
        .sorted { $0.amount > $1.amount }
    }
}

private enum RangeMode: String, CaseIterable, Identifiable {
    case currentMonth = "本月"
    case lastMonth = "上月"
    case currentYear = "今年"
    case custom = "自定义"

    var id: String { rawValue }
}

private struct ExpenseCategoryChart: View {
    var items: [CategorySpend]

    private var total: Decimal {
        items.reduce(.zero) { $0 + $1.amount }
    }

    var body: some View {
        VStack(spacing: 14) {
            Chart(items) { item in
                SectorMark(
                    angle: .value("金额", item.amountDouble),
                    innerRadius: .ratio(0.56),
                    angularInset: 1.5
                )
                .foregroundStyle(item.category.color)
            }
            .frame(height: 210)
            .chartLegend(.hidden)

            VStack(spacing: 10) {
                ForEach(items) { item in
                    CategorySpendRow(item: item, total: total)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct CategorySpendRow: View {
    var item: CategorySpend
    var total: Decimal

    private var percentText: String {
        guard total > .zero else { return "0%" }
        let value = item.amountDouble / NSDecimalNumber(decimal: total).doubleValue
        return value.formatted(.percent.precision(.fractionLength(0)))
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(item.category.color)
                .frame(width: 10, height: 10)

            Text(item.category.rawValue)
                .font(.subheadline.weight(.medium))

            Text(percentText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(item.amount.currencyText)
                .font(.subheadline.weight(.semibold))
        }
    }
}

private struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LedgerStore

    private let entry: LedgerEntry?
    @State private var type: EntryType = .expense
    @State private var date = Date()
    @State private var channel: PaymentChannel = .wechat
    @State private var amountText = ""
    @State private var note = ""

    init(store: LedgerStore, entry: LedgerEntry? = nil) {
        self.store = store
        self.entry = entry
        _type = State(initialValue: entry?.type ?? .expense)
        _date = State(initialValue: entry?.date ?? Date())
        _channel = State(initialValue: entry?.channel ?? .wechat)
        _amountText = State(initialValue: entry?.amount.inputText ?? "")
        _note = State(initialValue: entry?.note ?? "")
    }

    private var amount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("类型", selection: $type) {
                        ForEach(EntryType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("金额", text: $amountText)
                        .keyboardType(.decimalPad)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("途径")
                            .foregroundStyle(.secondary)

                        ChannelPicker(selection: $channel)
                    }

                    DatePicker("时间", selection: $date)
                    TextField(type == .income ? "来源，例如工资" : "用途，例如早餐", text: $note)
                }
            }
            .navigationTitle(entry == nil ? "手动输入" : "编辑明细")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard let amount else { return }
                        let cleanedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        var savedEntry = LedgerEntry(
                            type: type,
                            date: date,
                            channel: channel,
                            amount: amount,
                            note: cleanedNote.isEmpty ? type.rawValue : cleanedNote,
                            rawText: entry?.rawText
                        )

                        if let entry {
                            savedEntry.id = entry.id
                            store.update(savedEntry)
                        } else {
                            store.add(savedEntry)
                        }
                        dismiss()
                    }
                    .disabled(amount == nil || amount == .zero)
                }
            }
        }
    }
}

private struct ChannelPicker: View {
    @Binding var selection: PaymentChannel

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
            ForEach(PaymentChannel.allCases) { channel in
                Button {
                    selection = channel
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: channel.iconName)
                        Text(channel.rawValue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(channel.tint)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selection == channel ? channel.tint.opacity(0.14) : Color.clear)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selection == channel ? channel.tint : channel.tint.opacity(0.28), lineWidth: selection == channel ? 1.5 : 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct VoiceEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: LedgerStore
    @StateObject private var recorder = VoiceRecorder()
    @State private var editableText = ""

    private var textForParsing: String {
        editableText.isEmpty ? recorder.transcript : editableText
    }

    private var parsed: ParsedEntry {
        EntryParser.parse(textForParsing)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        recorder.isRecording ? recorder.stop() : recorder.start()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color.accentColor)

                            HStack(spacing: 8) {
                                Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                Text(recorder.isRecording ? "停止录音" : "开始语音记账")
                            }
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .contentShape(RoundedRectangle(cornerRadius: 22))
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 12, leading: 26, bottom: 12, trailing: 26))

                    if let message = recorder.authorizationMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("识别文本") {
                    TextEditor(text: Binding(
                        get: { editableText.isEmpty ? recorder.transcript : editableText },
                        set: { editableText = $0 }
                    ))
                    .frame(minHeight: 110)
                }

                Section("解析结果") {
                    ParsedRow(title: "类型", value: parsed.type.rawValue)
                    ParsedRow(title: "金额", value: parsed.amount?.currencyText ?? "未识别")
                    ParsedChannelRow(channel: parsed.channel)
                    ParsedRow(title: "时间", value: parsed.date.ledgerText)
                    ParsedRow(title: parsed.type == .income ? "来源" : "用途", value: parsed.note)
                }
            }
            .navigationTitle("语音记账")
            .onAppear {
                recorder.requestPermission()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        recorder.stop()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard let entry = parsed.makeEntry() else { return }
                        store.add(entry)
                        recorder.stop()
                        dismiss()
                    }
                    .disabled(!parsed.canSave)
                }
            }
        }
    }
}

private struct SummaryTile: View {
    var title: String
    var amount: Decimal
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(amount.currencyText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SummaryLine: View {
    var title: String
    var amount: Decimal
    var tint: Color

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(amount.currencyText)
                .fontWeight(.semibold)
                .foregroundStyle(tint)
        }
    }
}

private struct EntryRow: View {
    var entry: LedgerEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.channel.iconName)
                .font(.body)
                .foregroundStyle(entry.channel.tint)
                .frame(width: 32, height: 32)
                .background(entry.channel.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.note)
                    .font(.body.weight(.medium))
                Text("\(entry.channel.rawValue) · \(entry.date.ledgerText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(entry.type.sign)\(entry.amount.currencyText)")
                .font(.body.weight(.semibold))
                .foregroundStyle(entry.type.tint)
        }
        .padding(.vertical, 6)
    }
}

private struct EditableEntryRow: View {
    var entry: LedgerEntry
    @Binding var openedEntryID: UUID?
    var isSelecting: Bool
    @Binding var selectedIDs: Set<UUID>
    var onEdit: () -> Void
    var onDelete: () -> Void
    @State private var dragOffset: CGFloat = 0

    private var offset: CGFloat {
        let base: CGFloat = openedEntryID == entry.id ? -128 : 0
        return min(0, max(-128, base + dragOffset))
    }

    var body: some View {
        if isSelecting {
            HStack(spacing: 10) {
                SelectionIndicator(isSelected: selectedIDs.contains(entry.id))
                EntryRow(entry: entry)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if selectedIDs.contains(entry.id) {
                    selectedIDs.remove(entry.id)
                } else {
                    selectedIDs.insert(entry.id)
                }
            }
        } else {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        openedEntryID = nil
                    }
                    onEdit()
                } label: {
                    Label("编辑", systemImage: "square.and.pencil")
                        .labelStyle(.iconOnly)
                        .frame(width: 64)
                        .frame(maxHeight: .infinity)
                }
                .foregroundStyle(.white)
                .background(.blue)

                Button(role: .destructive) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        openedEntryID = nil
                    }
                    onDelete()
                } label: {
                    Label("删除", systemImage: "trash")
                        .labelStyle(.iconOnly)
                        .frame(width: 64)
                        .frame(maxHeight: .infinity)
                }
                .foregroundStyle(.white)
                .background(.red)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))

            EntryRow(entry: entry)
                .background(Color(.systemBackground))
                .contentShape(Rectangle())
                .onTapGesture {
                    if openedEntryID != nil {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            openedEntryID = nil
                        }
                    }
                }
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 16)
                    .onChanged { value in
                        if openedEntryID != nil && openedEntryID != entry.id {
                            openedEntryID = nil
                        }

                        if value.translation.width < 0 || openedEntryID == entry.id {
                            dragOffset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        let finalOffset = offset
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            openedEntryID = finalOffset < -56 ? entry.id : nil
                            dragOffset = 0
                        }
                    }
            )
        }
        .clipped()
        }
    }
}

private struct SelectionIndicator: View {
    var isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(width: 24, height: 24)
    }
}

private struct ParsedRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct ParsedChannelRow: View {
    var channel: PaymentChannel

    var body: some View {
        HStack {
            Text("途径")
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: channel.iconName)
                Text(channel.rawValue)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(channel.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(channel.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(channel.tint.opacity(0.5), lineWidth: 1)
            }
        }
    }
}
