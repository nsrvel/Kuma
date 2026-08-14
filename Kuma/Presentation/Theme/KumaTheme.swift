//
//  KumaTheme.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  Design system tokens: Spacing, Radius, Typography, and Semantic Colors.
//

import SwiftUI

// MARK: - Spacing Scale (Zero Magic Numbers)

public enum KumaSpacing {
    /// 4pt — Micro spacing (icon gaps, tight badges)
    public static let xs: CGFloat = 4
    /// 8pt — Small spacing (card internal padding, chip padding)
    public static let sm: CGFloat = 8
    /// 12pt — Medium spacing (form field gap, list item gap)
    public static let md: CGFloat = 12
    /// 16pt — Large spacing (container padding, standard section margins)
    public static let lg: CGFloat = 16
    /// 24pt — Extra large spacing (wizard section gaps)
    public static let xl: CGFloat = 24
    /// 32pt — Hero / Onboarding header spacing
    public static let xxl: CGFloat = 32
}

// MARK: - Corner Radius Scale

public enum KumaRadius {
    /// 6pt — Small elements (tags, badges, inner buttons)
    public static let sm: CGFloat = 6
    /// 10pt — Standard controls (text fields, cards, list rows)
    public static let md: CGFloat = 10
    /// 14pt — Large containers (dialogs, inspector panels, popovers)
    public static let lg: CGFloat = 14
    /// 20pt — Hero elements / Avatars
    public static let xl: CGFloat = 20
}

// MARK: - Typography Scale (macOS SF Pro Native)

public enum KumaFont {
    /// 20pt Bold — Onboarding titles, Hero headers
    public static let hero = Font.system(size: 20, weight: .bold, design: .default)
    /// 16pt Bold — Section titles, Window header
    public static let title = Font.system(size: 16, weight: .bold, design: .default)
    /// 13pt Semibold — Card titles, primary actions
    public static let heading = Font.system(size: 13, weight: .semibold, design: .default)
    /// 13pt Regular — Standard body text, descriptions
    public static let body = Font.system(size: 13, weight: .regular, design: .default)
    /// 11pt Medium — Subtitles, metadata, status labels
    public static let subheadline = Font.system(size: 11, weight: .medium, design: .default)
    /// 10pt Regular — Footnotes, timestamp, secondary hints
    public static let caption = Font.system(size: 10, weight: .regular, design: .default)
    /// 12pt Monospaced — Ports, URLs, CLI commands, logs
    public static let code = Font.system(size: 12, weight: .regular, design: .monospaced)
}

// MARK: - Semantic Colors & Tints

public enum KumaColors {
    // Service Execution States
    public static let statusRunning = Color.green
    public static let statusStarting = Color.orange
    public static let statusStopped = Color.secondary
    public static let statusFailed = Color.red
    public static let statusDisabled = Color.secondary.opacity(0.4)

    // Provider / Engine Tints (8 Providers)
    public static let providerKube = Color.blue
    public static let providerDocker = Color.cyan
    public static let providerPodman = Color.purple
    public static let providerShell = Color.green
    public static let providerSSH = Color.gray
    public static let providerHttp = Color.mint
    public static let providerTunnel = Color.orange
    public static let providerProcess = Color.red
}
