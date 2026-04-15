import SwiftUI

/// Expanded popover content shown when the user clicks the notch strip.
/// Block 1: a minimal pixel room with the pet in the center + a collapse
/// button. Status bars and action buttons arrive in Block 2.
struct RoomView: View {
    let onCollapse: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoomBackground()
            VStack(spacing: 16) {
                Spacer()
                PetView(size: 96)
                    .shadow(color: Color.black.opacity(0.4), radius: 4, y: 2)
                Spacer()
                PlaceholderStatusStrip()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(action: onCollapse) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(Color.white.opacity(0.15), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(10)
            .help("收起到刘海")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RoomBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.11, green: 0.08, blue: 0.18),
                Color(red: 0.22, green: 0.14, blue: 0.28)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(red: 0.35, green: 0.22, blue: 0.15))
                .frame(height: 60)
        }
    }
}

/// Visual placeholder for the Block 2 status bars. Non-interactive.
private struct PlaceholderStatusStrip: View {
    var body: some View {
        HStack(spacing: 12) {
            statusPill(label: "おなか", color: .orange, fill: 0.7)
            statusPill(label: "きもち", color: .pink, fill: 0.9)
            statusPill(label: "げんき", color: .green, fill: 0.5)
        }
    }

    private func statusPill(label: String, color: Color, fill: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.15))
                GeometryReader { geo in
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * fill)
                }
            }
            .frame(height: 6)
        }
    }
}
