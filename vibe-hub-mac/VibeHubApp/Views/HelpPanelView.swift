import SwiftUI

struct HelpPanelView: View {
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !compact {
                Text("本地说明")
                    .font(.system(size: 14, weight: .semibold))
            }

            Text("当前支持的目标")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                helpRow(title: "Codex", detail: "已接入真实 bridge / opencli 发送链路")
                helpRow(title: "当前应用", detail: "预留目标，用于未来更细的前台应用分发")
                helpRow(title: "OpenClaw 调度器", detail: "预留目标，用于未来 session / agent 分发")
                helpRow(title: "Echo 审阅", detail: "预留目标，用于总结/反思路径")
                helpRow(title: "财神", detail: "保留现有目标位，等待后续真实接入")
            }

            Text("说明")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Vibe Hub 当前负责展示、编辑、状态和发送入口；输入来自 OpenClaw + bridge，输出通过 bridge + opencli / Codex。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(compact ? 0 : 18)
        .frame(width: compact ? nil : 320)
        .background(compact ? AnyShapeStyle(.clear) : AnyShapeStyle(.ultraThinMaterial), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(compact ? .clear : .white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(compact ? 0 : 0.12), radius: 16, y: 10)
    }

    private func helpRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
