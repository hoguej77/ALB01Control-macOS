// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ALB01Control",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ALB01Protocol", targets: ["ALB01Protocol"]),
        .library(name: "ALB01HID", targets: ["ALB01HID"]),
        .executable(name: "ALB01Control", targets: ["ALB01ControlApp"]),
        .executable(name: "alb01-diagnostics", targets: ["alb01-diagnostics"]),
    ],
    targets: [
        .target(name: "ALB01Protocol"),
        .target(name: "ALB01HID", dependencies: ["ALB01Protocol"], linkerSettings: [.linkedFramework("IOKit")]),

        .executableTarget(name: "ALB01ControlApp", dependencies: ["ALB01Protocol", "ALB01HID"], linkerSettings: [.linkedFramework("ServiceManagement")]),
        .executableTarget(name: "alb01-diagnostics", dependencies: ["ALB01Protocol", "ALB01HID"]),
        .testTarget(name: "ALB01ProtocolTests", dependencies: ["ALB01Protocol"]),
        .testTarget(name: "ALB01ControlTests", dependencies: ["ALB01ControlApp", "ALB01Protocol"]),
    ]
)
