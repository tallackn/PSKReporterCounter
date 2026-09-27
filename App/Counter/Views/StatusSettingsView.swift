import SwiftUI

struct StatusSettingsView: View {
    let presentation: MonitorStatusPresentation
    let canReconnect: Bool
    let reconnect: () -> Void
    let dismissIssue: () -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(presentation.title).fontWeight(.medium)
                    Spacer()
                    Button("Reconnect", action: reconnect).disabled(!canReconnect)
                }
                if let timing = presentation.timing {
                    Text(timing).font(.caption).foregroundStyle(.secondary)
                }
                ScrollView {
                    Text(presentation.detail)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(presentation.isError ? Color.primary : Color.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.frame(height: presentation.isError ? 112 : 58)
                if presentation.canDismiss {
                    Button("Dismiss settings error", action: dismissIssue).font(.caption)
                }
            }.padding(10)
        } label: { Text("Status").fontWeight(.semibold) }
    }
}
