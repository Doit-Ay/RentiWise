//
//  LocationSelectorViewController.swift
//  RentiWise
//
//  Created by admin99 on 08/12/25.
//

import UIKit
import CoreLocation
import Supabase

/// Bottom sheet to select location:
/// - Use current location (GPS + reverse geocode)
/// - Enter address manually
/// - Manage saved addresses
/// - Pick from saved addresses list (from backend)
///
/// When an option is tapped, the sheet dismisses first, then performs the action.
final class LocationSelectorViewController: UIViewController {

    // MARK: - Public API (callbacks)
    // Called after we have a final address string to use
    var onSelectedAddress: ((String) -> Void)?
    // Called when user chooses to enter manually; provide a completion to receive the final string
    var onEnterManualAddress: ((@escaping (String) -> Void) -> Void)?
    // Called when user chooses to manage saved addresses
    var onManageSavedAddresses: (() -> Void)?

    // MARK: - Private UI
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    // Data (backend addresses — only populated when user is signed in)
    private var saved: [Address] = []
    private var isSignedIn: Bool = false
    private let service: AddressServicing = AddressService()
    
    // App brand color used across the app (matches Home/others)
    private let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Change Location"
        view.backgroundColor = .systemBackground

        setupTable()
        Task { await reloadSaved() }  // checks auth internally

        // Configure as a bottom sheet if available
        if let sheet = presentationController as? UISheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.preferredCornerRadius = 16
        }
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @MainActor
    private func applySaved(_ list: [Address], signedIn: Bool) {
        isSignedIn = signedIn
        saved = list
        tableView.reloadData()
    }

    private func reloadSaved() async {
        // First check if the user is authenticated at all
        do {
            _ = try await SupabaseManager.shared.client.auth.session
            // Signed in — fetch only this user's addresses
            do {
                let list = try await service.list()
                await MainActor.run { self.applySaved(list, signedIn: true) }
            } catch {
                // Fetch failed — still signed in but show no saved addresses
                await MainActor.run { self.applySaved([], signedIn: true) }
            }
        } catch {
            // Not authenticated — guest mode: only 2 options, no DB fetch
            await MainActor.run { self.applySaved([], signedIn: false) }
        }
    }

    // MARK: - Actions

    private func dismissThen(_ work: @escaping () -> Void) {
        // Always dismiss the sheet first, then perform the action.
        dismiss(animated: true) { work() }
    }

    private func useCurrentLocation() {
        // Dismiss first, then run the async location work
        dismissThen { [weak self] in
            guard let self = self else { return }
            Task {
                do {
                    let loc = try await AppLocationManager.shared.currentLocation()
                    let name = try await AppLocationManager.shared.placename(for: loc)
                    // Set the coordinate directly for accurate distance calculations
                    DistanceService.shared.setViewerCoordinate(
                        latitude: loc.coordinate.latitude,
                        longitude: loc.coordinate.longitude
                    )
                    // Keep Home button title in sync via local store
                    SavedAddressesStore.shared.setDefaultSelectedAddress(name)
                    NotificationCenter.default.post(name: .locationDidChange, object: nil)
                    await MainActor.run {
                        self.onSelectedAddress?(name)
                    }
                } catch {
                    // Present an alert from the topmost visible VC after dismissal
                    await MainActor.run {
                        let ac = UIAlertController(title: "Location Unavailable",
                                                   message: error.localizedDescription,
                                                   preferredStyle: .alert)
                        ac.addAction(UIAlertAction(title: "OK", style: .default))
                        self.presentTopMost(ac)
                    }
                }
            }
        }
    }

    private func enterAddressManually() {
        // Dismiss first, then ask the presenter to push ManualAddressViewController
        dismissThen { [weak self] in
            guard let self = self else { return }
            self.onEnterManualAddress? { [weak self] address in
                guard let self = self else { return }
                let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                // Keep Home button title in sync locally
                SavedAddressesStore.shared.setDefaultSelectedAddress(trimmed)
                DistanceService.shared.clearAllDistanceCaches()
                self.onSelectedAddress?(trimmed)
            }
        }
    }

    private func manageSavedAddresses() {
        // Dismiss first, then ask the presenter to push the manager
        dismissThen { [weak self] in
            self?.onManageSavedAddresses?()
        }
    }

    // Present an alert from the currently top-most view controller (after we dismissed ourselves)
    private func presentTopMost(_ vc: UIViewController) {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            present(vc, animated: true)
            return
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        top.present(vc, animated: true)
    }

    // Build a compact display string from an Address to show on the Home button/sheet callback
    private func displayString(for addr: Address) -> String {
        // Prefer label if present; else city; include state to disambiguate
        if let label = addr.label, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return label
        }
        // "City, State" fallback
        let parts = [addr.city, addr.state].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return parts.joined(separator: ", ")
    }

    private func persistedSelectionString(for addr: Address) -> String {
        [
            addr.address_line1,
            addr.address_line2,
            addr.city,
            addr.state,
            addr.postal_code,
            addr.country
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }
}

