import Foundation

struct Otlp: Codable {
    struct ExportTraceServiceRequest: Codable {
        var resourceSpans: [ResourceSpan]
    }
    
    struct KeyValue: Codable {
        var key: String
        var value: AnyValue
    }
    
    struct ArrayValue: Codable {
        var values: [AnyValue]
    }
    
    struct KeyValueList: Codable {
        var values: [KeyValue]
    }
    
    struct AnyValue: Codable {
        var stringValue: String?
        var boolValue: Bool?
        var intValue: Int?
        var doubleValue: Double?
        var arrayValue: [AnyValue]?
        var kvlistValue: [KeyValue]?
    }
    
    struct InstrumentationLibrary: Codable {
        var name: String
        var version: String?
    }
    
    struct ResourceSpan: Codable {
        var resource: Resource?
        var instrumentationLibrarySpans: [InstrumentationLibrarySpan]
    }
    
    struct Resource: Codable {
        var attributes: [KeyValue]
        var droppedAttributesCount: Int
    }
    
    struct InstrumentationLibrarySpan: Codable {
        var instrumentationLibrary: InstrumentationLibrary
        var spans: [Span]
    }
    
    struct SpanStatus: Codable {
        var code: Int
        var message: String?
    }
    
    struct Span: Codable {
        var traceId: String
        var spanId: String
        var traceState: String?
        var parentSpanId: String?
        var name: String?
        var kind: Int?
        var startTimeUnixNano: UInt64?
        var endTimeUnixNano: UInt64?
        var attributes: [KeyValue]?
        var droppedAttributesCount: Int
        var events: [Span.Event]?
        var droppedEventsCount: Int
        var links: [Span.Link]?
        var droppedLinksCount: Int
        var status: SpanStatus
        
        struct Event: Codable {
            var timeUnixNano: UInt64
            var name: String
            var attributes: [KeyValue]?
            var droppedAttributesCount: Int
        }
        
        struct Link: Codable {
            var traceId: String
            var spanId: String
            var traceState: String?
            var attributes: [KeyValue]?
            var droppedAttributesCount: Int
        }
    }
}
