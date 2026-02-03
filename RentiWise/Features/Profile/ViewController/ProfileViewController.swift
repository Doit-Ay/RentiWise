//
//  ProfileViewController.swift
//  RentiWise
//
//  Created by admin99 on 07/12/25.
//

import UIKit
import SwiftUI
import Supabase
import UniformTypeIdentifiers
import PhotosUI
import AVFoundation
import CoreLocation
import UserNotifications

final class ProfileViewController: UIViewController {

    private var hosting: UIHostingController<ProfileRootView>?
    
    // Navigation delegate for tab bar hiding
    private let tabBarDelegate = TabBarNavigationDelegate()

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

        // Print the tab index (if embedded in a UITabBarController)
        if let idx = computeProfileTabIndex() {
            print("[Profile] Tab index =", idx)
        } else {
            print("[Profile] Tab index not found (not inside a UITabBarController).")
        }
        
        // Set navigation delegate to auto-hide tab bar on push
        navigationController?.delegate = tabBarDelegate
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Always show tab bar when Profile root screen appears
        tabBarController?.tabBar.isHidden = false
    }

    // Finds the UITabBarController and returns the index of the tab that contains this ProfileViewController
    // It checks both: the VC directly in the tab, or wrapped in a UINavigationController.
    private func computeProfileTabIndex() -> Int? {
        // First, try the nearest tab bar controller in the hierarchy
        if let tab = self.tabBarController ?? findTabBarControllerFromWindow() {
            guard let vcs = tab.viewControllers, !vcs.isEmpty else { return nil }
            for (i, vc) in vcs.enumerated() {
                // Case 1: ProfileViewController is directly the tab's VC
                if vc === self { return i }
                // Case 2: The tab hosts a UINavigationController containing ProfileViewController
                if let nav = vc as? UINavigationController {
                    // If Profile is the root or currently visible controller in that nav, consider it "the profile tab"
                    if nav.viewControllers.first is ProfileViewController || nav.viewControllers.contains(where: { $0 === self }) {
                        return i
                    }
                }
            }
        }
        return nil
    }

    // Fallback: find the tab bar controller from the key window (covers SwiftUI hosting or unusual hierarchies)
    private func findTabBarControllerFromWindow() -> UITabBarController? {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            if let tab = window.rootViewController as? UITabBarController {
                return tab
            }
            if let nav = window.rootViewController as? UINavigationController,
               let tab = nav.viewControllers.first as? UITabBarController {
                return tab
            }
        }
        return nil
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

// Bridge to present SupportChatViewController inside SwiftUI (push style)
private struct SupportChatHost: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SupportChatViewController {
        let vc = SupportChatViewController()
        vc.title = "Support"
        // If you need any initial configuration, do it here.
        return vc
    }
    func updateUIViewController(_ uiViewController: SupportChatViewController, context: Context) {}
}

