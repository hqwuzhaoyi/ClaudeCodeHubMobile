import SwiftUI

/// Compatibility wrapper retained for the original scaffold target entry.
struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
        .environmentObject(SessionStore.previewSignedOut)
}
