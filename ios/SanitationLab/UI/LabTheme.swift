//
//  LabTheme.swift
//  SanitationLab — the few tokens the lab needs. Self-contained on purpose:
//  the lab must not depend on the app's design system while Gary is editing it.
//

import SwiftUI

enum LabTheme {
    static let ink = Color(red: 0.11, green: 0.12, blue: 0.14)
    static let muted = Color(red: 0.45, green: 0.47, blue: 0.50)
    static let line = Color(red: 0.86, green: 0.87, blue: 0.89)
    static let surface = Color(red: 0.97, green: 0.97, blue: 0.975)
    static let ok = Color(red: 0.17, green: 0.56, blue: 0.30)
    static let warn = Color(red: 0.86, green: 0.42, blue: 0.14)
    static let bad = Color(red: 0.86, green: 0.18, blue: 0.22)
    static let radius: CGFloat = 12
}

struct LabButtonStyle: ButtonStyle {
    var filled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .foregroundStyle(filled ? Color.white : LabTheme.ink)
            .background(filled ? LabTheme.ink : Color.white, in: Capsule())
            .overlay(Capsule().stroke(filled ? Color.clear : LabTheme.line, lineWidth: 1))
            .shadow(color: filled ? .clear : .black.opacity(0.06), radius: 6, y: 2)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
