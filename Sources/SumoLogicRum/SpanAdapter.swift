import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

struct SpanAdapter {
    static func toResourceSpans(spanDataList: [SpanData]) -> [Otlp.ResourceSpan] {
        let resourceAndLibraryMap = groupByResourceAndLibrary(spanDataList: spanDataList)
        var resourceSpans = [Otlp.ResourceSpan]()
        
        resourceAndLibraryMap.forEach { resMap in
            var instrumentationLibrarySpans = [Otlp.InstrumentationLibrarySpan]()
            resMap.value.forEach { instLibrary in
                let inst = Otlp.InstrumentationLibrarySpan(
                    instrumentationLibrary: Otlp.InstrumentationLibrary(
                        name: instLibrary.key.name,
                        version: instLibrary.key.version
                    ),
                    spans: instLibrary.value
                )
                instrumentationLibrarySpans.append(inst)
            }
            
            let resourceSpan = Otlp.ResourceSpan(
                resource: Otlp.Resource(
                    attributes: toSpanAttributes(resMap.key.attributes),
                    droppedAttributesCount: 0
                ),
                instrumentationLibrarySpans: instrumentationLibrarySpans
            )
            resourceSpans.append(resourceSpan)
        }
        
        return resourceSpans
    }
    
    private static func groupByResourceAndLibrary(spanDataList: [SpanData]) -> [Resource: [InstrumentationScopeInfo: [Otlp.Span]]] {
        var result = [Resource: [InstrumentationScopeInfo: [Otlp.Span]]]()
        spanDataList.forEach {
            result[$0.resource, default: [InstrumentationScopeInfo: [Otlp.Span]]()][$0.instrumentationScope, default: [Otlp.Span]()]
                .append(toOtlpSpan(spanData: $0))
        }
        return result
    }
    
    static func toOtlpSpan(spanData: SpanData) -> Otlp.Span {
        return Otlp.Span(
            traceId: spanData.traceId.hexString,
            spanId: spanData.spanId.hexString,
//            traceState: spanData.traceState,
            parentSpanId: spanData.parentSpanId?.hexString,
            name: spanData.name,
            kind: toSpanKind(spanData.kind),
            startTimeUnixNano: spanData.startTime.timeIntervalSince1970.toNanoseconds,
            endTimeUnixNano: spanData.endTime.timeIntervalSince1970.toNanoseconds,
            attributes: toSpanAttributes(spanData.attributes),
            droppedAttributesCount: spanData.totalAttributeCount - spanData.attributes.count,
            events: toSpanEvents(spanData.events),
            droppedEventsCount: spanData.totalRecordedEvents - spanData.events.count,
            links: toSpanLinks(spanData.links),
            droppedLinksCount: spanData.totalRecordedLinks - spanData.links.count,
            status: Otlp.SpanStatus(code: spanData.status.code)
        )
    }
    
    static func toSpanAttributes(_ attrs: [String: AttributeValue]) -> [Otlp.KeyValue] {
        var result: [Otlp.KeyValue] = []
        attrs.forEach({ key, value in
            result.append(Otlp.KeyValue(key: key, value: toSpanAttributeValue(value)))
        })
        return result
    }
    
    static func toSpanAttributeValue(_ value: AttributeValue) -> Otlp.AnyValue {
        switch value {
        case let .string(value):
            return Otlp.AnyValue(stringValue: value)
        case let .bool(value):
            return Otlp.AnyValue(boolValue: value)
        case let .int(value):
            return Otlp.AnyValue(intValue: value)
        case let .double(value):
            return Otlp.AnyValue(doubleValue: value)
        case let .stringArray(value):
            return Otlp.AnyValue(arrayValue: value.map({ Otlp.AnyValue(stringValue: $0) }))
        case let .boolArray(value):
            return Otlp.AnyValue(arrayValue: value.map({ Otlp.AnyValue(boolValue: $0) }))
        case let .intArray(value):
            return Otlp.AnyValue(arrayValue: value.map({ Otlp.AnyValue(intValue: $0) }))
        case let .doubleArray(value):
            return Otlp.AnyValue(arrayValue: value.map({ Otlp.AnyValue(doubleValue: $0) }))
        }
    }
    
    static func toSpanKind(_ kind: SpanKind) -> Int {
        switch kind {
        case .internal:
            return 1
        case .server:
            return 2
        case .client:
            return 3
        case .producer:
            return 4
        case .consumer:
            return 5
        }
    }
    
    static func toSpanEvents(_ events: [SpanData.Event]) -> [Otlp.Span.Event] {
        return events.map({ Otlp.Span.Event(
            timeUnixNano: $0.timestamp.timeIntervalSince1970.toNanoseconds,
            name: $0.name,
            attributes: toSpanAttributes($0.attributes),
            droppedAttributesCount: 0
        ) })
    }
    
    static func toSpanLinks(_ links: [SpanData.Link]) -> [Otlp.Span.Link] {
        return links.map({ Otlp.Span.Link(
            traceId: $0.context.traceId.hexString,
            spanId: $0.context.spanId.hexString,
//            traceState: $0.context.traceState,
            attributes: toSpanAttributes($0.attributes),
            droppedAttributesCount: 0
        ) })
    }
}
