import SwiftUI

/// The app's Settings window (⌘,).
struct SettingsView: View {
    @Environment(UsageService.self) private var usage
    @AppStorage(UsageService.keepLoginFreshKey) private var keepLoginFresh = false

    var body: some View {
        Form {
            Section {
                Toggle("Keep Claude Code login fresh", isOn: $keepLoginFresh)
                    .onChange(of: keepLoginFresh) { _, enabled in
                        if enabled { usage.refresh() }
                    }
            } footer: {
                Text("""
                    Claude Code's login expires after about 8 hours without use, and the meter goes stale. \
                    With this on, TokenMeter runs a tiny `claude -p` prompt (Haiku, no tools) shortly \
                    before expiry so Claude Code renews its own token. Each run uses a small amount of your \
                    usage and needs `claude` installed. Off by default.
                    """)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize()
    }
}
