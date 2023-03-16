import Foundation
import CrashReporter
import OpenTelemetryApi
import OpenTelemetrySdk

class CrashInstrumentation {
    init(logsExporter: SumoLogicLogsExporter) {
        if getppid() != 1 {
            print("SumoLogicRum crash instrumentation is disabled because running debugger was detected")
            return
        }
        
        let config = PLCrashReporterConfig(signalHandlerType: .mach, symbolicationStrategy: .all)
        guard let crashReporter = PLCrashReporter(configuration: config) else {
            print("Could not create an instance of PLCrashReporter")
            return
        }
        
        // Enable the Crash Reporter.
        do {
            try crashReporter.enableAndReturnError()
        } catch let error {
            print("Warning: Could not enable crash reporter: \(error)")
        }
        
        if crashReporter.hasPendingCrashReport() {
            do {
                let data = try crashReporter.loadPendingCrashReportDataAndReturnError()

                // Retrieving crash reporter data.
                let report = try PLCrashReport(data: data)
                let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "crash", instrumentationVersion: "0.0.1")
                let span = tracer.spanBuilder(spanName: "crash").setNoParent().setStartTime(time: report.systemInfo.timestamp).startSpan()
                var eventAttributes: [String: AttributeValue] = [
                    "signalName": .string(report.signalInfo.name),
                    "signalCode": .string(report.signalInfo.code),
                ]
                if report.hasProcessInfo {
                    eventAttributes.merge([
                        "processName": .string(report.processInfo.processName),
                        "processID": .int(Int(report.processInfo.processID)),
                        "processPath": .string(report.processInfo.processPath),
                    ]) { (_, new) in new }
                    if report.processInfo.processStartTime != nil {
                        eventAttributes["processStartTime"] = .string(DateFormatter().string(from: report.processInfo.processStartTime))
                    }
                    if report.processInfo.parentProcessName != nil {
                        eventAttributes["parentProcessName"] = .string(report.processInfo.parentProcessName)
                    }
                }
                if report.hasExceptionInfo {
                    eventAttributes.merge([
                        "exceptionName": .string(report.exceptionInfo.exceptionName),
                        "exceptionReason": .string(report.exceptionInfo.exceptionReason),
                    ]) { (_, new) in new }
                }
                span.addEvent(name: "crash", attributes: eventAttributes, timestamp: report.systemInfo.timestamp)
                span.end(time: report.systemInfo.timestamp.addingTimeInterval(1))
            } catch let error {
                print("CrashReporter failed to load and parse with error: \(error)")
            }
        }

        // Purge the report.
        crashReporter.purgePendingCrashReport()
    }
}
