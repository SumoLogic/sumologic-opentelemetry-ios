// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "SumoLogicRum",
    platforms: [.iOS(.v11)],
    products: [
        .library(name: "SumoLogicRum", type: .static, targets: ["SumoLogicRum"]),
    ],
    dependencies: [
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift", exact: "1.2.0"),
        .package(url: "https://github.com/microsoft/plcrashreporter", exact: "1.10.1"),
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
