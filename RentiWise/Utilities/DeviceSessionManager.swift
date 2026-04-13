//
//  DeviceSessionManager.swift
//  RentiWise
//
//  Single-device session enforcement.
//  On sign-in, a unique device token is generated and stored both locally
//  (UserDefaults) and remotely (users.active_device_token column).
//  On app activation, the local token is compared with remote —
//  a mismatch means another device signed in, triggering force sign-out.
//

import UIKit
import Supabase

enum DeviceSessionManager {

    private static let localTokenKey = "active_device_token"

    // MARK: - Register (called after successful sign-in/sign-up)

    /// Generates a fresh device token, stores it locally and pushes it to the `users` table.
    static func registerDeviceSession(userId: String) async {
        let token = UUID().uuidString
        UserDefaults.standard.set(token, forKey: localTokenKey)

        struct TokenUpdate: Encodable {
            let active_device_token: String
        }

        do {
            try await SupabaseManager.shared.client
                .from("users")
                .update(TokenUpdate(active_device_token: token))
                .eq("id", value: userId)
                .execute()
            debugLog("[DeviceSession] Registered device token for user \(userId)")
        } catch {
            debugLog("[DeviceSession] Failed to push device token: \(error.localizedDescription)")
        }
    }

    // MARK: - Validate (called on every foreground activation)

    /// Returns `true` if this device's token still matches the one in the database.
    /// Returns `false` if another device has signed in (token mismatch).
    static func validateDeviceSession(userId: String) async -> Bool {
        let localToken = UserDefaults.standard.string(forKey: localTokenKey)

        struct TokenRow: Decodable {
            let active_device_token: String?
        }

        do {
            let response = try await SupabaseManager.shared.client
                .from("users")
                .select("active_device_token")
                .eq("id", value: userId)
                .single()
                .execute()

            let row = try JSONDecoder().decode(TokenRow.self, from: response.data)
            let remoteToken = row.active_device_token

            // Case 1: No local token (user was signed in before enforcement was deployed)
            if localToken == nil {
                if let remoteToken, !remoteToken.isEmpty {
                    // Another device has already registered — kick this device out
                    debugLog("[DeviceSession] No local token but remote exists — another device owns the session.")
                    return false
                } else {
                    // No one has claimed yet — register this device
                    await registerDeviceSession(userId: userId)
                    return true
                }
            }

            // Case 2: We have a local token — compare with remote
            guard let remoteToken, !remoteToken.isEmpty else {
                // Remote is NULL but we have a local token — re-register
                await registerDeviceSession(userId: userId)
                return true
            }

            if remoteToken == localToken {
                return true
            } else {
                debugLog("[DeviceSession] Token mismatch — another device signed in.")
                return false
            }
        } catch {
            // Network error — don't kick the user out on transient failures
            debugLog("[DeviceSession] Validation error (allowing session): \(error.localizedDescription)")
            return true
        }
    }

    // MARK: - Force Sign Out

    /// Signs the user out and presents an alert explaining why.
    @MainActor
    static func forceSignOutWithAlert() {
        // Sign out via Supabase
        Task {
            try? await SupabaseManager.shared.signOut()
        }

        // Find the key window and present the alert
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              let rootVC = window.rootViewController else {
            return
        }

        // Find topmost presented VC
        var presenter = rootVC
        while let next = presenter.presentedViewController {
            presenter = next
        }

        let alert = UIAlertController(
            title: "Signed Out",
            message: "Your account was signed in on another device. Each account can only be active on one device at a time.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            // Navigate to profile/sign-in
            if let tab = rootVC as? UITabBarController {
                tab.selectedIndex = 1  // Profile tab
                if let nav = tab.viewControllers?[1] as? UINavigationController {
                    let profileVC = ProfileViewController()
                    profileVC.title = ""
                    profileVC.hidesBottomBarWhenPushed = false
                    nav.setViewControllers([profileVC], animated: false)
                }
            }
        })
        presenter.present(alert, animated: true)
    }

    // MARK: - Clear (called on sign-out)

    /// Removes the local device token from UserDefaults.
    static func clearLocalToken() {
        UserDefaults.standard.removeObject(forKey: localTokenKey)
    }
}
