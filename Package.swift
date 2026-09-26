// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ATaleOfTodos",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Tale", targets: ["TaleApp"])],
    targets: [
        .target(name: "TaleCore", linkerSettings: [.linkedLibrary("sqlite3")]),
        .executableTarget(name: "TaleApp", dependencies: ["TaleCore"]),
        .testTarget(name: "TaleCoreTests", dependencies: ["TaleCore"])
    ]
)
