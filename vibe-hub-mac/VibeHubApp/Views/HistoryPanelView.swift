import SwiftUI

struct HistoryPanelView: View {
    let entries: [SendHistoryEntry]
    @State private var searchText: String = ""
    @State private var selectedTarget: String = "全部目标"
    @State private var selectedStatus: String = "全部状态"
    @State private var selectedDate: String = "全部日期"
    @State private var expandedIds: Set<UUID> = []

    private var targets: [String] {
        ["全部目标"] + Array(Set(entries.map(\.target))).sorted()
    }

    private var statuses: [String] {
        ["全部状态"] + Array(Set(entries.map(\.status))).sorted()
    }

    private var dates: [String] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let set = Set(entries.map { fmt.string(from: $0.createdAt) })
        return ["全部日期"] + Array(set).sorted(by: >)
    }

    private var filteredEntries: [SendHistoryEntry] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return entries.filter { entry in
            let targetMatch = selectedTarget == "全部目标" || entry.target == selectedTarget
            let statusMatch = selectedStatus == "全部状态" || entry.status == selectedStatus
            let dateMatch = selectedDate == "全部日期" || fmt.string(from: entry.createdAt) == selectedDate
            let haystack = [entry.target, entry.text, entry.summary ?? "", entry.status]
                .joined(separator: " ")
            let searchMatch = searchText.isEmpty || haystack.localizedCaseInsensitiveContains(searchText)
            return targetMatch && statusMatch && dateMatch && searchMatch
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("发送历史")
                            .font(.system(size: 14, weight: .semibold))
                        Text("已发送卡片")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(filteredEntries.count) 张")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.08), in: Capsule())
                }

                HStack(spacing: 8) {
                    TextField("搜索关键词 / 目标 / 状态 / 文本", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    Picker("目标", selection: $selectedTarget) {
                        ForEach(targets, id: \.self) { target in
                            Text(target).tag(target)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    Picker("状态", selection: $selectedStatus) {
                        ForEach(statuses, id: \.self) { status in
                            Text(status).tag(status)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    Picker("日期", selection: $selectedDate) {
                        ForEach(dates, id: \.self) { date in
                            Text(date).tag(date)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }

                if filteredEntries.isEmpty {
                    Text("没有符合条件的发送记录。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(filteredEntries) { entry in
                            let expanded = expandedIds.contains(entry.id)
                            VStack(alignment: .leading, spacing: 8) {
                                Button {
                                    toggleExpand(entry.id)
                                } label: {
                                    HStack {
                                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text(entry.target)
                                            .font(.system(size: 11, weight: .semibold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.white.opacity(0.08), in: Capsule())
                                        Text(entry.status)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                Text(displaySummary(for: entry))
                                    .font(.system(size: 12, weight: .medium))

                                if expanded {
                                    Text(cleanHistoryText(entry.text))
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)

                                    HStack {
                                        Button("再次发送") {}
                                        Button("编辑后发送") {}
                                        Button("转发给其他目标") {}
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(12)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
            .padding(20)
        }
        .scrollIndicators(.visible)
        .frame(minWidth: 500, minHeight: 680)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 16, y: 10)
    }

    private func toggleExpand(_ id: UUID) {
        if expandedIds.contains(id) {
            expandedIds.remove(id)
        } else {
            expandedIds.insert(id)
        }
    }

    private func summarize(_ text: String) -> String {
        let cleaned = cleanHistoryText(text).replacingOccurrences(of: "\n", with: " ")
        return cleaned.count > 56 ? String(cleaned.prefix(56)) + "…" : cleaned
    }

    private func displaySummary(for entry: SendHistoryEntry) -> String {
        let cleanedSummary = cleanHistoryText(entry.summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedSummary.isEmpty {
            return cleanedSummary
        }
        return summarize(entry.text)
    }

    private func cleanHistoryText(_ text: String) -> String {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                guard !line.isEmpty else { return false }
                if line.allSatisfy({ "-|─┌┬┐└┴┘├┼│ ".contains($0) }) {
                    return false
                }
                return true
            }
        return lines.joined(separator: "\n")
    }
}