// MARK: - UITableViewDataSource
extension LocationSelectorViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        // Section 0: Actions (2 rows for guest/no addresses, 3 rows when user has saved addresses)
        // Section 1: Saved addresses (only when signed in AND has ≥1 address)
        return (isSignedIn && !saved.isEmpty) ? 2 : 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            // If signed in AND has saved addresses: show 3 actions (includes Manage)
            // Otherwise: show only 2 options (Use GPS + Enter manually)
            return (isSignedIn && !saved.isEmpty) ? 3 : 2
        } else {
            // Section 1 only exists when isSignedIn && !saved.isEmpty
            return saved.count
        }
    }

    func tableView(_ tableView: UITableView,
                   titleForHeaderInSection section: Int) -> String? {
        return section == 1 ? "Saved Addresses" : nil
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()

        if indexPath.section == 0 {
            // Action rows
            switch indexPath.row {
            case 0:
                config.text = "Use current location"
                config.image = UIImage(systemName: "location.fill")
            case 1:
                config.text = "Enter address manually"
                config.image = UIImage(systemName: "square.and.pencil")
            case 2:
                // Only rendered when isSignedIn && !saved.isEmpty
                config.text = "Manage saved addresses"
                config.image = UIImage(systemName: "bookmark.circle")
            default:
                break
            }
        } else {
            // Saved addresses section — only reached when signed in
            guard indexPath.row < saved.count else {
                cell.contentConfiguration = config
                return cell
            }
            let address = saved[indexPath.row]
            let title: String
            if let label = address.label, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                title = "\(label) — \(address.address_line1)"
            } else {
                title = address.address_line1
            }
            let secondary = "\(address.city), \(address.state) \(address.postal_code)"
            config.text = title
            config.secondaryText = secondary
            config.image = UIImage(systemName: address.is_default ? "bookmark.fill" : "bookmark")
        }

        // Apply app brand tint to all row icons
        config.imageProperties.tintColor = brandTeal

        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        cell.tintColor = brandTeal
        return cell
    }
}

// MARK: - UITableViewDelegate
extension LocationSelectorViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0 {
            // Action rows — same for guests and signed-in users
            switch indexPath.row {
            case 0:
                useCurrentLocation()
            case 1:
                enterAddressManually()
            case 2:
                // Only reachable when isSignedIn && !saved.isEmpty
                manageSavedAddresses()
            default:
                break
            }
        } else {
            // Section 1: saved addresses — only reachable when signed in
            guard indexPath.row < saved.count else { return }
            let address = saved[indexPath.row]
            dismissThen { [weak self] in
                guard let self = self else { return }
                let display = self.displayString(for: address)

                // Set coordinates directly if available (avoids geocoding "Home"/"Office")
                if let lat = address.latitude, let lon = address.longitude, lat != 0, lon != 0 {
                    DistanceService.shared.setViewerCoordinate(latitude: lat, longitude: lon)
                } else {
                    DistanceService.shared.clearAllDistanceCaches()
                }

                let persistedSelection = self.persistedSelectionString(for: address)
                SavedAddressesStore.shared.setDefaultSelectedAddress(
                    persistedSelection.isEmpty ? display : persistedSelection
                )
                NotificationCenter.default.post(name: .locationDidChange, object: nil)
                self.onSelectedAddress?(display)
            }
        }
    }
}
