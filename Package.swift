// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AITrafficLight",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "TrafficLightCore", targets: ["TrafficLightCore"]),
        .executable(name: "ai-traffic-light", targets: ["TrafficLightApp"]),
        .executable(name: "status-dump", targets: ["TrafficLightStatusDump"]),
        .executable(name: "core-self-test", targets: ["TrafficLightCoreSelfTest"])
    ],
    targets: [
        .target(name: "TrafficLightCore"),
        .executableTarget(
            name: "TrafficLightApp",
            dependencies: ["TrafficLightCore"]
        ),
        .executableTarget(
            name: "TrafficLightStatusDump",
            dependencies: ["TrafficLightCore"]
        ),
        .executableTarget(
            name: "TrafficLightCoreSelfTest",
            dependencies: ["TrafficLightCore"],
            path: "Tests/TrafficLightCoreSelfTest"
        )
    ]
)
