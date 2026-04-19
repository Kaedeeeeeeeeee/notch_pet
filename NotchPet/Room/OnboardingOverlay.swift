import SwiftUI

/// First-run 3-step onboarding card shown on top of the RoomView while
/// `AppSettings.shared.hasCompletedOnboarding` is false. Tapping through
/// to the final step's "Let's begin" button sets the flag and the host
/// view unmounts this overlay.
struct OnboardingOverlay: View {
    @ObservedObject var petState: PetState
    let onFinish: () -> Void

    @State private var step: Int = 0
    @State private var eggPulse: Bool = false

    private var lang: AppLanguage { AppSettings.shared.language }

    private static let stepCount: Int = 3

    var body: some View {
        ZStack {
            Color.black.opacity(0.70).ignoresSafeArea()

            VStack(spacing: 14) {
                // Illustration slot — only step 2 shows a sprite today,
                // but the fixed-height frame keeps the card from jumping
                // between steps.
                ZStack {
                    if step == 1 {
                        SpriteImage(
                            species: petState.species,
                            stage: .egg,
                            mode: .idle,
                            personality: nil
                        )
                        .frame(width: 54, height: 54)
                        .scaleEffect(eggPulse ? 1.08 : 0.96)
                        .animation(
                            .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                            value: eggPulse
                        )
                    }
                }
                .frame(height: 60)

                Text(currentTitle)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(currentBody)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                // Progress dots — mirrors the filled/empty convention used
                // in the heart strip (filled = current step).
                HStack(spacing: 6) {
                    ForEach(0..<Self.stepCount, id: \.self) { i in
                        Circle()
                            .fill(Color.white.opacity(i == step ? 0.9 : 0.25))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.top, 4)

                Button {
                    if step < Self.stepCount - 1 {
                        step += 1
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(step < Self.stepCount - 1
                         ? lang.onboardingNextButton
                         : lang.onboardingStartButton)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .frame(maxWidth: 320)
        }
        .onTapGesture { }  // swallow taps to prevent pass-through
        .onAppear { eggPulse = true }
    }

    private var currentTitle: String {
        switch step {
        case 0:  return lang.onboardingStep1Title
        case 1:  return lang.onboardingStep2Title
        default: return lang.onboardingStep3Title
        }
    }

    private var currentBody: String {
        switch step {
        case 0:  return lang.onboardingStep1Body
        case 1:  return lang.onboardingStep2Body
        default: return lang.onboardingStep3Body
        }
    }
}
