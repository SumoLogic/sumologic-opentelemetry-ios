import Foundation
import UIKit
import OpenTelemetryApi
import OpenTelemetrySdk

fileprivate func endUISpan(_ span: Span?) {
    guard span != nil else { return }
    let endTime = Date()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        span!.end(time: endTime)
    }
}

fileprivate func swizzle(cls: AnyClass, original: Selector, swizzled: Selector) -> Void {
    guard let originalMethod = class_getInstanceMethod(cls, original),
        let swizzledMethod = class_getInstanceMethod(cls, swizzled) else { return }
    method_exchangeImplementations(originalMethod, swizzledMethod)
}

fileprivate func eventTypeToString(_ eventType: UIEvent.EventType) -> String {
    switch eventType {
    case .hover:
        return "hover"
    case .touches:
        return "touches"
    case .motion:
        return "motion"
    case .remoteControl:
        return "remoteControl"
    case .presses:
        return "presses"
    case .scroll:
        return "scroll"
    case .transform:
        return "transform"
    @unknown default:
        return "unknown"
    }
}

fileprivate func eventSubtypeToString(_ eventSubtype: UIEvent.EventSubtype) -> String {
    switch eventSubtype {
    case .none:
        return "none"
    case .motionShake:
        return "motionShake"
    case .remoteControlPlay:
        return "remoteControlPlay"
    case .remoteControlPause:
        return "remoteControlPause"
    case .remoteControlStop:
        return "remoteControlStop"
    case .remoteControlTogglePlayPause:
        return "remoteControlTogglePlayPause"
    case .remoteControlNextTrack:
        return "remoteControlNextTrack"
    case .remoteControlPreviousTrack:
        return "remoteControlPreviousTrack"
    case .remoteControlBeginSeekingBackward:
        return "remoteControlBeginSeekingBackward"
    case .remoteControlEndSeekingBackward:
        return "remoteControlEndSeekingBackward"
    case .remoteControlBeginSeekingForward:
        return "remoteControlBeginSeekingForward"
    case .remoteControlEndSeekingForward:
        return "remoteControlEndSeekingForward"
    @unknown default:
        return "unknown"
    }
}

extension UIApplication {
    @objc func sumoLogicRum_sendAction(
        _ action: Selector,
        to target: Any?,
        from sender: Any?,
        for event: UIEvent?
    ) -> Bool {
        let span = tracer?.spanBuilder(spanName: "Action: \(action.description)").startSpan()
        if span != nil {
            OpenTelemetry.instance.contextProvider.setActiveSpan(span!)
        }
        let handled = self.sumoLogicRum_sendAction(action, to: target, from: sender, for: event)
        endUISpan(span)
        return handled
    }
    
    @objc func sumoLogicRum_sendEvent(_ event: UIEvent) -> Void {
        let hasEndedTouch = event.allTouches?.first(where: { $0.phase == .ended }) != nil
        let span = hasEndedTouch
            ? tracer?.spanBuilder(spanName: "Event: \(String(describing: type(of: event)))").setNoParent().startSpan()
            : nil
        if span != nil {
            OpenTelemetry.instance.contextProvider.setActiveSpan(span!)
            span?.setAttribute(key: "event.type", value: eventTypeToString(event.type))
            span?.setAttribute(key: "event.subtype", value: eventSubtypeToString(event.subtype))
        }
        self.sumoLogicRum_sendEvent(event)
        endUISpan(span)
    }
}

fileprivate var viewSpans: [UIViewController: Span] = [:]

extension UIViewController {
    @objc func sumoLogicRum_viewWillAppear(_ animated: Bool) {
        if tracer != nil {
            let title = String(describing: type(of: self))
            let span = tracer!.spanBuilder(spanName: "Navigation: \(title)").startSpan()
            OpenTelemetry.instance.contextProvider.setActiveSpan(span)
            viewSpans[self] = span
            let accessibilityLabel = self.accessibilityLabel ?? self.navigationItem.accessibilityLabel ?? self.navigationItem.title
            if accessibilityLabel != nil {
                span.setAttribute(key: "accessibilityLabel", value: accessibilityLabel!)
            }
        }
        
        self.sumoLogicRum_viewWillAppear(animated)
    }
    
    @objc func sumoLogicRum_viewDidAppear(_ animated: Bool) {
        self.sumoLogicRum_viewDidAppear(animated)
        let span = viewSpans[self]
        if span != nil {
            endUISpan(span)
            viewSpans.removeValue(forKey: self)
        }
    }
}

fileprivate var tracer: Tracer?

class UIInstrumentation {
    public init() {
        tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "ui", instrumentationVersion: "0.0.1")
        
        swizzle(cls: UIApplication.self, original: #selector(UIApplication.sendAction(_:to:from:for:)), swizzled: #selector(UIApplication.sumoLogicRum_sendAction(_:to:from:for:)))
        swizzle(cls: UIApplication.self, original: #selector(UIApplication.sendEvent(_:)), swizzled: #selector(UIApplication.sumoLogicRum_sendEvent(_:)))
        swizzle(cls: UIViewController.self, original: #selector(UIViewController.viewWillAppear(_:)), swizzled: #selector(UIViewController.sumoLogicRum_viewWillAppear(_:)))
        swizzle(cls: UIViewController.self, original: #selector(UIViewController.viewDidAppear(_:)), swizzled: #selector(UIViewController.sumoLogicRum_viewDidAppear(_:)))
    }
}
