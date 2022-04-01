# Sumo Logic OpenTelemetry RUM for iOS

## Features

- `URLSession` auto-instrumentation
- Information about app start
- Touches, actions and view controllers
- Support for manual instrumentation

## Instalation

Use Swift Package Manager through XCode (Project -> Package Dependencies) or by modifying `Package.swift` file:

```swift
.package(url: "https://github.com/SumoLogic/sumologic-opentelemetry-ios", from: "1.0.0")
```

Then initialize this library by calling `SumoLogicRum.initialize`, ideally in `App.init` or `AppDelegate.didFinishLaunchingWithOptions`.

```swift
import SumoLogicRum

SumoLogicRum.initialize(
    collectionSourceUrl: "...",
)
```

## Configuration

| Parameter                       | Type     | Default    | Description                     |
| ------------------------------- | -------- | ---------- | ------------------------------- |
| collectionSourceUrl             | `String` | _required_ | Sumo Logic collector source url |
| serviceName                     | `String` | auto       | Name of your service            |
| applicationName                 | `String` | auto       | Name of your application        |
| enableAppLoadInstrumentation    | `Bool`   | true       |                                 |
| enableUIInstrumentation         | `Bool`   | true       |                                 |
| enableURLSessionInstrumentation | `Bool`   | true       |                                 |
| enableCrashInstrumentation      | `Bool`   | true       |                                 |

## Manual instrumentation

Use standard OpenTelemetry-Swift API to create spans manually:

```swift
import OpenTelemetryApi
import OpenTelemetrySdk

let tracer = OpenTelemetrySDK.instance.tracerProvider.get(instrumentationName: "app", instrumentationVersion: "0.0.1")

let span = tracer.spanBuilder(spanName: "your operation name").startSpan()
OpenTelemetry.instance.contextProvider.setActiveSpan(span)

span.end()
```

## License

This project is released under the [Apache 2.0 License](./LICENSE).

## Code Of Conduct

Please refer to our [Code of Conduct](./CODE_OF_CONDUCT.md).
