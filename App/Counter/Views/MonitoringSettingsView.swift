import PSKReporterCore
import SwiftUI

struct MonitoringSettingsView: View {
    @Binding var callsign: String
    @Binding var interval: ReportingInterval
    @Binding var band: RadioBand
    @Binding var mode: OperatingMode
    @Binding var countUniqueStations: Bool
    let actionTitle: String
    let canApply: Bool
    let focusCallsign: Bool
    let apply: () -> Void
    @FocusState private var callsignFocused: Bool

    private var validCallsign: Bool { Callsign.isValid(callsign) }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Callsign").frame(width: 145, alignment: .leading)
                    TextField("e.g. ZL1ABC", text: $callsign)
                        .textFieldStyle(.roundedBorder)
                        .focused($callsignFocused)
                        .onSubmit { apply() }
                        .accessibilityIdentifier("callsignField")
                }
                HStack {
                    Text("Window length").frame(width: 145, alignment: .leading)
                    Picker("Window length", selection: $interval) {
                        ForEach(ReportingInterval.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().frame(width: 155)
                    Spacer()
                }
                HStack {
                    Text("Band").frame(width: 145, alignment: .leading)
                    Picker("Band", selection: $band) {
                        ForEach(RadioBand.allCases) { Text($0.label).tag($0) }
                    }.labelsHidden().frame(width: 155).accessibilityIdentifier("bandPicker")
                    Spacer()
                }
                HStack {
                    Text("Mode").frame(width: 145, alignment: .leading)
                    Picker("Mode", selection: $mode) {
                        ForEach(OperatingMode.allCases) { Text($0.label).tag($0) }
                    }.labelsHidden().frame(width: 155).accessibilityIdentifier("modePicker")
                    Spacer()
                }
                Toggle("Count unique stations", isOn: $countUniqueStations)
                    .accessibilityIdentifier("uniqueStationsToggle")
                Text("Show reports arriving in the last \(interval.label). The count and graphs update every second.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    if !callsign.isEmpty && !validCallsign {
                        Text("Use letters, numbers and optional / or - separators.")
                            .font(.caption).foregroundStyle(.red)
                    } else {
                        Text(countUniqueStations ? "Use the first report per receiving station in the window."
                             : "Count every report, including repeated reports from the same station.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Button(actionTitle, action: apply)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canApply)
                        .accessibilityIdentifier("apply")
                }
            }.padding(10)
        } label: { Text("Monitoring").fontWeight(.semibold) }
        .onAppear { callsignFocused = focusCallsign }
    }
}
