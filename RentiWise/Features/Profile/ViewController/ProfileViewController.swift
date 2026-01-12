//
//  ProfileViewController.swift
//  RentiWise
//
//  Created by admin99 on 07/12/25.
//

import UIKit
import SwiftUI
import Supabase

final class ProfileViewController: UIViewController {

    private var hosting: UIHostingController<ProfileRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Show a visible title for Profile (SwiftUI will also set its own)
        title = "Profile"
        // Page background should be grouped to let white cards pop
        view.backgroundColor = .systemGroupedBackground

        // Build SwiftUI root
        let root = ProfileRootView()
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        hosting = host
    }
}

// MARK: - SwiftUI wrappers

// A host that embeds MyRentalsViewController inside SwiftUI and hides the tab bar while active.
private struct MyRentalsHostView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> MyRentalsViewController {
        let vc = MyRentalsViewController()
        // Ensure title is correct from the VC side too
        vc.title = "My Rentals"
        // Important: this flag only applies when pushed in UIKit. Since we’re in SwiftUI,
        // we’ll also hide the tab bar via a UIKit bridge (below) on appear.
        vc.hidesBottomBarWhenPushed = true
        return vc
    }
    func updateUIViewController(_ uiViewController: MyRentalsViewController, context: Context) {}
}

// A helper UIViewController to toggle tab bar visibility when presented in SwiftUI.
private struct TabBarHider: UIViewControllerRepresentable {
    let hidden: Bool
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        DispatchQueue.main.async {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first,
               let tab = window.rootViewController as? UITabBarController {
                tab.tabBar.isHidden = hidden
            }
        }
        return vc
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first,
               let tab = window.rootViewController as? UITabBarController {
                tab.tabBar.isHidden = hidden
            }
        }
    }
}

// MARK: - SwiftUI Profile

private struct ProfileRootView: View {

