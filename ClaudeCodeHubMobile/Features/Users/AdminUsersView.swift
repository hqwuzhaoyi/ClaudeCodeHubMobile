import SwiftUI

struct AdminUsersView: View {
    @StateObject private var viewModel: AdminUsersViewModel

    init(sessionStore: SessionStore) {
        _viewModel = StateObject(wrappedValue: AdminUsersViewModel(sessionStore: sessionStore))
    }

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(message: errorMessage) {
                        Task { await viewModel.refresh() }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }

                Section {
                    HStack {
                        SummaryMetric(label: "Users", value: AppFormatters.integer(viewModel.users.count), icon: "person.2")
                        SummaryMetric(label: "Keys", value: AppFormatters.integer(viewModel.totalKeyCount), icon: "key")
                    }
                    Toggle("Disabled users only", isOn: $viewModel.showsDisabledOnly)
                } header: {
                    Text("User Management")
                } footer: {
                    Text("This mobile view focuses on safe inspection: users, groups, key status, quotas, and today's usage.")
                }

                Section {
                    if viewModel.filteredUsers.isEmpty && !viewModel.isLoading {
                        ContentUnavailableView("No users found", systemImage: "person.crop.circle.badge.questionmark", description: Text("Try changing the search or filter."))
                    } else {
                        ForEach(viewModel.filteredUsers) { user in
                            AdminUserRow(user: user)
                        }
                    }
                } header: {
                    HStack {
                        Text("Users")
                        Spacer()
                        Text("\(viewModel.filteredUsers.count) shown")
                    }
                }
            }
            .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search users, keys, groups…")
            .overlay {
                if viewModel.isLoading && viewModel.users.isEmpty {
                    ProgressView("Loading users…")
                }
            }
            .navigationTitle("Users")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.loadIfNeeded() }
        }
    }
}

private struct AdminUserRow: View {
    let user: AdminUser
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    StatusDot(isEnabled: user.isEnabled)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(user.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if let role = user.role {
                                Text(role.uppercased())
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(.secondary.opacity(0.12), in: Capsule())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(user.providerGroup ?? "No provider group")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(AppFormatters.money(user.todayUsage))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                        Text("\(user.keys.count) keys")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                Label(AppFormatters.integer(user.todayTokens), systemImage: "number")
                if let dailyQuota = user.dailyQuota ?? user.limitDailyUsd {
                    Label("Daily \(AppFormatters.money(dailyQuota))", systemImage: "speedometer")
                }
                if let rpm = user.rpm {
                    Label("\(rpm) RPM", systemImage: "gauge.with.dots.needle.bottom.50percent")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if isExpanded {
                if user.keys.isEmpty {
                    Text("No keys")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(user.keys) { key in
                            AdminKeyRow(key: key)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.vertical, 5)
    }
}

private struct AdminKeyRow: View {
    let key: AdminAPIKey

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                StatusDot(isEnabled: key.isEnabled, size: 7)
                Text(key.name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(AppFormatters.integer(key.todayCallCount))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Text(key.maskedKey ?? "masked key unavailable")
                    .font(.caption2.monospaced())
                Text(AppFormatters.money(key.todayUsage))
                Text(AppFormatters.integer(key.todayTokens))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let lastProviderName = key.lastProviderName {
                Label(lastProviderName, systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SummaryMetric: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.monospacedDigit())
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StatusDot: View {
    let isEnabled: Bool
    var size: CGFloat = 9

    var body: some View {
        Circle()
            .fill(isEnabled ? Color.green : Color.red)
            .frame(width: size, height: size)
            .padding(.top, 6)
    }
}
