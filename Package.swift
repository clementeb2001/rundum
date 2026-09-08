// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "RundumCore", platforms: [.iOS(.v16), .macOS(.v13)], products: [.library(name: "RundumCore", targets: ["RundumCore"])], targets: [.target(name: "RundumCore", path: "Core"), .testTarget(name: "RundumCoreTests", dependencies: ["RundumCore"], path: "Tests")])
