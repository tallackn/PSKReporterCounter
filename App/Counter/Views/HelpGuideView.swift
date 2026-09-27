import SwiftUI

struct HelpGuideView: View {
    let openSettings: () -> Void
    @State private var selectedTopic: HelpTopic? = .gettingStarted
    @State private var search = ""

    private var topics: [HelpTopic] { HelpTopic.allCases.filter { $0.matches(search) } }

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                List(selection: $selectedTopic) {
                    ForEach(topics) { topic in
                        Label(topic.title, systemImage: topic.symbol).tag(topic)
                    }
                }
                .frame(minWidth: 210, idealWidth: 220)
                .navigationTitle("Contents")
                .navigationSplitViewColumnWidth(min: 210, ideal: 220, max: 270)
                .searchable(text: $search, prompt: "Search Help")
            } detail: {
                if let topic = selectedTopic, topics.contains(topic) {
                    ScrollView {
                        HelpTopicContent(topic: topic)
                            .padding(26)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.id(topic)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.title)
                        Text("No matching help topics").font(.headline)
                        Text("Try a different word, such as callsign, signal or login.")
                            .foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            Divider()
            HStack {
                Text("PSK Reporter Counter Help").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Open Settings…", action: openSettings)
            }.padding(14)
        }
        .onChange(of: search) { _ in
            if selectedTopic.map({ !topics.contains($0) }) ?? true { selectedTopic = topics.first }
        }
    }
}

struct HelpTopicContent: View {
    let topic: HelpTopic

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(topic.title).font(.title.weight(.semibold))
            ForEach(topic.sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title).font(.headline)
                    Text(section.body).fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
            }
        }.textSelection(.enabled)
    }
}
