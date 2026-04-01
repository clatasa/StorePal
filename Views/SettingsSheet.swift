internal import SwiftUI
import CoreLocation

struct SettingsSheet: View {
    @EnvironmentObject var viewModel: StoreViewModel
    @Environment(\.dismiss) var dismiss

    private var locationStatus: CLAuthorizationStatus {
        viewModel.locationService.authorizationStatus
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── Geo-fence radius ──────────────────────────────────────
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Alert Radius")
                            Spacer()
                            Text("\(Int(viewModel.geofenceRadius)) m")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: $viewModel.geofenceRadius,
                            in: 100...2000,
                            step: 50
                        )
                        .tint(.blue)
                        HStack {
                            Text("100 m")
                            Spacer()
                            Text("2 km")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Geo-fence Radius")
                } footer: {
                    Text("You'll be alerted when you're within \(Int(viewModel.geofenceRadius)) m of a saved store. Changes apply to all stores immediately.")
                }

                // ── Permissions ───────────────────────────────────────────
                Section("Permissions") {
                    PermissionRow(
                        title: "Location",
                        detail: locationDetail,
                        color: locationColor,
                        action: locationAction
                    )
                    PermissionRow(
                        title: "Notifications",
                        detail: viewModel.notificationService.isAuthorized
                            ? "Enabled"
                            : "Disabled — alerts won't appear",
                        color: viewModel.notificationService.isAuthorized ? .green : .red,
                        action: viewModel.notificationService.isAuthorized ? nil : {
                            Task { await viewModel.notificationService.requestAuthorization() }
                        }
                    )
                }

                // ── Status ────────────────────────────────────────────────
                Section("Status") {
                    LabeledContent("Saved Stores",  value: "\(viewModel.favorites.count) / \(viewModel.maxFavorites)")
                    LabeledContent("Detection",     value: "CLRegion Monitoring")
                    LabeledContent("Search Area",   value: "5 km radius")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Helpers

    private var locationDetail: String {
        switch locationStatus {
        case .authorizedAlways:    return "Always — geo-fencing active"
        case .authorizedWhenInUse: return "When In Use — background alerts disabled"
        case .denied:              return "Denied — open Settings to enable"
        case .notDetermined:       return "Not yet requested"
        default:                   return "Restricted"
        }
    }

    private var locationColor: Color {
        switch locationStatus {
        case .authorizedAlways:    return .green
        case .authorizedWhenInUse: return .orange
        default:                   return .red
        }
    }

    private var locationAction: (() -> Void)? {
        switch locationStatus {
        case .notDetermined, .authorizedWhenInUse:
            return { viewModel.locationService.requestAlwaysAuthorization() }
        case .denied:
            return {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        default: return nil
        }
    }
}

// MARK: - Reusable permission row

struct PermissionRow: View {
    let title: String
    let detail: String
    let color: Color
    let action: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let action {
                Button("Fix", action: action)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}
