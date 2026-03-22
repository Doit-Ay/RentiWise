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
import UserNotifications

final class ProfileViewController: UITableViewController {
    
    // Navigation delegate for tab bar hiding
    private let tabBarDelegate = TabBarNavigationDelegate()
    
    // MARK: - State
    private var isLoggedIn: Bool = false
    private var displayName: String = "Guest User"
    private var userEmail: String = ""
    private var userPhone: String = ""
    private var userUpiId: String = ""
    private var userBadgeTier: String = "newcomer"
    private var userTrustScore: Int = 0
    private var isCollegeVerified: Bool = false
    private var notificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "notificationsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "notificationsEnabled") }
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
        
        // Initial auth state
        Task { await refreshAuthState() }
        
        // Print the tab index
        if let idx = computeProfileTabIndex() {
            print("[Profile] Tab index =", idx)
        } else {
            print("[Profile] Tab index not found (not inside a UITabBarController).")
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
    
    @objc private func editProfileTapped() {
        let editVC = EditProfileViewController(
            fullName: displayName == "Guest User" ? "" : displayName,
            email: userEmail,
            phone: userPhone,
            upiId: userUpiId
        )
        editVC.onSaved = { [weak self] newName, newPhone, newUpiId in
            self?.displayName = newName.isEmpty ? "User" : newName
            self?.userPhone = newPhone
            self?.userUpiId = newUpiId
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
            return isLoggedIn ? 1 : 2 // header + sign up button if not logged in
        case .more:
            return 5 // My Rentals, Wishlist, Privacy & Security, Contact Us, Trust Score
        case .settings:
            return 1 // Notifications toggle
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
            let headerCell = tableView.dequeueReusableCell(withIdentifier: "AccountHeaderCell", for: indexPath) as! AccountHeaderCell
            headerCell.configure(
                displayName: displayName,
                email: userEmail,
                phone: userPhone,
                isLoggedIn: isLoggedIn,
                badgeTier: userBadgeTier,
                trustScore: userTrustScore,
                isCollegeVerified: isCollegeVerified
            )
            headerCell.onVerifyTapped = { [weak self] in
                guard let self else { return }
                if self.isCollegeVerified {
                    // Show detail screen
                    let detailVC = CollegeVerifiedDetailViewController()
                    detailVC.hidesBottomBarWhenPushed = true
                    self.navigationController?.pushViewController(detailVC, animated: true)
                } else {
                    // Show verification flow
                    let vc = CollegeVerificationViewController()
                    vc.onVerificationComplete = { [weak self] in
                        self?.isCollegeVerified = true
                        self?.tableView.reloadData()
                    }
                    vc.hidesBottomBarWhenPushed = true
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
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
            // Account header cell is handled above, this must be the sign up button
            cell.textLabel?.text = "Sign Up"
            cell.textLabel?.textColor = brandTeal
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
            case 4:
                cell.textLabel?.text = "Trust Score"
                cell.imageView?.image = UIImage(systemName: "shield.checkered")
                cell.imageView?.tintColor = brandTeal
            default:
                break
            }
            
            return cell
            
        case .settings:
            cell.textLabel?.text = "Notifications"
            cell.textLabel?.textColor = .label
            cell.imageView?.image = UIImage(systemName: "bell")
            cell.imageView?.tintColor = brandTeal
            
            let toggle = UISwitch()
            toggle.onTintColor = brandTeal
            toggle.isOn = notificationsEnabled
            toggle.addTarget(self, action: #selector(notificationsToggled(_:)), for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
            
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
    
    @objc private func notificationsToggled(_ sender: UISwitch) {
        notificationsEnabled = sender.isOn
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
                let vc = SupportChatViewController()
                vc.title = "Support"
                vc.hidesBottomBarWhenPushed = true
                navigationController?.pushViewController(vc, animated: true)
            case 4:
                let vc = TrustScoreBreakdownViewController()
                vc.hidesBottomBarWhenPushed = true
                navigationController?.pushViewController(vc, animated: true)
            default:
                break
            }
            
        case .settings:
            break
            
        case .signOut:
            Task { await signOut() }
        }
    }
    
    // MARK: - Auth helpers
    
    private func openSignUp() {
        let nibName = "SignUpViewController"
        let vc: SignUpViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
            Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            vc = SignUpViewController(nibName: nibName, bundle: nil)
        } else {
            vc = SignUpViewController(service: SignUpService())
        }
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
    
    private func signOut() async {
        do {
            try await SupabaseManager.shared.signOut()
            // Reset location to default (Chennai, Tamil Nadu)
            SavedAddressesStore.shared.resetToDefault()
            await refreshAuthState()
        } catch {
            print("Sign out error:", error)
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
                displayName = "Guest User"
                userEmail = ""
                userPhone = ""
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
            // Also fetch trust score/badge
            struct TrustRow: Decodable { let trust_score: Int?; let badge_tier: String?; let is_college_verified: Bool? }
            var trustScore = 0
            var badgeTier = "newcomer"
            var collegeVerified = false
            do {
                let userId = profile.id
                let resp = try await SupabaseManager.shared.client
                    .from("users")
                    .select("trust_score, badge_tier, is_college_verified")
                    .eq("id", value: userId)
                    .single()
                    .execute()
                let row = try JSONDecoder().decode(TrustRow.self, from: resp.data)
                trustScore = row.trust_score ?? 0
                badgeTier = row.badge_tier ?? "newcomer"
                collegeVerified = row.is_college_verified ?? false
            } catch { /* trust score fetch is non-critical */ }

            await MainActor.run {
                self.displayName = profile.fullName.isEmpty ? "User" : profile.fullName
                self.userEmail = profile.email
                self.userPhone = profile.phone
                self.userUpiId = profile.upiId
                self.userTrustScore = trustScore
                self.userBadgeTier = badgeTier
                self.isCollegeVerified = collegeVerified
            }
        } catch {
            await MainActor.run {
                self.displayName = "User"
                self.userEmail = ""
                self.userPhone = ""
                self.userUpiId = ""
            }
        }
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
    private let nameLabel = UILabel()
    private let verifiedPill = UIButton(type: .system)
    private let emailLabel = UILabel()
    private let phoneLabel = UILabel()
    private let messageLabel = UILabel()
    private let trustBadge = TrustBadgeView()
    
    var onVerifyTapped: (() -> Void)?
    
    // App brand color
    private let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        
        // Icon
        iconView.image = UIImage(systemName: "person.crop.circle.fill")
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = brandTeal
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)
        
        // Name row (name + verified pill)
        verifiedPill.titleLabel?.font = .systemFont(ofSize: 10, weight: .semibold)
        verifiedPill.contentEdgeInsets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        verifiedPill.layer.cornerRadius = 8
        verifiedPill.clipsToBounds = true
        verifiedPill.addTarget(self, action: #selector(verifyPillTapped), for: .touchUpInside)
        verifiedPill.translatesAutoresizingMaskIntoConstraints = false
        
        let nameRow = UIStackView(arrangedSubviews: [nameLabel, verifiedPill, UIView()])
        nameRow.axis = .horizontal
        nameRow.spacing = 8
        nameRow.alignment = .center
        
        // Trust badge
        trustBadge.translatesAutoresizingMaskIntoConstraints = false
        trustBadge.isHidden = true
        
        // Labels stack
        let stack = UIStackView(arrangedSubviews: [nameRow, emailLabel, phoneLabel, trustBadge, messageLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        
        nameLabel.font = .preferredFont(forTextStyle: .headline)
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
    
    @objc private func verifyPillTapped() {
        onVerifyTapped?()
    }
    
    func configure(displayName: String, email: String, phone: String, isLoggedIn: Bool, badgeTier: String = "newcomer", trustScore: Int = 0, isCollegeVerified: Bool = false) {
        nameLabel.text = displayName.isEmpty ? "Guest User" : displayName
        
        if isLoggedIn {
            emailLabel.text = email.isEmpty ? nil : email
            emailLabel.isHidden = email.isEmpty
            phoneLabel.text = phone.isEmpty ? nil : phone
            phoneLabel.isHidden = phone.isEmpty
            messageLabel.isHidden = true
            // Show trust badge
            trustBadge.badgeTier = badgeTier
            trustBadge.trustScore = trustScore
            trustBadge.isHidden = false
            // Verified pill
            verifiedPill.isHidden = false
            if isCollegeVerified {
                verifiedPill.setTitle("🎓 Verified", for: .normal)
                verifiedPill.setTitleColor(.white, for: .normal)
                verifiedPill.backgroundColor = brandTeal
                verifiedPill.isUserInteractionEnabled = false
            } else {
                verifiedPill.setTitle("Unverified", for: .normal)
                verifiedPill.setTitleColor(.secondaryLabel, for: .normal)
                verifiedPill.backgroundColor = UIColor.systemGray5
                verifiedPill.isUserInteractionEnabled = true
            }
        } else {
            emailLabel.isHidden = true
            phoneLabel.isHidden = true
            trustBadge.isHidden = true
            verifiedPill.isHidden = true
            messageLabel.text = "Create an account to sync and manage bookings"
            messageLabel.isHidden = false
        }
    }
}

// MARK: - Supporting View Controllers

// These will be implemented separately in the continuation
