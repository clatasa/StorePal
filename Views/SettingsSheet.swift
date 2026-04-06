internal import SwiftUI
import CoreLocation

struct SettingsSheet: View {
    @EnvironmentObject var viewModel: StoreViewModel
    @Environment(\.dismiss) var dismiss
    @AppStorage("useImperial") private var useImperial: Bool = false
    @AppStorage("geofenceAlertBehavior") private var alertBehaviorRaw: String = GeofenceAlertBehavior.always.rawValue

    private var alertBehavior: Binding<GeofenceAlertBehavior> {
        Binding(
            get: { GeofenceAlertBehavior(rawValue: alertBehaviorRaw) ?? .always },
            set: { alertBehaviorRaw = $0.rawValue }
        )
    }

    private var locationStatus: CLAuthorizationStatus {
        viewModel.locationService.authorizationStatus
    }

    // MARK: - Unit helpers

    private func formatRadius(_ meters: Double) -> String {
        useImperial
            ? String(format: "%.2f mi", meters * 0.000621371)
            : "\(Int(meters)) m"
    }

    private var sliderMinLabel: String { useImperial ? "0.06 mi" : "100 m" }
    private var sliderMaxLabel: String { useImperial ? "1.24 mi" : "2 km" }
    private var searchAreaLabel: String { useImperial ? "3.1 mi radius" : "5 km radius" }

    var body: some View {
        NavigationStack {
            Form {
                // ── Geo-fence radius ──────────────────────────────────────
                Section {
                    Picker("Distance Units", selection: $useImperial) {
                        Text("Meters").tag(false)
                        Text("Miles").tag(true)
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Alert Radius")
                            Spacer()
                            Text(formatRadius(viewModel.geofenceRadius))
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
                            Text(sliderMinLabel)
                            Spacer()
                            Text(sliderMaxLabel)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Store Geo-fence")
                } footer: {
                    Text("Default alert radius for all stores. Applies immediately to stores without a custom radius. Long-press a store on the home screen to set a per-store override.")
                }

                // ── Alert behavior ────────────────────────────────────────
                Section {
                    ForEach(GeofenceAlertBehavior.allCases, id: \.self) { option in
                        Button {
                            alertBehavior.wrappedValue = option
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.label)
                                        .foregroundStyle(.primary)
                                    Text(option.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if alertBehavior.wrappedValue == option {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Store Alert Behavior")
                } footer: {
                    Text("Controls when you receive a notification upon entering a store's geo-fence.")
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
                    LabeledContent("Search Area",   value: searchAreaLabel)
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
