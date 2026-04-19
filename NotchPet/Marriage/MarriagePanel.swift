import SwiftUI

/// Marriage overlay. Triggered by the ring button in the RoomView
/// header (visible only for single adult pets). Two tabs: show your
/// pet's invitation QR, or scan a partner's. Mirrors ShopPanel's ZStack
/// structure so it lives inside RoomView without creating a new window.
struct MarriagePanel: View {
    @ObservedObject var petState: PetState
    @Binding var isShowing: Bool
    @ObservedObject private var settings = AppSettings.shared

    @State private var selectedTab: Tab = .showQR
    @State private var scanErrorMessage: String? = nil
    @State private var confirmation: String? = nil

    enum Tab: CaseIterable {
        case showQR, scanQR

        func label(_ lang: AppLanguage) -> String {
            switch self {
            case .showQR: return lang.marriageShowQRTab
            case .scanQR: return lang.marriageScanQRTab
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.86).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                tabBar
                content
                Spacer()
            }
        }
        .onTapGesture { /* swallow taps to block pass-through */ }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(settings.language.marriageTitle)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Spacer()
            Button {
                isShowing = false
            } label: {
                Text("×")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                    scanErrorMessage = nil
                } label: {
                    Text(tab.label(settings.language))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(selectedTab == tab
                                      ? Color.white.opacity(0.25)
                                      : Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 10)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let confirmation = confirmation {
            confirmationView(message: confirmation)
        } else {
            switch selectedTab {
            case .showQR: showQRContent
            case .scanQR: scanQRContent
            }
        }
    }

    // MARK: - Show-QR tab

    private var showQRContent: some View {
        VStack(spacing: 12) {
            if let payload = MarriagePayload.from(petState: petState) {
                QRCodeRenderer.image(from: payload.encode(), size: 180)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 180, height: 180)
                    .background(Color.white)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.12))
                    )

                Text(settings.language.marriageShowQRHint)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            } else {
                Text(settings.language.marriageIneligible)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.top, 40)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    // MARK: - Scan-QR tab

    private var scanQRContent: some View {
        VStack(spacing: 14) {
            Text(settings.language.marriageScanHint)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .padding(.horizontal, 30)

            Button {
                openScanner()
            } label: {
                Text(settings.language.marriageScanButton)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.18))
                    )
            }
            .buttonStyle(.plain)

            if let err = scanErrorMessage {
                Text(err)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.red.opacity(0.9))
            }
        }
    }

    private func openScanner() {
        scanErrorMessage = nil
        QRScanWindowController.shared.start(
            onDetected: { raw in
                guard let payload = MarriagePayload.decode(from: raw) else {
                    scanErrorMessage = settings.language.marriageScanFailed
                    return
                }
                petState.marry(with: payload.toPartnerSnapshot())
                confirmation = settings.language.marriageConfirmed
            },
            onCancel: {}
        )
    }

    // MARK: - Confirmation view

    private func confirmationView(message: String) -> some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 40)
            Text("♥")
                .font(.system(size: 36))
                .foregroundStyle(Color.pink.opacity(0.9))
            Text(message)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            if let partner = petState.partner {
                Text(partner.name)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
            }
            Button {
                isShowing = false
            } label: {
                Text(settings.language.confirmClose)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.18))
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }
}
