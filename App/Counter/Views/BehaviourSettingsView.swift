import SwiftUI

struct BehaviourSettingsView: View {
    @Binding var hideDockIcon: Bool
    @Binding var launchAtLogin: Bool
    let isUpdating: Bool
    let statusDescription: String
    let showLoginSettings: Bool
    let openLoginSettings: () -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Hide Dock icon", isOn: $hideDockIcon)
                    .accessibilityIdentifier("hideDockToggle")
                Text("Settings remain available from the menu bar icon.")
                    .font(.caption).foregroundStyle(.secondary).padding(.leading, 20)
                Toggle("Launch automatically at login", isOn: $launchAtLogin)
                    .disabled(isUpdating)
                    .accessibilityIdentifier("launchAtLoginToggle")
                HStack {
                    Text(statusDescription).font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    if showLoginSettings {
                        Button("Open Login Items", action: openLoginSettings).font(.caption)
                    }
                }.padding(.leading, 20)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
        } label: { Text("Behaviour").fontWeight(.semibold) }
    }
}
