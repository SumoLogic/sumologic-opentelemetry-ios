import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

class SumoLogicSpanProcessor: SpanProcessor {
    public var isStartRequired = true
    public var isEndRequired = true
    private var batchSpanProcessor: BatchSpanProcessor
    
    // We track number of spans per trace id only for root spans comming from "ui" instrumentation.
    // Because it's our own instrumentation, we make sure that these spans ends, so we don't have to use here weak references.
    private var tracesSpansAmount: [TraceId: UInt] = [:]
    
    public init(spanExporter: SpanExporter) {
        batchSpanProcessor = BatchSpanProcessor(spanExporter: spanExporter)
    }
    
    public func onStart(parentContext: SpanContext?, span: ReadableSpan) {
        let traceId = span.context.traceId
        let numberOfSpans = tracesSpansAmount[traceId]
        if numberOfSpans != nil || span.instrumentationLibraryInfo.name == "ui" {
            tracesSpansAmount[traceId] = (numberOfSpans ?? 0) + 1
        }
        
        batchSpanProcessor.onStart(parentContext: parentContext, span: span)
    }

    public func onEnd(span: ReadableSpan) {
        let traceId = span.context.traceId
        let numberOfSpans = tracesSpansAmount[traceId]
        if numberOfSpans != nil {
            tracesSpansAmount.removeValue(forKey: traceId)
        }
        if numberOfSpans == nil || numberOfSpans! > 1 {
            batchSpanProcessor.onEnd(span: span)
        } else {
            // forget
        }
    }
    
    public func shutdown() {
        batchSpanProcessor.shutdown()
    }
    
    public func forceFlush(timeout: TimeInterval?) {
        batchSpanProcessor.forceFlush(timeout: timeout)
    }
}
