import Foundation

struct LicenceComponent: Decodable, Identifiable {
    let id: String
    let title: String
    let licence: String
    let credit: String
    let summary: String
    let url: URL?
    let files: [String]

    func fullText(in resourceDirectory: URL) throws -> String {
        try files.map { file in
            let text = try String(contentsOf: resourceDirectory.appendingPathComponent(file), encoding: .utf8)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return text
        }.joined(separator: "\n\n----------------------------------------\n\n")
    }
}

struct LicenceCatalogue: Decodable {
    let components: [LicenceComponent]
}

struct AppInformation {
    static let name = "PSK Reporter Counter"
    static let author = "Nathan Tallack (ZL2NU)"
    static let copyright = "Copyright © 2026 Nathan Tallack (ZL2NU)"
    static let privacyPolicy = URL(string: "https://github.com/tallackn/PSKReporterCounter/blob/main/PRIVACY.md")!
    static let support = URL(string: "https://github.com/tallackn/PSKReporterCounter/blob/main/SUPPORT.md")!

    let version: String
    let sourceRepository: URL?
    let components: [LicenceComponent]
    let licenceTexts: [String: String]
    let loadError: String?

    init(bundle: Bundle = .main) {
        let release = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        version = build.map { "Version \(release) (\($0))" } ?? release
        // Both distribution and development bundles provide the source URL.
        sourceRepository = (bundle.object(forInfoDictionaryKey: "PSKSourceRepositoryURL") as? String)
            .flatMap(URL.init(string:)).flatMap { $0.scheme == "https" && $0.host != nil ? $0 : nil }
        do {
            guard let directory = bundle.resourceURL else { throw CocoaError(.fileNoSuchFile) }
            let catalogue = try JSONDecoder().decode(LicenceCatalogue.self,
                from: Data(contentsOf: directory.appendingPathComponent("Acknowledgements.json")))
            var texts: [String: String] = [:]
            for component in catalogue.components { texts[component.id] = try component.fullText(in: directory) }
            components = catalogue.components
            licenceTexts = texts
            loadError = nil
        } catch {
            components = []
            licenceTexts = [:]
            loadError = "The bundled licence documents could not be read. Please reinstall the app.\n\(error.localizedDescription)"
        }
    }
}