    @State private var isLoggedIn: Bool = false
    @State private var displayName: String = "Guest User"
    @State private var userEmail: String = ""
    @State private var userPhone: String = ""
    @State private var showEditProfile = false

    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    var body: some View {
        NavigationStack {
            List {
                // Account
                Section("Account") {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(displayName.isEmpty ? "Guest User" : displayName)
                                .font(.headline)

                            if isLoggedIn {
                                if !userEmail.isEmpty {
                                    Text(userEmail)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                if !userPhone.isEmpty {
                                    Text(userPhone)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("Sign in to sync and manage bookings")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !isLoggedIn {
                        Button("Sign In") {
                            openSignIn()
                        }
                    }
                }

                // More
                Section {
                    // Keep everything in SwiftUI NavigationStack.
                    NavigationLink {
                        // Hide tab bar while this destination is shown
                        MyRentalsHostView()
                            .background(TabBarHider(hidden: true))
                            .navigationTitle("My Rentals")
                            .navigationBarTitleDisplayMode(.inline)
                            .onDisappear {
                                // Restore tab bar when leaving
                                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let window = scene.windows.first,
                                   let tab = window.rootViewController as? UITabBarController {
                                    tab.tabBar.isHidden = false
                                }
                            }
                    } label: {
                        Label("My Rentals", systemImage: "bag")
                    }

                    NavigationLink {
                        WishlistPage()
                    } label: {
                        Label("Wishlist", systemImage: "heart")
                    }

                    NavigationLink {
                        PrivacySecurityPage()
                    } label: {
                        Label("Privacy & Security", systemImage: "lock.shield")
                    }

                    NavigationLink {
                        HelpSupportPage()
                    } label: {
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }
                }

                // Settings
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Notifications", systemImage: "bell")
                    }
                }

                // Sign out
                if isLoggedIn {
                    Section {
                        Button(role: .destructive) {
                            Task { await signOut() }
                        } label: {
                            Text("Sign Out")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isLoggedIn {
                        Button {
                            showEditProfile = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(Color(red: 0x70/255, green: 0xA7/255, blue: 0xB4/255))
                        }
                        .accessibilityLabel("Edit Profile")
                    }
                }
            }
            .task { await refreshAuthState() }
            .onAppear { Task { await refreshAuthState() } }
            .refreshable { await refreshAuthState() }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(
                    fullName: displayName == "Guest User" ? "" : displayName,
                    email: userEmail,
                    phone: userPhone,
                    onSaved: { newName, newPhone in
                        self.displayName = newName.isEmpty ? "User" : newName
                        self.userPhone = newPhone
                    }
                )
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Auth helpers
    private func openSignIn() {
        guard let top = topViewController() else { return }
        let nibName = "SignViewController"
        let signInVC: SignViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
            Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            signInVC = SignViewController(nibName: nibName, bundle: nil)
        } else {
            signInVC = SignViewController(service: SignInService())
        }
        signInVC.routeContext = .fromProfile
        signInVC.title = "Sign in"

        if let nav = top as? UINavigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(signInVC, animated: true)
        } else if let nav = top.navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(signInVC, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: signInVC)
            nav.modalPresentationStyle = .fullScreen
            top.present(nav, animated: true)
        }
    }

    private func signOut() async {
        do {
            try await SupabaseManager.shared.signOut()
            await refreshAuthState()
        } catch {
        }
    }

    private func refreshAuthState() async {
        if let id = await SupabaseManager.shared.currentUserId() {
            isLoggedIn = true
            await fetchDisplayInfo(userId: id)
        } else {
            isLoggedIn = false
            displayName = "Guest User"
            userEmail = ""
            userPhone = ""
        }
    }

    private func fetchDisplayInfo(userId: String) async {
        let service = ProfileService()
        do {
            let profile = try await service.fetchCurrentUserProfile()
            await MainActor.run {
                self.displayName = profile.fullName.isEmpty ? "User" : profile.fullName
                self.userEmail = profile.email
                self.userPhone = profile.phone
            }
        } catch {
            await MainActor.run {
                self.displayName = "User"
                self.userEmail = ""
                self.userPhone = ""
            }
        }
    }

    private func topViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?.rootViewController) -> UIViewController? {

        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}

// MARK: - Edit Profile

private struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var fullName: String
    let email: String
    @State private var phone: String

    var onSaved: (_ newName: String, _ newPhone: String) -> Void

    @State private var isSaving = false
    @State private var errorMessage: String?

    init(fullName: String, email: String, phone: String, onSaved: @escaping (_ newName: String, _ newPhone: String) -> Void) {
        _fullName = State(initialValue: fullName)
        self.email = email
        _phone = State(initialValue: phone)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Full Name", text: $fullName)
                        .textInputAutocapitalization(.words)
                }
                Section("Contact") {
                    TextField("Email", text: .constant(email))
                        .disabled(true)
                        .foregroundStyle(.secondary)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .disabled(fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            guard let userId = await SupabaseManager.shared.currentUserId() else {
                throw NSError(domain: "Profile", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
            }

            struct UpdateRow: Encodable {
                let full_name: String
                let phone: String
            }

            _ = try await SupabaseManager.shared.client
                .from("users")
                .update(UpdateRow(full_name: trimmedName, phone: trimmedPhone))
                .eq("id", value: userId)
                .execute()

            onSaved(trimmedName, trimmedPhone)
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Placeholder pages

private struct WishlistPage: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Wishlist")
                .font(.headline)
            Text("Add items to your wishlist from Explore.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 24)
        .navigationTitle("Wishlist")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}

private struct PrivacySecurityPage: View {
    var body: some View {
        List {
            Section("Privacy") {
                NavigationLink("Manage Data") { Text("Manage Data") }
                NavigationLink("App Permissions") { Text("App Permissions") }
            }
            Section("Security") {
                NavigationLink("Change Password") { Text("Change Password") }
                NavigationLink("Two-Factor Authentication") { Text("Two-Factor Authentication") }
            }
        }
        .navigationTitle("Privacy & Security")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}

private struct HelpSupportPage: View {
    var body: some View {
        List {
            Section("Help") {
                NavigationLink("FAQ") { Text("FAQ") }
                NavigationLink("Getting Started") { Text("Getting Started") }
            }
            Section("Support") {
                NavigationLink("Contact Us") { Text("Contact Us") }
                NavigationLink("Report a Problem") { Text("Report a Problem") }
            }
        }
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}

