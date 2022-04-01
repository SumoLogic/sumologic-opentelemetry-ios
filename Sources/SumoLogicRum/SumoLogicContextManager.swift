import Foundation
import UIKit
import OpenTelemetryApi
import OpenTelemetrySdk

class SumoLogicContextManager: ContextManager {
    private var context: [OpenTelemetryContextKeys: NSMutableArray] = [:]

    func getCurrentContextValue(forKey: OpenTelemetryContextKeys) -> AnyObject? {
        return context[forKey]?.lastObject as AnyObject?
    }

    func setCurrentContextValue(forKey: OpenTelemetryContextKeys, value: AnyObject) {
        if context[forKey] == nil {
            context[forKey] = NSMutableArray()
        }
        context[forKey]?.add(value)
    }

    func removeContextValue(forKey: OpenTelemetryContextKeys, value: AnyObject) {
        context[forKey]?.remove(value)
    }
}
