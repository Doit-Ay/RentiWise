//
//  ProfileViewController.swift
//  RentiWise
//
//  Created by admin99 on 07/12/25.
//

import UIKit
import Supabase
import UniformTypeIdentifiers
import PhotosUI
import AVFoundation
import CoreLocation

final class ProfileViewController: UITableViewController {
    
    // Navigation delegate for tab bar hiding
    private let tabBarDelegate = TabBarNavigationDelegate()
    
    // MARK: - State
    private var isLoggedIn: Bool = false
    private var displayName: String = "Guest User"
    private var userEmail: String = ""
    private var userPhone: String = ""
    private var phoneVerified: Bool = false
    private var kycStatus: String = "none"
    private var currentProfile: UserProfile?

    private var showsAddPhoneRow: Bool {
        isLoggedIn && userPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var showsKYCVerificationRow: Bool {
        ((Bundle.main.object(forInfoDictionaryKey: "ENABLE_KYC_VERIFICATION") as? NSNumber)?.boolValue) ?? false
    }

    private var kycRowIndex: Int? {
        guard showsKYCVerificationRow else { return nil }
        return showsAddPhoneRow ? 2 : 1
    }
    
    // App brand color
    private let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
    
    // MARK: - Sections
    private enum Section: Int, CaseIterable {
        case account
        case more
        case settings
        case signOut
    }
    
    // MARK: - Lifecycle
    
    init() {
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Profile"
        
        // Set up table view
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(AccountHeaderCell.self, forCellReuseIdentifier: "AccountHeaderCell")
        tableView.backgroundColor = .systemGroupedBackground
        
        // Ensure content doesn't go under navigation bar
        tableView.contentInsetAdjustmentBehavior = .automatic
        
        // Add extra top padding to prevent section header from going under nav bar
        tableView.contentInset.top = 16
        
        // Set up navigation
        navigationController?.delegate = tabBarDelegate
        
        // Refresh control
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEntitlementsChanged),
            name: .iapEntitlementsDidChange,
            object: nil
        )
        
        // Initial auth state
        Task { await refreshAuthState() }
        
        // Print the tab index
        if let idx = computeProfileTabIndex() {
            debugLog("[Profile] Tab index = \(idx)")
        } else {
            debugLog("[Profile] Tab index not found (not inside a UITabBarController).")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Always show tab bar when Profile root screen appears
        tabBarController?.tabBar.isHidden = false
        
        // Set up edit button
        updateNavigationBar()
        
        // Refresh data
        Task { await refreshAuthState() }
    }
    
    // MARK: - Actions
    
    @objc private func handleRefresh() {
        Task {
            await refreshAuthState()
            await MainActor.run {
                refreshControl?.endRefreshing()
            }
        }
    }

    @objc private func handleEntitlementsChanged() {
        Task { await refreshAuthState() }
    }
    
    @objc private func editProfileTapped() {
        let baseProfile = currentProfile ?? UserProfile(
            id: "",
            fullName: displayName == "Guest User" ? "" : displayName,
            email: userEmail,
            phone: userPhone,
            phoneVerified: phoneVerified,
            kycStatus: kycStatus,
            upiId: "",
            collegeEmail: "",
            isCollegeVerified: false,
            averageRating: 0,
            totalRentalsAsBorrower: 0,
            borrowFreezeUntil: nil
        )
        let editVC = EditProfileViewController(profile: baseProfile)
        editVC.onSaved = { [weak self] profile in
            self?.applyProfile(profile)
            self?.tableView.reloadData()
        }
        let nav = UINavigationController(rootViewController: editVC)
        present(nav, animated: true)
    }
    
