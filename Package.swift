// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PSKReporterCounter",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "PSKReporterCore", targets: ["PSKReporterCore"]),
        .executable(name: "PSKReporterCounter", targets: ["PSKReporterCounter"]),
        .executable(name: "PSKReporterProbe", targets: ["PSKReporterProbe"])
    ],
    dependencies: [
        .package(url: "https://github.com/emqx/CocoaMQTT.git", exact: "2.4.1")
    ],
    targets: [
        .target(name: "PSKReporterCore", dependencies: [.product(name: "CocoaMQTT", package: "CocoaMQTT")], path: "App/Core"),
        .executableTarget(name: "PSKReporterCounter", dependencies: ["PSKReporterCore"], path: "App/Counter"),
        .executableTarget(name: "PSKReporterProbe", dependencies: ["PSKReporterCore"], path: "App/Probe"),
        .testTarget(name: "PSKReporterCoreTests", dependencies: ["PSKReporterCore"])
    ]
)
