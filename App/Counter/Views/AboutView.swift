import SwiftUI

struct AboutView: View {
    let information: AppInformation
    let openHelp: () -> Void
    @State private var selection = 0
    @State private var licenceID = "app"

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 16) {
                Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                    .resizable().scaledToFit().frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(AppInformation.name).font(.title2.weight(.semibold))
                    Text(information.version).foregroundStyle(.secondary)
                    Text(AppInformation.author).fontWeight(.medium)
                }
                Spacer()
            }
            Picker("Information", selection: $selection) {
                Text("About").tag(0)
                Text("Licences").tag(1)
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 240)
            Group {
                if selection == 0 { credits }
                else { LicenceReaderView(information: information, licenceID: $licenceID) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                Text(AppInformation.copyright).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Help", action: openHelp)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var credits: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Live reception reports in your menu bar.").font(.headline)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Free software under the MIT License").fontWeight(.semibold)
                    Text("The app's original source and documentation are released under MIT. The libraries and system frameworks retain their own licences.")
                    Button("Read the MIT licence") { licenceID = "app"; selection = 1 }
                    if let url = information.sourceRepository { Link("Source code on GitHub", destination: url) }
                }
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reception data").font(.headline)
                    Text("PSK Reporter by Philip Gladstone. Live MQTT distribution provided by Tom (M0LTE), using PSK Reporter data with permission.")
                    HStack(spacing: 18) {
                        Link("PSK Reporter", destination: URL(string: "https://pskreporter.info/")!)
                        Link("MQTT feed", destination: URL(string: "https://www.mqtt.pskreporter.info/")!)
                    }
                    Text("PSK Reporter Counter is an independent application.").foregroundStyle(.secondary)
                }
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Libraries and frameworks").font(.headline)
                    Text("CocoaMQTT and MqttCocoaAsyncSocket provide the live connection. The interface uses Swift, AppKit, SwiftUI and Swift Charts, with Apple's macOS system frameworks.")
                    Button("View all acknowledgements and licences") { selection = 1 }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .textSelection(.enabled)
        }
    }

}

struct LicenceReaderView: View {
    let information: AppInformation
    @Binding var licenceID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = information.loadError {
                Text(error).foregroundStyle(.secondary).textSelection(.enabled)
            } else {
                Picker("Component", selection: $licenceID) {
                    ForEach(information.components) { Text($0.title).tag($0.id) }
                }.accessibilityIdentifier("licencePicker")
                if let component = information.components.first(where: { $0.id == licenceID }) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(component.licence).font(.headline)
                        Text(component.credit).font(.callout)
                        Text(component.summary).font(.caption).foregroundStyle(.secondary)
                        if let url = component.url { Link("Project and licence information", destination: url).font(.caption) }
                    }.textSelection(.enabled)
                    Divider()
                    ScrollView {
                        Text(information.licenceTexts[component.id] ?? "")
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    .id(component.id)
                }
            }
        }.padding(18)
    }
}
