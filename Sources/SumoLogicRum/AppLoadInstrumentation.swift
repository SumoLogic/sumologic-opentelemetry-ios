import Foundation
import UIKit
import OpenTelemetryApi
import OpenTelemetrySdk

fileprivate let fileStartTime = Date()

fileprivate enum Error: Swift.Error {
    case unknown
}

fileprivate let appLoadEvents = [
    UIApplication.didFinishLaunchingNotification,
    UIApplication.willEnterForegroundNotification,
    UIApplication.didBecomeActiveNotification
]

fileprivate let finalAppLoadEvent = UIApplication.didBecomeActiveNotification

fileprivate func processStartTime() throws -> Date {
    let name = "kern.proc.pid"
    var keysBufferSize = Int(4)
    var keysBuffer = Array<Int32>(repeating: 0, count: keysBufferSize)
    var kp: kinfo_proc = kinfo_proc()
    
    try keysBuffer.withUnsafeMutableBufferPointer { (lbp: inout UnsafeMutableBufferPointer<Int32>) throws in
        try name.withCString { (nbp: UnsafePointer<Int8>) throws in
            guard sysctlnametomib(nbp, lbp.baseAddress, &keysBufferSize) == 0 else {
                throw Error.unknown
            }
        }
        lbp[3] = getpid()
        keysBufferSize = MemoryLayout<kinfo_proc>.size
        guard sysctl(lbp.baseAddress, 4, &kp, &keysBufferSize, nil, 0) == 0 else {
            throw Error.unknown
        }
    }
    
    let startTime = kp.kp_proc.p_un.__p_starttime
    let timeInterval: Double = Double(startTime.tv_sec) + (Double(startTime.tv_usec) / 1e6)
    return Date(timeIntervalSince1970: timeInterval)
}

class AppLoadInstrumentation {
    private let tracer: Tracer
    
    public init() {
        tracer = OpenTelemetrySDK.instance.tracerProvider.get(instrumentationName: "app-load", instrumentationVersion: "0.0.1")
        
        let startTime = (try? processStartTime()) ?? fileStartTime
        let span = tracer.spanBuilder(spanName: "appLoad").setStartTime(time: startTime).startSpan()
        OpenTelemetry.instance.contextProvider.setActiveSpan(span)
        
        appLoadEvents.forEach { event in
            NotificationCenter.default.addObserver(forName: event, object: nil, queue: nil) { _ in
                span.addEvent(name: event.rawValue)
                if event == finalAppLoadEvent {
                    span.end()
                }
            }
        }
    }
}