// Bridge to present ProductViewController inside SwiftUI (push style)
private struct ProductHostView: UIViewControllerRepresentable {
    let item: Item
    func makeUIViewController(context: Context) -> ProductViewController {
        let nibName = "ProductViewController"
        let vc: ProductViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
            Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
                vc = ProductViewController(nibName: nibName, bundle: nil)
        } else {
            vc = ProductViewController()
        }
        vc.configure(with: item)
        vc.title = "Product Detail"
        vc.hidesBottomBarWhenPushed = true
        return vc
    }
    func updateUIViewController(_ uiViewController: ProductViewController, context: Context) {}
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
                    NavigationLink {
                        MyRentalsHostView()
                            .navigationTitle("My Rentals")
                            .navigationBarTitleDisplayMode(.inline)
                            .hideTabBar()
                    } label: {
                        Label("My Rentals", systemImage: "bag")
                    }

                    NavigationLink {
                        WishlistPage()
                            .hideTabBar()
                    } label: {
                        Label("Wishlist", systemImage: "heart")
                    }

                    NavigationLink {
                        PrivacySecurityPage()
                            .hideTabBar()
                    } label: {
                        Label("Privacy & Security", systemImage: "lock.shield")
                    }

                    NavigationLink {
                        SupportChatHost()
                            .navigationTitle("Support")
                            .navigationBarTitleDisplayMode(.inline)
                            .hideTabBar()
                    } label: {
                        Label("Contact Us", systemImage: "message")
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
            .onAppear {
                // Show tab bar when Profile root screen appears
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let tabBarController = window.rootViewController as? UITabBarController {
                    tabBarController.tabBar.isHidden = false
                }
            }
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
    @State private var isLoading = false
    @State private var items: [Item] = []
    @State private var errorMessage: String?

    private let brandTeal = Color(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0)

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            if items.isEmpty && !isLoading && errorMessage == nil {
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
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
                .listRowBackground(Color.clear)
            }

            ForEach(items, id: \.id) { item in
                NavigationLink {
                    ProductHostView(item: item)
                        .navigationBarTitleDisplayMode(.inline)
                        .hideTabBar()
                } label: {
                    HStack(spacing: 12) {
                        WishlistImage(path: item.images.first)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                                .lineLimit(2)
                            Text(priceText(for: item))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "heart.fill")
                            .foregroundStyle(brandTeal)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await loadWishlist() }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Wishlist")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadWishlist() }
        .hideTabBar()
    }

    private func priceText(for item: Item) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2
        let amount = NSNumber(value: item.price_per_day)
        let price = nf.string(from: amount) ?? String(format: "%.2f", item.price_per_day)
        return "\(price) / day"
    }

    private func loadWishlist() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        defer { Task { await MainActor.run { isLoading = false } } }

        guard let userId = await SupabaseManager.shared.currentUserId() else {
            await MainActor.run { errorMessage = "Please sign in to view your wishlist." }
            return
        }

        struct WishRow: Decodable { let item_id: String }
        do {
            let client = SupabaseManager.shared.client
            // FIX: use the correct table name "wishlist" (singular)
            let resp = try await client
                .from("wishlist")
                .select("item_id")
                .eq("user_id", value: userId)
                .execute()
            let wishRows = try JSONDecoder().decode([WishRow].self, from: resp.data)
            let itemIds = wishRows.map { $0.item_id }
            if itemIds.isEmpty {
                await MainActor.run { self.items = [] }
                return
            }
            let itemsResp = try await client
                .from("items")
                .select()
                .in("id", value: itemIds)
                .execute()
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let fetched = try decoder.decode([Item].self, from: itemsResp.data)
            await MainActor.run { self.items = fetched }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}

private struct WishlistImage: View {
    let path: String?

    var body: some View {
        Group {
            if let path, let url = StorageURLBuilder.publicFileURL(for: path) {
                if #available(iOS 15.0, *) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            placeholder
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            placeholder
                        @unknown default:
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: 60, height: 60)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var placeholder: some View {
        Image(systemName: "photo")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.secondary)
            .padding(10)
    }
}

private struct ManageDataViews: View {
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            Section("Data") {
                NavigationLink("Profile Information") { ProfileInformationView().hideTabBar() }
                NavigationLink("Payment History") { PaymentHistoryView().hideTabBar() }
            }

            Section("Actions") {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    if isDeleting {
                        HStack { ProgressView(); Text("Deleting Account…") }
                    } else {
                        Text("Delete Account")
                    }
                }
            }
        }
        .navigationTitle("Manage Data")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) { Task { await deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your profile, bookings, and payments. This action cannot be undone.")
        }
        .background(Color(.systemGroupedBackground))
    }

    private func deleteAccount() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }
        do {
            guard let userId = await SupabaseManager.shared.currentUserId() else {
                throw NSError(domain: "ManageData", code: 2, userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
            }

            let client = SupabaseManager.shared.client
            // Delete related rows (order matters if FKs don't cascade)
            _ = try await client.from("payments").delete().eq("user_id", value: userId).execute()
            _ = try await client.from("bookings").delete().eq("user_id", value: userId).execute()
            _ = try await client.from("wishlist").delete().eq("user_id", value: userId).execute()
            _ = try await client.from("users").delete().eq("id", value: userId).execute()

            try await SupabaseManager.shared.signOut()
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }
}

// MARK: - Data detail views

private struct ProfileInformationView: View {
    @State private var profile: UserProfile?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
            if isLoading { ProgressView().frame(maxWidth: .infinity, alignment: .center) }
            if let profile {
                Section("Profile") {
                    LabeledContent("Full Name", value: profile.fullName)
                    LabeledContent("Email", value: profile.email)
                    if !profile.phone.isEmpty { LabeledContent("Phone", value: profile.phone) }
                }
            }
        }
        .navigationTitle("Profile Information")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .background(Color(.systemGroupedBackground))
    }

    private func load() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        defer { Task { await MainActor.run { isLoading = false } } }
        do {
            let p = try await ProfileService().fetchCurrentUserProfile()
            await MainActor.run { profile = p }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}

private struct BookingHistoryView: View {
    @State private var items: [BookingItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
            if isLoading { ProgressView().frame(maxWidth: .infinity, alignment: .center) }
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title).font(.headline)
                    Text("\(dateRange(item.startDate, item.endDate)) • Total: \(currency(item.totalPrice))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("Booking History")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .background(Color(.systemGroupedBackground))
    }

