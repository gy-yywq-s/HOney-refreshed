//
//  AppConfig.swift
//  HOney — runtime configuration (base URLs, feature flags).
//

import Foundation

struct AppConfig: Sendable {
    var honeyBaseURL: URL
    var portalBaseURL: URL
    /// Web base for the persistent School Portal WKWebView.
    var portalWebURL: URL

    static let `default` = AppConfig(
        honeyBaseURL: URL(string: "https://honey.gaelisus.com")!,
        portalBaseURL: URL(string: "https://www.huayaopudong.com")!,
        portalWebURL: URL(string: "https://www.huayaopudong.com/student")!
    )
}
