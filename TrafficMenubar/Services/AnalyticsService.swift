import Foundation
import Sentry
import TelemetryDeck

enum AnalyticsConfig {
    // Sign up at https://dashboard.telemetrydeck.com — free tier: 100k signals/month
    static let telemetryDeckAppID = "95538E13-F9E7-44A7-B96A-7D7DB036E06F"

    // Sign up at https://sentry.io — free tier: 5k errors/month
    static let sentryDSN = "https://4f6a09578d8be85fde1c421497f573bd@o4511112331984896.ingest.us.sentry.io/4511112335917056"
}

final class AnalyticsService {
    static let shared = AnalyticsService()

    private var isEnabled = false

    private init() {}

    func configure() {
        isEnabled = true

        let config = TelemetryDeck.Config(appID: AnalyticsConfig.telemetryDeckAppID)
        TelemetryDeck.initialize(config: config)

        SentrySDK.start { options in
            options.dsn = AnalyticsConfig.sentryDSN
            options.releaseName = Bundle.main.appVersionString
            #if DEBUG
            options.environment = "debug"
            options.debug = true
            #else
            options.environment = "production"
            #endif
            options.enableCaptureFailedRequests = false
            options.enableUncaughtNSExceptionReporting = true
            options.enableSwizzling = false
            options.enableAutoSessionTracking = true
            options.attachStacktrace = true
            options.sendDefaultPii = false
            options.enableAutoPerformanceTracing = false
            options.beforeSend = { event in
                event.breadcrumbs = event.breadcrumbs?.filter { $0.category != "http" }
                return event
            }
        }

        signal("app_launched")
    }

    func signal(_ name: String, parameters: [String: String] = [:]) {
        guard isEnabled else { return }
        TelemetryDeck.signal(name, parameters: parameters)
    }

    func trackRouteFetch(provider: String, success: Bool, routeCount: Int = 0) {
        signal("route_fetch", parameters: [
            "provider": provider,
            "success": String(success),
            "route_count": String(routeCount)
        ])
    }

    func trackProviderChange(_ provider: String) {
        signal("provider_changed", parameters: ["provider": provider])
    }

    func trackFeatureUsed(_ feature: String) {
        signal("feature_used", parameters: ["feature": feature])
    }
}

extension Bundle {
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "com.trafficmenubar.app@\(version)+\(build)"
    }
}