    private func updateNavigationBar() {
        if isLoggedIn {
            let editButton = UIBarButtonItem(
                image: UIImage(systemName: "pencil"),
                style: .plain,
                target: self,
                action: #selector(editProfileTapped)
            )
            editButton.tintColor = brandTeal
            navigationItem.rightBarButtonItem = editButton
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }
    
    // MARK: - TableView DataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if isLoggedIn {
            return Section.allCases.count
        } else {
            return 3 // account, more, settings (no sign out)
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        
        switch sectionType {
        case .account:
            if isLoggedIn {
                // header + optional verify phone + optional KYC row
                var count = 1
                if showsAddPhoneRow { count += 1 }
                if showsKYCVerificationRow { count += 1 }
                return count
            } else {
                return 2 // header + sign up button
            }
        case .more:
            return 4 // My Rentals, Wishlist, Privacy & Security, Contact Us
        case .settings:
            return 1 // App permissions
        case .signOut:
            return isLoggedIn ? 1 : 0
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }
        
        switch sectionType {
        case .account:
            return "Account"
        case .more:
            return nil
        case .settings:
            return nil
        case .signOut:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sectionType = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        
        // Get a fresh cell and reset its state to prevent reuse issues
        let cell: UITableViewCell
        switch sectionType {
        case .account where indexPath.row == 0:
            guard let headerCell = tableView.dequeueReusableCell(withIdentifier: "AccountHeaderCell", for: indexPath) as? AccountHeaderCell else {
                assertionFailure("Could not dequeue AccountHeaderCell")
                return UITableViewCell()
            }
            headerCell.configure(
                displayName: displayName,
                email: userEmail,
                phone: userPhone,
                isLoggedIn: isLoggedIn
            )
            return headerCell
        default:
            cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        }
        
        // Reset cell to default state before configuration (prevents reuse issues)
        cell.textLabel?.textAlignment = .left
        cell.textLabel?.textColor = .label
        cell.accessoryType = .none
        cell.accessoryView = nil
        cell.imageView?.image = nil
        cell.imageView?.tintColor = brandTeal
        cell.selectionStyle = .default
        
        switch sectionType {
        case .account:
            // Account header cell is handled above
            if !isLoggedIn {
                // Sign up button
                cell.textLabel?.text = "Sign Up"
                cell.textLabel?.textColor = brandTeal
            } else {
                if showsAddPhoneRow && indexPath.row == 1 {
                    cell.textLabel?.text = "Add Phone Number"
                    cell.textLabel?.textColor = brandTeal
                    cell.accessoryType = .disclosureIndicator
                    cell.imageView?.image = UIImage(systemName: "phone.badge.plus")
                    cell.imageView?.tintColor = brandTeal
                } else if let kycRowIndex, indexPath.row == kycRowIndex {
                    // KYC / Identity Verification row
                    cell.accessoryType = .disclosureIndicator
                    switch kycStatus {
                    case "approved":
                        cell.textLabel?.text = "🪪 Identity Verified"
                        cell.textLabel?.textColor = .systemGreen
                        cell.imageView?.image = UIImage(systemName: "checkmark.seal.fill")
                        cell.imageView?.tintColor = .systemGreen
                    case "pending":
                        cell.textLabel?.text = "🪪 Verification Pending"
                        cell.textLabel?.textColor = .systemOrange
                        cell.imageView?.image = UIImage(systemName: "clock.fill")
                        cell.imageView?.tintColor = .systemOrange
                    case "declined":
                        cell.textLabel?.text = "🪪 Verification Declined"
                        cell.textLabel?.textColor = .systemRed
                        cell.imageView?.image = UIImage(systemName: "xmark.seal.fill")
                        cell.imageView?.tintColor = .systemRed
                    default:
                        cell.textLabel?.text = "Verify Identity"
                        cell.textLabel?.textColor = brandTeal
                        cell.imageView?.image = UIImage(systemName: "person.badge.shield.checkmark")
                        cell.imageView?.tintColor = brandTeal
                    }
                }
            }
            return cell
            
        case .more:
            cell.accessoryType = .disclosureIndicator
            cell.textLabel?.textColor = .label
            
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "My Rentals"
                cell.imageView?.image = UIImage(systemName: "bag")
                cell.imageView?.tintColor = brandTeal
            case 1:
                cell.textLabel?.text = "Wishlist"
                cell.imageView?.image = UIImage(systemName: "heart")
                cell.imageView?.tintColor = brandTeal
            case 2:
                cell.textLabel?.text = "Privacy & Security"
                cell.imageView?.image = UIImage(systemName: "lock.shield")
                cell.imageView?.tintColor = brandTeal
            case 3:
                cell.textLabel?.text = "Contact Us"
                cell.imageView?.image = UIImage(systemName: "message")
                cell.imageView?.tintColor = brandTeal
            default:
                break
            }
            
            return cell
            
        case .settings:
            cell.textLabel?.text = "App Permissions"
            cell.textLabel?.textColor = .label
            cell.imageView?.image = UIImage(systemName: "slider.horizontal.3")
            cell.imageView?.tintColor = brandTeal
            cell.accessoryType = .disclosureIndicator
            cell.accessoryView = nil
            cell.selectionStyle = .default
            
            return cell
            
        case .signOut:
            cell.textLabel?.text = "Sign Out"
            cell.textLabel?.textColor = .systemRed
            cell.textLabel?.textAlignment = .center
            cell.accessoryType = .none
            cell.accessoryView = nil
            cell.imageView?.image = nil
            return cell
        }
    }
    
