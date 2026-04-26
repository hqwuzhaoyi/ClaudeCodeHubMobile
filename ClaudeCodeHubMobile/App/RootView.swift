import SwiftUI

struct RootView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        Group {
            if sessionStore.isBootstrapping {
                ProgressView("Restoring session…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sessionStore.isAuthenticated {
                MainTabView(sessionStore: sessionStore)
            } else {
                LoginView()
            }
        }
        .animation(.default, value: sessionStore.isAuthenticated)
        .task {
            await sessionStore.bootstrap()
        }
    }
}

private struct MainTabView: View {
    @ObservedObject var sessionStore: SessionStore

    var body: some View {
        TabView {
            OverviewView(sessionStore: sessionStore)
                .tabItem {
                    Label("Overview", systemImage: "chart.pie.fill")
                }

            LogsView(sessionStore: sessionStore)
                .tabItem {
                    Label("Logs", systemImage: "list.bullet.rectangle")
                }

            AccountView(sessionStore: sessionStore)
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }
        }
    }
}

#Preview("Signed out") {
    RootView()
        .environmentObject(SessionStore.previewSignedOut)
}

#Preview("Signed in") {
    RootView()
        .environmentObject(SessionStore.previewSignedIn)
}
