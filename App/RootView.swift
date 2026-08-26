import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { ScannerView() }
                .tabItem { Label("Scanner", systemImage: "wave.3.right") }
            NavigationStack { RadarView() }
                .tabItem { Label("Radar", systemImage: "scope") }
            NavigationStack { SafetyView() }
                .tabItem { Label("Schutz", systemImage: "shield.checkered") }
            NavigationStack { HistoryView() }
                .tabItem { Label("Verlauf", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Mehr", systemImage: "slider.horizontal.3") }
        }
    }
}
