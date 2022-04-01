import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

fileprivate let TELEMETRY_SDK_EXPORT_TIMESTAMP = "sumologic.telemetry.sdk.export_timestamp"

struct SumoLogicOtlpExporterOptions {
    let endpoint: String

    public init(endpoint: String) {
        self.endpoint = endpoint
    }
}

class SumoLogicOtlpTraceExporter: SpanExporter {
    private var options: SumoLogicOtlpExporterOptions
    private var isRunning: Bool = true
    
    public init(options: SumoLogicOtlpExporterOptions) {
        self.options = options
    }
    
    public func export(spans: [SpanData]) -> SpanExporterResultCode {
        guard isRunning else { return .failure }
        guard let url = URL(string: options.endpoint) else { return .failure }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var payload = Otlp.ExportTraceServiceRequest(
            resourceSpans: SpanAdapter.toResourceSpans(spanDataList: spans)
        )
        
        let exportTimestamp = Int(Date().timeIntervalSince1970.toMilliseconds)
        for index in payload.resourceSpans.indices {
            payload.resourceSpans[index].resource?.attributes.append(Otlp.KeyValue(key: TELEMETRY_SDK_EXPORT_TIMESTAMP, value: Otlp.AnyValue(intValue: exportTimestamp)))
        }
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            return .failure
        }

        var status: SpanExporterResultCode = .failure

        let sem = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: request) { _, _, error in
            if error != nil {
                status = .failure
            } else {
                status = .success
            }
            sem.signal()
        }
        task.resume()
        sem.wait()

        return status
    }
    
    public func flush() -> SpanExporterResultCode {
        guard isRunning else { return .failure }
        return .success
    }
    
    public func reset() {
    }
    
    public func shutdown() {
        isRunning = false
    }
}
