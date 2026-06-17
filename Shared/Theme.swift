import SwiftUI

// "Retro apothecary" design language for rx'd — parchment, bottle-green, oxblood,
// serif type, ruled labels and rubber-stamp statuses.
//
// Reusable components live in their own files (LabelCard, RuledHeader, StatusStamp,
// AppleHealthBadge, RxMonogram); color helpers in Color+Adaptive.swift.
enum Theme {
    static let background = Color(light: 0xEDE3CC, dark: 0x1B1712) // parchment
    static let surface = Color(light: 0xFBF6E9, dark: 0x2A2419) // label paper
    static let surfaceAlt = Color(light: 0xE4D8BD, dark: 0x342C1E)
    static let accent = Color(light: 0x2E6B5E, dark: 0x57A492) // bottle green
    static let oxblood = Color(light: 0xA6392E, dark: 0xCC5A4D) // ℞ red
    static let gold = Color(light: 0xAE7C2B, dark: 0xCBA15A)
    static let ink = Color(light: 0x2B231B, dark: 0xF1E7D2)
    static let inkFaded = Color(light: 0x8A7B63, dark: 0xA89876)

    // Status palette
    static let taken = Color(light: 0x2E6B5E, dark: 0x57A492) // green
    static let pending = Color(light: 0x8A7B63, dark: 0xA89876) // sepia
    static let snoozed = Color(light: 0xAE7C2B, dark: 0xCBA15A) // gold
    static let missed = Color(light: 0xA6392E, dark: 0xCC5A4D) // oxblood

    static let cardCornerRadius: CGFloat = 12
    static let cardShadow = Color.black.opacity(0.10)

    static let rx = "\u{211E}" // ℞
}
