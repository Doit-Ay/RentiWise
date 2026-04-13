//
//  SavedAddressesStore.swift
//  RentiWise
//
//  Created by admin99 on 08/12/25.
//

import Foundation

/// A simple UserDefaults-backed store for saved addresses and the last selected address.
final class SavedAddressesStore {

    static let shared = SavedAddressesStore()

    private let defaults: UserDefaults
    private let currentUserIdProvider: () -> String?
    private let addressesKeyBase = "rw.savedAddresses"
    private let selectedAddressKeyBase = "rw.selectedAddress"

    init(
        defaults: UserDefaults = .standard,
        currentUserIdProvider: @escaping () -> String? = { SupabaseManager.shared.currentUserIdSync() }
    ) {
        self.defaults = defaults
        self.currentUserIdProvider = currentUserIdProvider
        bootstrapIfNeeded()
    }

    // MARK: - Bootstrap

    private func scopedKey(for baseKey: String) -> String {
        let scope = currentUserIdProvider()?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let normalizedScope = (scope?.isEmpty == false) ? scope! : "guest"
        return "\(baseKey).\(normalizedScope)"
    }

    private var addressesKey: String { scopedKey(for: addressesKeyBase) }
    private var selectedAddressKey: String { scopedKey(for: selectedAddressKeyBase) }

    private func bootstrapIfNeeded() {
        // Do not seed demo data. If nothing saved yet, keep it empty.
        if defaults.array(forKey: addressesKey) as? [String] == nil {
            defaults.set([], forKey: addressesKey)
        }
    }

    // MARK: - Addresses CRUD

    func allAddresses() -> [String] {
        bootstrapIfNeeded()
        return (defaults.array(forKey: addressesKey) as? [String]) ?? []
    }

    func add(_ address: String) {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var list = allAddresses()
        // De-duplicate: move to front if already exists
        if let idx = list.firstIndex(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            list.remove(at: idx)
        }
        list.insert(trimmed, at: 0)
        defaults.set(list, forKey: addressesKey)
    }

    func remove(at index: Int) {
        var list = allAddresses()
        guard index >= 0 && index < list.count else { return }
        let removed = list.remove(at: index)
        defaults.set(list, forKey: addressesKey)
        // If the removed one was selected, clear selection
        if let selected = getDefaultSelectedAddress(),
           selected.caseInsensitiveCompare(removed) == .orderedSame {
            defaults.removeObject(forKey: selectedAddressKey)
        }
    }

    func move(from sourceIndex: Int, to destinationIndex: Int) {
        var list = allAddresses()
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < list.count,
              destinationIndex >= 0, destinationIndex <= list.count else { return }
        let item = list.remove(at: sourceIndex)
        list.insert(item, at: destinationIndex)
        defaults.set(list, forKey: addressesKey)
    }

    func replaceAll(with addresses: [String]) {
        bootstrapIfNeeded()
        let trimmed = addresses
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        defaults.set(trimmed, forKey: addressesKey)
    }

    // MARK: - Selected address

    func setDefaultSelectedAddress(_ address: String) {
        bootstrapIfNeeded()
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            defaults.removeObject(forKey: selectedAddressKey)
            return
        }
        defaults.set(trimmed, forKey: selectedAddressKey)
        // Ensure it exists in saved list too
        add(trimmed)
    }

    func getDefaultSelectedAddress() -> String? {
        bootstrapIfNeeded()
        guard let s = defaults.string(forKey: selectedAddressKey),
              !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return s
    }

    func clearSelectedAddress() {
        bootstrapIfNeeded()
        defaults.removeObject(forKey: selectedAddressKey)
    }
    
    /// Resets the selected address to defaults (clears stored location).
    /// The app will use the default location (Chennai) on next refresh.
    func resetToDefault() {
        clearSelectedAddress()
    }
}
