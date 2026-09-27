import Foundation

struct Catalogue: Decodable {
    struct Component: Decodable {
        let id: String
        let title: String
        let packageIdentity: String?
        let version: String?
        let files: [String]
    }
    let components: [Component]
}

struct Resolved: Decodable {
    struct Pin: Decodable {
        struct State: Decodable { let version: String }
        let identity: String
        let state: State
    }
    let pins: [Pin]
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("Licence validation failed: \(message)\n".utf8))
    exit(1)
}

guard CommandLine.arguments.count == 2 else { fail("Supply the built app bundle path.") }
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("Contents/Resources")
do {
    let data = try Data(contentsOf: resources.appendingPathComponent("Acknowledgements.json"))
    let sourceData = try Data(contentsOf: root.appendingPathComponent("Resources/Acknowledgements.json"))
    guard data == sourceData else { fail("The bundled catalogue differs from the source catalogue.") }
    let catalogue = try JSONDecoder().decode(Catalogue.self, from: data)
    let resolved = try JSONDecoder().decode(Resolved.self, from: Data(contentsOf: root.appendingPathComponent("Package.resolved")))
    guard Set(catalogue.components.map(\.id)).count == catalogue.components.count,
          catalogue.components.contains(where: { $0.id == "app" }) else { fail("Missing app licence or repeated component identifiers.") }
    var checkedFiles = Set<String>()
    for component in catalogue.components {
        guard !component.files.isEmpty else { fail("\(component.title) has no licence documents.") }
        if let identity = component.packageIdentity {
            guard resolved.pins.first(where: { $0.identity == identity })?.state.version == component.version else {
                fail("\(component.title) does not match Package.resolved. Review its licence attribution.")
            }
        }
        for file in component.files {
            guard file == "LICENSE.txt" || (file.hasPrefix("ThirdPartyLicences/") && !file.contains("..")) else {
                fail("Unexpected licence resource path: \(file)")
            }
            let bundled = try Data(contentsOf: resources.appendingPathComponent(file))
            guard let text = String(data: bundled, encoding: .utf8),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { fail("\(file) is empty or unreadable.") }
            let source = try Data(contentsOf: root.appendingPathComponent(file == "LICENSE.txt" ? "LICENSE" : file))
            guard source == bundled else { fail("\(file) differs from its source copy.") }
            checkedFiles.insert(file)
        }
    }
    for pin in resolved.pins {
        guard catalogue.components.contains(where: { $0.packageIdentity == pin.identity }) else {
            fail("No licence entry for resolved package \(pin.identity).")
        }
    }
    print("Verified \(catalogue.components.count) licence entries and \(checkedFiles.count) complete documents in the app bundle.")
} catch { fail(error.localizedDescription) }
