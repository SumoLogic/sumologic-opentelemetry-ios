import Foundation
import UIKit
@_exported import OpenTelemetryApi
@_exported import OpenTelemetrySdk
import ResourceExtension
import URLSessionInstrumentation

fileprivate var logsExporter: SumoLogicLogsExporter? = nil

public struct SumoLogicRum {
    public static func initialize(
        collectionSourceUrl: String,
        serviceName: String? = nil,
        applicationName: String? = nil,
        enableAppLoadInstrumentation: Bool = true,
        enableUIInstrumentation: Bool = true,
        enableURLSessionInstrumentation: Bool = true,
        enableCrashInstrumentation: Bool = true
    ) {
        OpenTelemetry.registerContextManager(contextManager: SumoLogicContextManager())
        
        var resource = DefaultResources().get()
        var attributes = [String: AttributeValue]()
        if serviceName != nil {
            attributes[ResourceAttributes.serviceName.rawValue] = AttributeValue.string(serviceName!)
        }
        if applicationName != nil {
            attributes["application"] = AttributeValue.string(applicationName!)
        }
        resource.merge(other: Resource(attributes: attributes))

        let otlpTraceExporter = SumoLogicOtlpTraceExporter(options: SumoLogicOtlpExporterOptions(endpoint: collectionSourceUrl))
        let spanProcessor = SumoLogicSpanProcessor(spanExporter: otlpTraceExporter)

        OpenTelemetry.registerTracerProvider(tracerProvider:
            TracerProviderBuilder()
                .add(spanProcessor: spanProcessor)
                .with(resource: resource)
                .build()
        )
        
        logsExporter = SumoLogicLogsExporter(options: SumoLogicLogsExporterOptions(resource: resource, endpoint: "\(collectionSourceUrl)/v1/logs", maxQueueSize: 50, scheduledDelay: 2.0))
        
        if enableURLSessionInstrumentation {
            URLSessionInstrumentation(configuration: URLSessionInstrumentationConfiguration(
                shouldInstrument: {
                    return $0.url?.absoluteString.starts(with: collectionSourceUrl) == false
                }
            ))
        }
        
        if enableAppLoadInstrumentation {
            AppLoadInstrumentation()
        }
        
        if enableUIInstrumentation {
            UIInstrumentation()
        }
        
        if enableCrashInstrumentation {
            CrashInstrumentation(logsExporter: logsExporter!)
        }
    }
    
    public static func recordError(message: String) {
        logsExporter?.recordCustomError(message: message)
    }
}
