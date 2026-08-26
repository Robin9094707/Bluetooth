import SwiftUI

@main
struct RJBluetoothUltraApp: App {
    @StateObject private var scanner = BluetoothScanner()
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if didCompleteOnboarding {
                    RootView()
                        .environmentObject(scanner)
                } else {
                    OnboardingView {
                        didCompleteOnboarding = true
                    }
                    .environmentObject(scanner)
                }
            }
            .preferredColorScheme(nil)
        }
    }
}
