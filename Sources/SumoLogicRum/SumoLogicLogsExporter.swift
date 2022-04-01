import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

struct SumoLogicLogsExporterOptions {
    let resource: Resource
    let endpoint: String
    let maxQueueSize: Int
    let scheduledDelay: Double
}

struct LogRecord {
    enum LogType: String {
        case uncaughtException, unhandledRejection, consoleError, documentError, customError
    }
    
    struct LogError: Codable {
        let name: String
        let message: String
        let stack: String?
    }
    
    let type: LogType
    let message: String
//    let arguments: [Any?]?
    let error: LogError?
}

fileprivate struct ProtoLogRecord: Codable {
    enum SeverityNumber: Int, Codable {
      case SEVERITY_NUMBER_UNSPECIFIED = 0,
      SEVERITY_NUMBER_TRACE,
      SEVERITY_NUMBER_TRACE2,
      SEVERITY_NUMBER_TRACE3,
      SEVERITY_NUMBER_TRACE4,
      SEVERITY_NUMBER_DEBUG,
      SEVERITY_NUMBER_DEBUG2,
      SEVERITY_NUMBER_DEBUG3,
      SEVERITY_NUMBER_DEBUG4,
      SEVERITY_NUMBER_INFO,
      SEVERITY_NUMBER_INFO2,
      SEVERITY_NUMBER_INFO3,
      SEVERITY_NUMBER_INFO4,
      SEVERITY_NUMBER_WARN,
      SEVERITY_NUMBER_WARN2,
      SEVERITY_NUMBER_WARN3,
      SEVERITY_NUMBER_WARN4,
      SEVERITY_NUMBER_ERROR,
      SEVERITY_NUMBER_ERROR2,
      SEVERITY_NUMBER_ERROR3,
      SEVERITY_NUMBER_ERROR4,
      SEVERITY_NUMBER_FATAL,
      SEVERITY_NUMBER_FATAL2,
      SEVERITY_NUMBER_FATAL3,
      SEVERITY_NUMBER_FATAL4
    }
    
    let timeUnixNano: UInt64
    let severityNumber: SeverityNumber?
//    let severityText: String?
//    let name: String?
    let body: Otlp.AnyValue?
    let attributes: [Otlp.KeyValue]
    let droppedAttributesCount: Int
}

fileprivate struct OtlpLogs {
    struct ExportLogsServiceRequest: Codable {
        var resourceLogs: [ResourceLog]
    }
    
    struct ResourceLog: Codable {
        var resource: Otlp.Resource?
        var instrumentationLibraryLogs: [InstrumentationLibraryLog]
    }
    
    struct InstrumentationLibraryLog: Codable {
        var instrumentationLibrary: Otlp.InstrumentationLibrary
        var logs: [ProtoLogRecord]
    }
}

class SumoLogicLogsExporter {
    private let options: SumoLogicLogsExporterOptions
    private var logs: [ProtoLogRecord] = []
    private var timer: Timer?
    private let cond = NSCondition()
    
    init(options: SumoLogicLogsExporterOptions) {
        self.options = options
    }
    
    private func exportWhenNeeded() {
        if logs.count >= options.maxQueueSize {
            export()
        } else if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: options.scheduledDelay, repeats: false) { _ in self.export() }
        }
    }
    
    public func recordLog(_ log: LogRecord) {
        cond.lock()
        defer { cond.unlock() }
        
        var attributes: [Otlp.KeyValue] = [
            Otlp.KeyValue(key: "type", value: Otlp.AnyValue(stringValue: log.type.rawValue))
        ]
        
        if log.error != nil {
            attributes.append(Otlp.KeyValue(key: "error.name", value: Otlp.AnyValue(stringValue: log.error!.name)))
            attributes.append(Otlp.KeyValue(key: "error.message", value: Otlp.AnyValue(stringValue: log.error!.message)))
            if log.error?.stack != nil {
                attributes.append(Otlp.KeyValue(key: "error.stack", value: Otlp.AnyValue(stringValue: log.error!.stack)))
            }
        }
        
        let protoLog = ProtoLogRecord(
            timeUnixNano: Date().timeIntervalSince1970.toNanoseconds,
            severityNumber: ProtoLogRecord.SeverityNumber.SEVERITY_NUMBER_ERROR,
            body: Otlp.AnyValue(stringValue: log.message),
            attributes: attributes,
            droppedAttributesCount: 0
        )
        
        logs.append(protoLog)
        
        exportWhenNeeded()
    }
    
    public func recordCustomError(message: String) {
        cond.lock()
        defer { cond.unlock() }
        
        var attributes: [Otlp.KeyValue] = [
            Otlp.KeyValue(key: "type", value: Otlp.AnyValue(stringValue: LogRecord.LogType.customError.rawValue))
        ]
        
        let protoLog = ProtoLogRecord(
            timeUnixNano: Date().timeIntervalSince1970.toNanoseconds,
            severityNumber: ProtoLogRecord.SeverityNumber.SEVERITY_NUMBER_ERROR,
            body: Otlp.AnyValue(stringValue: message),
            attributes: attributes,
            droppedAttributesCount: 0
        )
        
        logs.append(protoLog)
        
        exportWhenNeeded()
    }
    
    private func export() {
        guard let url = URL(string: options.endpoint) else { return }
        
        cond.lock()
        defer { cond.unlock() }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let logsToExport = logs
        logs = []

        let payload = OtlpLogs.ExportLogsServiceRequest(
            resourceLogs: [OtlpLogs.ResourceLog(
                resource: Otlp.Resource(
                    attributes: SpanAdapter.toSpanAttributes(options.resource.attributes),
                    droppedAttributesCount: 0
                ),
                instrumentationLibraryLogs: [
                    OtlpLogs.InstrumentationLibraryLog(
                        instrumentationLibrary: Otlp.InstrumentationLibrary(name: "sumologic-rum-ios", version: "0.0.0"),
                        logs: logsToExport
                    )
                ]
            )]
        )

        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            print("cannot stringify logs error=\(error)")
            return
        }

        URLSession.shared.dataTask(with: request) { data, res, error in
            print("export logs error=\(error) res=\(res) data=\(data)")
        }.resume()
    }
}