    private func load() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        defer { Task { await MainActor.run { isLoading = false } } }
        do {
            guard let userId = await SupabaseManager.shared.currentUserId() else {
                throw NSError(domain: "BookingHistory", code: 1, userInfo: [NSLocalizedDescriptionKey: "Please sign in to view your bookings."])
            }
            let client = SupabaseManager.shared.client
            let resp = try await client
                .from("bookings")
                .select("id,item_id,start_date,end_date,total_price,items(title)")
                .eq("user_id", value: userId)
                .order("start_date", ascending: false)
                .execute()
            struct Row: Decodable { let id: String; let item_id: String; let start_date: Date; let end_date: Date; let total_price: Double; let items: ItemTitle }
            struct ItemTitle: Decodable { let title: String }
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            let rows = try decoder.decode([Row].self, from: resp.data)
            let mapped = rows.map { row in
                BookingItem(id: row.id, title: row.items.title, startDate: row.start_date, endDate: row.end_date, totalPrice: row.total_price)
            }
            await MainActor.run { self.items = mapped }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func currency(_ value: Double) -> String {
        let nf = NumberFormatter(); nf.numberStyle = .currency; return nf.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    private func dateRange(_ s: Date, _ e: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return "\(df.string(from: s)) – \(df.string(from: e))"
    }
}

private struct BookingItem: Identifiable { let id: String; let title: String; let startDate: Date; let endDate: Date; let totalPrice: Double }

// Modifications start here for PaymentHistoryView:

private struct PaymentHistoryView: View {
    @State private var items: [PaymentHistoryItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let brandTeal = Color(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0)

    var body: some View {
        List {
            if let errorMessage { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
            if isLoading { ProgressView().frame(maxWidth: .infinity, alignment: .center) }

            // Group by calendar day
            ForEach(groupedByDayKeys(), id: \.self) { key in
                Section(header: Text(sectionTitle(for: key)).font(.subheadline).foregroundStyle(.secondary)) {
                    ForEach(itemsForDay(key)) { p in
                        HStack {
                            Spacer(minLength: 0)
                            HStack(alignment: .center, spacing: 12) {
                                // Leading icon container
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(.secondarySystemBackground))
                                    Image(systemName: iconForProvider(p.provider))
                                        .foregroundStyle(brandTeal)
                                }
                                .frame(width: 36, height: 36)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(p.itemTitle.isEmpty ? "Item" : p.itemTitle)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    Text(p.itemCategory.isEmpty ? "" : p.itemCategory)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    // Payment method + time
                                    Text("\(prettyProvider(p.provider)) • \(timeText(p.createdAt))")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }

                                Spacer(minLength: 8)

                                Text(currency(p.amount))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                            }
                            .padding(12)
                            .frame(width: 361, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                            )
                            Spacer(minLength: 0)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Payment History")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        await MainActor.run { isLoading = true; errorMessage = nil }

        defer { Task { await MainActor.run { isLoading = false } } }

        do {
            guard let userId = await SupabaseManager.shared.currentUserId() else {
                throw NSError(domain: "PaymentHistory", code: 1, userInfo: [NSLocalizedDescriptionKey: "Please sign in to view your payments."])
            }

            let client = SupabaseManager.shared.client
            let resp = try await client
                .from("payments")
                .select("id,total_amount,status,provider,created_at,items(title,category)")
                .eq("borrower_id", value: userId)
                .order("created_at", ascending: false)
                .execute()

            struct ItemInfo: Decodable { let title: String?; let category: String? }
            struct PaymentDec: Decodable {
                let id: String
                let total_amount: Double
                let status: String
                let provider: String
                let created_at: Date
                let items: ItemInfo?
            }

            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            let rows = try decoder.decode([PaymentDec].self, from: resp.data)
            let mapped = rows.map { row in
                PaymentHistoryItem(
                    id: row.id,
                    amount: row.total_amount,
                    status: row.status,
                    createdAt: row.created_at,
                    provider: row.provider,
                    itemTitle: row.items?.title ?? "",
                    itemCategory: row.items?.category ?? ""
                )
            }
            await MainActor.run { self.items = mapped }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func currency(_ value: Double) -> String {
        let nf = NumberFormatter(); nf.numberStyle = .currency; return nf.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    private func dateText(_ d: Date) -> String {
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short; return df.string(from: d)
    }
    private func timeText(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df.string(from: d)
    }

    private func groupedByDayKeys() -> [String] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let keys = Set(items.map { df.string(from: $0.createdAt) })
        // Sort descending by date string (ISO-like format sorts lexicographically)
        return keys.sorted(by: >)
    }

    private func itemsForDay(_ key: String) -> [PaymentHistoryItem] {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        return items.filter { df.string(from: $0.createdAt) == key }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func sectionTitle(for key: String) -> String {
        let inDF = DateFormatter(); inDF.dateFormat = "yyyy-MM-dd"
        let outDF = DateFormatter(); outDF.dateStyle = .medium; outDF.timeStyle = .none
        if let d = inDF.date(from: key) { return outDF.string(from: d) }
        return key
    }

    private func iconForProvider(_ provider: String) -> String {
        switch provider.lowercased() {
        case "apple_pay": return "apple.logo"
        case "card": return "creditcard"
        case "cod": return "banknote"
        default: return "creditcard"
        }
    }

    private func prettyProvider(_ provider: String) -> String {
        switch provider.lowercased() {
        case "apple_pay": return "Apple Pay"
        case "card": return "Card"
        case "cod": return "Cash on Delivery"
        default: return provider.capitalized
        }
    }
}

private struct PaymentHistoryItem: Identifiable {
    let id: String
    let amount: Double
    let status: String
    let createdAt: Date
    let provider: String
    let itemTitle: String
    let itemCategory: String
}

// MARK: - PrivacySecurityPage fix

private struct PrivacySecurityPage: View {
    var body: some View {
        List {
            Section("Privacy") {
                NavigationLink {
                    ManageDataViews()
                        .hideTabBar()
                } label: {
                    Text("Manage Data")
                }
                
                NavigationLink {
                    AppPermissionsView()
                        .hideTabBar()
                } label: {
                    Text("App Permissions")
                }
            }
            Section("Security") {
                NavigationLink {
                    ChangePasswordView()
                        .hideTabBar()
                } label: {
                    Text("Change Password")
                }
            }
        }
        .navigationTitle("Privacy & Security")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .hideTabBar()
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
                // Replaced Contact Us with SupportChatHost in ProfileRootView section above.
                NavigationLink("Report a Problem") { Text("Report a Problem") }
            }
        }
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}

private struct ChangePasswordView: View {
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""

    @State private var showCurrent: Bool = false
    @State private var showNew: Bool = false
    @State private var showConfirm: Bool = false

    @State private var isUpdating: Bool = false
    @State private var statusMessage: String?

    private let brandTeal = Color(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0)

    var body: some View {
        VStack(spacing: 16) {
            Form {
                Section("") {
                    // Current Password
                    passwordRow(title: "Current Password", text: $currentPassword, isSecure: !showCurrent, toggle: { showCurrent.toggle() })

                    // New Password
                    passwordRow(title: "New Password", text: $newPassword, isSecure: !showNew, toggle: { showNew.toggle() })

                    // Confirm New Password
                    passwordRow(title: "Confirm New Password", text: $confirmPassword, isSecure: !showConfirm, toggle: { showConfirm.toggle() })
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isUpdating {
                    ProgressView()
                } else {
                    Button("Update") {
                        Task { await updatePassword() }
                    }
                    .tint(brandTeal)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Row helper
    @ViewBuilder
    private func passwordRow(title: String, text: Binding<String>, isSecure: Bool, toggle: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if isSecure {
                    SecureField(title, text: text)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } else {
                    TextField(title, text: text)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            Spacer(minLength: 8)
            Button(action: toggle) {
                Image(systemName: isSecure ? "eye.slash" : "eye")
                    .foregroundStyle(brandTeal)
            }
            .accessibilityLabel(isSecure ? "Show Password" : "Hide Password")
        }
    }

    // MARK: - Supabase update (no validation logic)
    private func updatePassword() async {
        await MainActor.run { isUpdating = true; statusMessage = nil }
        defer { Task { await MainActor.run { isUpdating = false } } }
        do {
            // UI-only per request: no validation. Attempt password update via Supabase.
            try await SupabaseManager.shared.client.auth.update(user: .init(password: newPassword))
            await MainActor.run { statusMessage = "Password updated." }
        } catch {
            await MainActor.run { statusMessage = error.localizedDescription }
        }
    }
}

private struct AppPermissionsView: View {
    @State private var locationEnabled = false
    @State private var cameraEnabled = false
    @State private var photosEnabled = false
    @State private var notificationsEnabled = false

    @State private var showSettingsAlert = false
    @State private var settingsAlertMessage = ""

    private let brandTeal = Color(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0)

    var body: some View {
        Form {
            Section("App Permissions") {
                Toggle("Location", isOn: Binding(
                    get: { locationEnabled },
                    set: { newValue in handleLocationToggle(newValue) }
                ))
                .tint(brandTeal)

                Toggle("Camera", isOn: Binding(
                    get: { cameraEnabled },
                    set: { newValue in handleCameraToggle(newValue) }
                ))
                .tint(brandTeal)

                Toggle("Photos", isOn: Binding(
                    get: { photosEnabled },
                    set: { newValue in handlePhotosToggle(newValue) }
                ))
                .tint(brandTeal)

                Toggle("Notifications", isOn: Binding(
                    get: { notificationsEnabled },
                    set: { newValue in handleNotificationsToggle(newValue) }
                ))
                .tint(brandTeal)
            }
        }
        .onAppear { refreshStatuses() }
        .navigationTitle("App Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .alert("Change Permissions", isPresented: $showSettingsAlert, actions: {
            Button("Cancel", role: .cancel) {}
            Button("Open Settings") { openAppSettings() }
        }, message: {
            Text(settingsAlertMessage)
        })
    }

    // MARK: - Status refresh
    private func refreshStatuses() {
        // Location
        let locStatus = CLLocationManager.authorizationStatus()
        locationEnabled = (locStatus == .authorizedAlways || locStatus == .authorizedWhenInUse)
        // Camera
        let camStatus = AVCaptureDevice.authorizationStatus(for: .video)
        cameraEnabled = (camStatus == .authorized)

        // Photos (read-write path for pickers)
        let phStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        photosEnabled = (phStatus == .authorized || phStatus == .limited)

        // Notifications
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsEnabled = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
            }
        }
    }

    // MARK: - Toggles
    private func handleLocationToggle(_ newValue: Bool) {
        let status = CLLocationManager.authorizationStatus()
        if newValue {
            switch status {
            case .notDetermined:
                let manager = CLLocationManager()
                manager.requestWhenInUseAuthorization()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { refreshStatuses() }
            case .denied, .restricted:
                settingsAlertMessage = "Location access is disabled. You can enable it in Settings."
                showSettingsAlert = true
                // Revert UI
                locationEnabled = false
            default:
                refreshStatuses()
            }
        } else {
            settingsAlertMessage = "To turn off Location access, please use the Settings app."
            showSettingsAlert = true
            // Reflect current system state again
            refreshStatuses()
        }
    }

    private func handleCameraToggle(_ newValue: Bool) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if newValue {
            switch status {
            case .notDetermined:
                Task { @MainActor in
                    let granted = await AVCaptureDevice.requestAccess(for: .video)
                    cameraEnabled = granted
                }
            case .denied, .restricted:
                settingsAlertMessage = "Camera access is disabled. You can enable it in Settings."
                showSettingsAlert = true
                cameraEnabled = false
            case .authorized:
                cameraEnabled = true
            @unknown default:
                cameraEnabled = false
            }
        } else {
            settingsAlertMessage = "To turn off Camera access, please use the Settings app."
            showSettingsAlert = true
            refreshStatuses()
        }
    }

    private func handlePhotosToggle(_ newValue: Bool) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if newValue {
            switch status {
            case .notDetermined:
                Task { @MainActor in
                    let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                    photosEnabled = (newStatus == .authorized || newStatus == .limited)
                }
            case .denied, .restricted:
                settingsAlertMessage = "Photos access is disabled. You can enable it in Settings."
                showSettingsAlert = true
                photosEnabled = false
            case .limited, .authorized:
                photosEnabled = true
            @unknown default:
                photosEnabled = false
            }
        } else {
            settingsAlertMessage = "To turn off Photos access, please use the Settings app."
            showSettingsAlert = true
            refreshStatuses()
        }
    }

    private func handleNotificationsToggle(_ newValue: Bool) {
        if newValue {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                switch settings.authorizationStatus {
                case .notDetermined:
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                        DispatchQueue.main.async {
                            notificationsEnabled = granted
                        }
                    }
                case .denied:
                    DispatchQueue.main.async {
                        settingsAlertMessage = "Notifications are disabled. You can enable them in Settings."
                        showSettingsAlert = true
                        notificationsEnabled = false
                    }
                case .authorized, .provisional, .ephemeral:
                    DispatchQueue.main.async { notificationsEnabled = true }
                @unknown default:
                    DispatchQueue.main.async { notificationsEnabled = false }
                }
            }
        } else {
            settingsAlertMessage = "To turn off Notifications, please use the Settings app."
            showSettingsAlert = true
            refreshStatuses()
        }
    }

    // MARK: - Helpers
    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}