    // MARK: - TableView Delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let sectionType = Section(rawValue: indexPath.section) else { return }
        
        switch sectionType {
        case .account:
            if indexPath.row == 1 && !isLoggedIn {
                // Sign up button
                openSignUp()
            } else if isLoggedIn {
                if showsAddPhoneRow && indexPath.row == 1 {
                    presentAddPhoneNumber()
                } else if let kycRowIndex, indexPath.row == kycRowIndex {
                    // KYC row
                    presentKYCVerification()
                }
            }
            
        case .more:
            switch indexPath.row {
            case 0:
                let vc = MyRentalsViewController()
                vc.title = "My Rentals"
                vc.hidesBottomBarWhenPushed = true
                navigationController?.pushViewController(vc, animated: true)
            case 1:
                let vc = WishlistViewController()
                vc.hidesBottomBarWhenPushed = true
                navigationController?.pushViewController(vc, animated: true)
            case 2:
                let vc = PrivacySecurityViewController()
                vc.hidesBottomBarWhenPushed = true
                navigationController?.pushViewController(vc, animated: true)
            case 3:
                let vc = SupportTicketListViewController()
                vc.title = "Support"
                vc.hidesBottomBarWhenPushed = true
                navigationController?.pushViewController(vc, animated: true)
            default:
                break
            }
            
        case .settings:
            let vc = AppPermissionsViewController()
            vc.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(vc, animated: true)
            
        case .signOut:
            Task { await signOut() }
        }
    }
    
    // MARK: - Auth helpers
    
    private func openSignUp() {
        let vc = SignUpViewController()
        vc.title = "Sign Up"
        vc.hidesBottomBarWhenPushed = true
        
        if let nav = navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }

    // MARK: - Add Phone Number

    private func presentAddPhoneNumber() {
        let alert = UIAlertController(
            title: "Add Phone Number",
            message: "Enter your 10-digit Indian mobile number.",
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = "e.g. 9876543210"
            field.keyboardType = .numberPad
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self,
                  let digits = alert.textFields?.first?.text?.filter({ $0.isNumber }),
                  digits.count == 10 else {
                self?.showSavePhoneError("Please enter a valid 10-digit number.")
                return
            }
            let e164 = "+91\(digits)"
            Task {
                await self.savePhoneNumber(e164)
            }
        })
        present(alert, animated: true)
    }

    private func savePhoneNumber(_ phone: String) async {
        guard let userId = await SupabaseManager.shared.currentUserId() else { return }
        struct PhoneUpdate: Encodable { let phone: String }
        do {
            try await SupabaseManager.shared.client
                .from("users")
                .update(PhoneUpdate(phone: phone))
                .eq("id", value: userId)
                .execute()
            await refreshAuthState()
        } catch {
            await MainActor.run {
                self.showSavePhoneError("Failed to save: \(error.localizedDescription)")
            }
        }
    }

    private func showSavePhoneError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - KYC Verification

    private func presentKYCVerification() {
        let kycVC = KYCVerificationViewController()
        kycVC.onComplete = { [weak self] status in
            self?.kycStatus = status
            self?.tableView.reloadData()
        }
        kycVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(kycVC, animated: true)
    }

    private func signOut() async {
        do {
            try await SupabaseManager.shared.signOut()
            // Reset location to default (Chennai, Tamil Nadu)
            SavedAddressesStore.shared.resetToDefault()
            await refreshAuthState()
        } catch {
            debugLog("Sign out error: \(error)")
        }
    }
    
    private func refreshAuthState() async {
        if let id = await SupabaseManager.shared.currentUserId() {
            await MainActor.run {
                isLoggedIn = true
            }
            await fetchDisplayInfo(userId: id)
        } else {
            await MainActor.run {
                isLoggedIn = false
                currentProfile = nil
                displayName = "Guest User"
                userEmail = ""
                userPhone = ""
                phoneVerified = false
                kycStatus = "none"
            }
        }
        
        await MainActor.run {
            tableView.reloadData()
            updateNavigationBar()
        }
    }
    
    private func fetchDisplayInfo(userId: String) async {
        let service = ProfileService()
        do {
            let profile = try await service.fetchCurrentUserProfile()
            await MainActor.run {
                self.applyProfile(profile)
            }
        } catch {
            await MainActor.run {
                self.currentProfile = nil
                self.displayName = "User"
                self.userEmail = ""
                self.userPhone = ""
                self.phoneVerified = false
                self.kycStatus = "none"
            }
        }
    }
    
    private func applyProfile(_ profile: UserProfile) {
        currentProfile = profile
        displayName = profile.fullName.isEmpty ? "User" : profile.fullName
        userEmail = profile.email
        userPhone = profile.phone
        phoneVerified = profile.phoneVerified
        kycStatus = profile.kycStatus
    }



    private func computeProfileTabIndex() -> Int? {
        if let tab = self.tabBarController ?? findTabBarControllerFromWindow() {
            guard let vcs = tab.viewControllers, !vcs.isEmpty else { return nil }
            for (i, vc) in vcs.enumerated() {
                if vc === self { return i }
                if let nav = vc as? UINavigationController {
                    if nav.viewControllers.first is ProfileViewController || nav.viewControllers.contains(where: { $0 === self }) {
                        return i
                    }
                }
            }
        }
        return nil
    }
    
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

