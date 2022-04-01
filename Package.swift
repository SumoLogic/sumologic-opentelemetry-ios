// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "SumoLogicRum",
    platforms: [.iOS(.v11)],
    products: [
        .library(name: "SumoLogicRum", type: .static, targets: ["SumoLogicRum"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kkruk-sumo/opentelemetry-swift", revision: "6a0ceb776efbe8de0eedde9f0399009190756b49"),
        .package(url: "https://github.com/microsoft/plcrashreporter", from: "1.10.1"),
    ],
    targets: [
        .target(
            name: "SumoLogicRum",
            dependencies: [
                            .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                            .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                            .product(name: "ResourceExtension", package: "opentelemetry-swift"),
                            .product(name: "URLSessionInstrumentation", package: "opentelemetry-swift"),
                            .product(name: "NetworkStatus", package: "opentelemetry-swift"),
                            .product(name: "CrashReporter", package: "plcrashreporter")]
        ),
    ]
)
