//
//  LocationSelectorViewController.swift
//  RentiWise
//
//  Created by admin99 on 08/12/25.
//

import UIKit
import CoreLocation

/// Bottom sheet to select location:
/// - Use current location (GPS + reverse geocode)
/// - Enter address manually
/// - Manage saved addresses
/// - Pick from saved addresses list
///
/// Present it modally; on iOS 15+ it uses UISheetPresentationController with .medium/.large detents.
final class LocationSelectorViewController: UIViewController {

    // MARK: - Public API (callbacks)
    var onSelectedAddress: ((String) -> Void)?
    var onEnterManualAddress: ((@escaping (String) -> Void) -> Void)?
    var onManageSavedAddresses: (() -> Void)?

    // MARK: - Private UI
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    // Data
    private var saved: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Change Location"
        view.backgroundColor = .systemBackground

        setupTable()
        reloadSaved()

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

    private func reloadSaved() {
        saved = SavedAddressesStore.shared.allAddresses()
        tableView.reloadData()
    }

    // MARK: - Actions

    private func useCurrentLocation() {
        Task {
            do {
                let loc = try await AppLocationManager.shared.currentLocation()
                let name = try await AppLocationManager.shared.placename(for: loc)
                SavedAddressesStore.shared.setDefaultSelectedAddress(name)
                await MainActor.run {
                    self.onSelectedAddress?(name)
                    self.dismiss(animated: true)
                }
            } catch {
                await MainActor.run {
                    let ac = UIAlertController(title: "Location Unavailable",
                                               message: error.localizedDescription,
                                               preferredStyle: .alert)
                    ac.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(ac, animated: true)
                }
            }
        }
    }

    private func enterAddressManually() {
        // Let the presenter provide a UI to enter address; when done, call the completion with the address string.
        onEnterManualAddress? { [weak self] address in
            guard let self = self else { return }
            let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            SavedAddressesStore.shared.setDefaultSelectedAddress(trimmed)
            self.onSelectedAddress?(trimmed)
            self.dismiss(animated: true)
        }
    }

    private func manageSavedAddresses() {
        onManageSavedAddresses?()
    }
}

// MARK: - UITableViewDataSource
extension LocationSelectorViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        // Section 0: Actions
        // Section 1: Saved addresses (if any)
        return saved.isEmpty ? 1 : 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if saved.isEmpty {
            // Only actions
            switch section {
            case 0: return 2 // Use GPS, Enter manually (no Manage when none saved)
            default: return 0
            }
        } else {
            if section == 0 {
                return 3 // Use GPS, Enter manually, Manage saved
            } else {
                return saved.count
            }
        }
    }

    func tableView(_ tableView: UITableView,
                   titleForHeaderInSection section: Int) -> String? {
        if saved.isEmpty {
            return section == 0 ? nil : nil
        } else {
            return section == 1 ? "Saved addresses" : nil
        }
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()

        if saved.isEmpty {
            // Actions only
            if indexPath.section == 0 {
                if indexPath.row == 0 {
                    config.text = "Use current location"
                    config.image = UIImage(systemName: "location.fill")
                } else {
                    config.text = "Enter address manually"
                    config.image = UIImage(systemName: "square.and.pencil")
                }
            }
        } else {
            if indexPath.section == 0 {
                switch indexPath.row {
                case 0:
                    config.text = "Use current location"
                    config.image = UIImage(systemName: "location.fill")
                case 1:
                    config.text = "Enter address manually"
                    config.image = UIImage(systemName: "square.and.pencil")
                case 2:
                    config.text = "Manage saved addresses"
                    config.image = UIImage(systemName: "bookmark.circle")
                default:
                    break
                }
            } else {
                // Saved addresses section
                let address = saved[indexPath.row]
                config.text = address
                config.image = UIImage(systemName: "bookmark")
            }
        }

        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }
}

// MARK: - UITableViewDelegate
extension LocationSelectorViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if saved.isEmpty {
            // Actions only
            if indexPath.section == 0 {
                if indexPath.row == 0 {
                    useCurrentLocation()
                } else {
                    enterAddressManually()
                }
            }
            return
        }

        if indexPath.section == 0 {
            switch indexPath.row {
            case 0:
                useCurrentLocation()
            case 1:
                enterAddressManually()
            case 2:
                manageSavedAddresses()
            default:
                break
            }
        } else {
            // Pick a saved address
            let address = saved[indexPath.row]
            SavedAddressesStore.shared.setDefaultSelectedAddress(address)
            onSelectedAddress?(address)
            dismiss(animated: true)
        }
    }
}