// MARK: - Account Header Cell

private class AccountHeaderCell: UITableViewCell {
    
    private let iconView = UIImageView()
    private let nameRow = UIStackView()
    private let nameLabel = UILabel()
    private let emailLabel = UILabel()
    private let phoneLabel = UILabel()
    private let messageLabel = UILabel()
    
    // App brand color
    private let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        selectionStyle = .none
        
        // Icon
        iconView.image = UIImage(systemName: "person.crop.circle.fill")
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = brandTeal
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        nameRow.axis = .horizontal
        nameRow.alignment = .center
        nameRow.spacing = 8

        nameRow.addArrangedSubview(nameLabel)
        
        // Labels stack
        let stack = UIStackView(arrangedSubviews: [nameRow, emailLabel, phoneLabel, messageLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        
        nameLabel.font = .preferredFont(forTextStyle: .headline)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        emailLabel.font = .preferredFont(forTextStyle: .subheadline)
        emailLabel.textColor = .secondaryLabel
        phoneLabel.font = .preferredFont(forTextStyle: .subheadline)
        phoneLabel.textColor = .secondaryLabel
        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.textColor = .secondaryLabel
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44),
            
            stack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(displayName: String, email: String, phone: String, isLoggedIn: Bool) {
        nameLabel.text = displayName.isEmpty ? "Guest User" : displayName
        iconView.tintColor = brandTeal
        
        if isLoggedIn {
            emailLabel.text = email.isEmpty ? nil : email
            emailLabel.isHidden = email.isEmpty
            phoneLabel.text = phone.isEmpty ? nil : phone
            phoneLabel.isHidden = phone.isEmpty
            messageLabel.isHidden = true
        } else {
            emailLabel.isHidden = true
            phoneLabel.isHidden = true
            messageLabel.text = "Create an account to sync and manage bookings"
            messageLabel.isHidden = false
        }
    }
}

// MARK: - Supporting View Controllers

// These will be implemented separately in the continuation
