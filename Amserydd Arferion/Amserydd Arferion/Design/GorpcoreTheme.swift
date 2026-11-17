import SwiftUI

enum GorpcoreTheme {
    static let desertSand = Color(hex: 0xD8C090)
    static let sandstone = Color(hex: 0xC8B888)
    static let trailTan = Color(hex: 0xC8A868)
    static let pebble = Color(hex: 0xB0A898)
    static let rust = Color(hex: 0xA03818)
    static let amberTrail = Color(hex: 0xC88038)
    static let mossyOak = Color(hex: 0x506040)
    static let canopy = Color(hex: 0x405830)
    static let charcoal = Color(hex: 0x403C38)
    static let carbon = Color(hex: 0x303028)

    static let background = desertSand.opacity(0.30)
    static let surface = Color.white.opacity(0.74)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

struct GorpcoreCard: ViewModifier {
    var background: Color = GorpcoreTheme.surface

    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(GorpcoreTheme.carbon.opacity(0.10), lineWidth: 1)
            }
    }
}

extension View {
    func gorpcoreCard(background: Color = GorpcoreTheme.surface) -> some View {
        modifier(GorpcoreCard(background: background))
    }
}

struct GorpcoreSectionHeader: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.semibold).monospaced())
                .tracking(2)
                .foregroundStyle(GorpcoreTheme.rust)
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(GorpcoreTheme.carbon)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum TimeText {
    static func balance(_ seconds: TimeInterval) -> String {
        let value = abs(Int(seconds.rounded()))
        let hours = value / 3_600
        let minutes = (value % 3_600) / 60
        let remainingSeconds = value % 60

        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds) }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    static func compact(_ seconds: TimeInterval) -> String {
        let minutes = Int(abs(seconds).rounded()) / 60
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        if minutes > 0 { return "\(minutes)m" }
        return "<1m"
    }
}
