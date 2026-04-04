//
//  UserProfileViewController.swift
//  RentiWise
//
//  App Store Compliance: Guideline 1.2 — Safety & Report/Block on user profile surfaces.
//

import UIKit
import Supabase

/// A lightweight public profile view for another user.
/// Shows display name, avatar, and provides Report / Block safety actions.
/// Presented when tapping an owner's name/avatar on a listing or from other UGC surfaces.
final class UserProfileViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    // MARK: - Public API (set before pushing)
    var userId: String = ""
    var displayName: String?

    // MARK: - Dependencies
    private let safetyService = CommunitySafetyService.shared

    // MARK: - UI
    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let memberSinceLabel = UILabel()
    private let listingsHeaderLabel = UILabel()
    private let statusLabel = UILabel()
    private let listingsTableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyStateLabel = UILabel()
    private var listings: [Item] = []
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Profile"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: self,
            action: #selector(didTapSafetyMenu)
        )
        navigationItem.rightBarButtonItem?.tintColor = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)

        setupUI()
        loadProfile()
        loadListings()
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Avatar
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.layer.cornerRadius = 44
        avatarImageView.backgroundColor = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 0.15)
        view.addSubview(avatarImageView)

        // Name
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 22, weight: .bold)
        nameLabel.textAlignment = .center
        nameLabel.text = displayName ?? "User"
        view.addSubview(nameLabel)

        // Member since
        memberSinceLabel.translatesAutoresizingMaskIntoConstraints = false
        memberSinceLabel.font = .systemFont(ofSize: 14, weight: .regular)
        memberSinceLabel.textColor = .secondaryLabel
        memberSinceLabel.textAlignment = .center
        memberSinceLabel.text = " "
        view.addSubview(memberSinceLabel)

        // Listings header
        listingsHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        listingsHeaderLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        listingsHeaderLabel.text = "Listings"
        view.addSubview(listingsHeaderLabel)

        // Status label (blocked / info)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 15, weight: .regular)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.isHidden = true
        view.addSubview(statusLabel)

        // Empty state
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.font = .systemFont(ofSize: 15, weight: .regular)
        emptyStateLabel.textColor = .secondaryLabel
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.text = "This user has no active listings right now."
        emptyStateLabel.isHidden = true
        view.addSubview(emptyStateLabel)

        // Listings table
        listingsTableView.translatesAutoresizingMaskIntoConstraints = false
        listingsTableView.backgroundColor = .clear
        listingsTableView.separatorStyle = .none
        listingsTableView.rowHeight = UITableView.automaticDimension
        listingsTableView.estimatedRowHeight = 72
        listingsTableView.dataSource = self
        listingsTableView.delegate = self
        listingsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "ListingCell")
        view.addSubview(listingsTableView)

        NSLayoutConstraint.activate([
            avatarImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            avatarImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 88),
            avatarImageView.heightAnchor.constraint(equalToConstant: 88),

            nameLabel.topAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            memberSinceLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            memberSinceLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            memberSinceLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            listingsHeaderLabel.topAnchor.constraint(equalTo: memberSinceLabel.bottomAnchor, constant: 32),
            listingsHeaderLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            statusLabel.topAnchor.constraint(equalTo: listingsHeaderLabel.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            emptyStateLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            listingsTableView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            listingsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listingsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listingsTableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        // Render initials into avatar
        let initials = makeInitials(from: displayName ?? "U")
        avatarImageView.image = drawInitialsImage(initials: initials, size: CGSize(width: 88, height: 88))
    }

    // MARK: - Data Loading

    private func loadProfile() {
        guard !userId.isEmpty else { return }

        if safetyService.isBlocked(userId) {
            statusLabel.text = "You have blocked this user."
            statusLabel.isHidden = false
            listingsHeaderLabel.isHidden = true
            emptyStateLabel.isHidden = true
            listingsTableView.isHidden = true
            return
        }

        // Fetch display name if not provided
        Task { [weak self] in
            guard let self else { return }

            struct ProfileDTO: Decodable {
                let full_name: String?
                let created_at: String?
            }

            do {
                let response = try await SupabaseManager.shared.client
                    .from("user_profiles")
                    .select("full_name, created_at")
                    .eq("id", value: userId)
                    .single()
                    .execute()

                let dto = try JSONDecoder().decode(ProfileDTO.self, from: response.data)
                await MainActor.run {
                    if let name = dto.full_name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.nameLabel.text = name
                        self.displayName = name
                        let initials = self.makeInitials(from: name)
                        self.avatarImageView.image = self.drawInitialsImage(initials: initials, size: CGSize(width: 88, height: 88))
                    }

                    if let createdStr = dto.created_at {
                        let isoFormatter = ISO8601DateFormatter()
                        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        if let date = isoFormatter.date(from: createdStr) {
                            let displayFormatter = DateFormatter()
                            displayFormatter.dateStyle = .medium
                            displayFormatter.timeStyle = .none
                            self.memberSinceLabel.text = "Member since \(displayFormatter.string(from: date))"
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.statusLabel.text = "Unable to load profile."
                    self.statusLabel.isHidden = false
                }
            }
        }
    }

    private func loadListings() {
        guard !userId.isEmpty, !safetyService.isBlocked(userId) else { return }

        Task { [weak self] in
            guard let self else { return }

            do {
                let response = try await SupabaseManager.shared.client
                    .from("items")
                    .select()
                    .eq("owner_id", value: userId)
                    .eq("is_active", value: true)
                    .order("created_at", ascending: false)
                    .limit(20)
                    .execute()

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let fetched = try decoder.decode([Item].self, from: response.data)

                await MainActor.run {
                    self.listings = fetched
                    self.refreshListingsUI()
                }
            } catch {
                await MainActor.run {
                    self.listings = []
                    if self.statusLabel.isHidden {
                        self.statusLabel.text = "We couldn't load this user's listings right now."
                        self.statusLabel.isHidden = false
                    }
                    self.refreshListingsUI()
                }
            }
        }
    }

    private func refreshListingsUI() {
        guard !safetyService.isBlocked(userId) else { return }

        listingsHeaderLabel.isHidden = false
        listingsHeaderLabel.text = listings.isEmpty ? "Listings" : "Listings (\(listings.count))"
        emptyStateLabel.isHidden = !listings.isEmpty
        listingsTableView.isHidden = listings.isEmpty
        listingsTableView.reloadData()
    }

    // MARK: - Safety Menu (Guideline 1.2)

    @objc private func didTapSafetyMenu(_ sender: UIBarButtonItem) {
        guard !userId.isEmpty else { return }
        guard ensureSignedInForSafetyTools() else { return }

        let actionSheet = UIAlertController(title: "Safety Tools", message: nil, preferredStyle: .actionSheet)

        actionSheet.addAction(UIAlertAction(title: "Report User", style: .default) { [weak self] _ in
            self?.presentReportReasons(anchor: sender)
        })

        let isBlocked = safetyService.isBlocked(userId)
        let blockTitle = isBlocked ? "Unblock User" : "Block User"
        actionSheet.addAction(UIAlertAction(title: blockTitle, style: .destructive) { [weak self] _ in
            guard let self else { return }
            if isBlocked {
                self.safetyService.unblock(userId: self.userId)
                self.presentInfo("User Unblocked", message: "Their content will be visible again.")
                self.statusLabel.isHidden = true
                self.listingsHeaderLabel.isHidden = false
            } else {
                self.confirmBlockUser()
            }
        })

        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = actionSheet.popoverPresentationController {
            popover.barButtonItem = sender
        }
        present(actionSheet, animated: true)
    }

    private func ensureSignedInForSafetyTools() -> Bool {
        if SupabaseManager.shared.currentUserIdSync() != nil {
            return true
        }

        let alert = UIAlertController(
            title: "Sign in required",
            message: "Please sign in to report or block users.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Sign In", style: .default) { [weak self] _ in
            self?.openSignIn()
        })
        present(alert, animated: true)
        return false
    }

    private func openSignIn() {
        let nibName = "SignViewController"
        let signInVC: SignViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
            Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            signInVC = SignViewController(nibName: nibName, bundle: nil)
        } else {
            signInVC = SignViewController(service: SignInService())
        }
        signInVC.title = ""
        signInVC.hidesBottomBarWhenPushed = true

        if let nav = navigationController {
            nav.pushViewController(signInVC, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: signInVC)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }

    private func presentReportReasons(anchor: UIBarButtonItem) {
        let reasons = ["Harassment", "Scam or fraud", "Unsafe behavior", "Spam", "Other"]
        let actionSheet = UIAlertController(title: "Report User", message: "Why are you reporting this user?", preferredStyle: .actionSheet)
        for reason in reasons {
            actionSheet.addAction(UIAlertAction(title: reason, style: .default) { [weak self] _ in
                self?.presentReportDetails(reason: reason)
            })
        }
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = actionSheet.popoverPresentationController {
            popover.barButtonItem = anchor
        }
        present(actionSheet, animated: true)
    }

    private func presentReportDetails(reason: String) {
        let alert = UIAlertController(title: "Report User", message: "Add any details that will help our review team.", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Optional details"; $0.clearButtonMode = .whileEditing }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Submit", style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            let details = alert?.textFields?.first?.text
            Task {
                do {
                    try await self.safetyService.reportUser(
                        userId: self.userId,
                        displayName: self.displayName,
                        context: "User profile view",
                        reason: reason,
                        details: details
                    )
                    await MainActor.run {
                        self.presentInfo("Report Sent", message: "Thanks. Our team will review this account.")
                    }
                } catch {
                    await MainActor.run {
                        self.presentInfo("Error", message: error.localizedDescription)
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    private func confirmBlockUser() {
        let name = displayName ?? "this user"
        let alert = UIAlertController(
            title: "Block \(name)?",
            message: "Their listings and chat will be hidden immediately.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Block", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.safetyService.block(userId: self.userId, displayName: self.displayName ?? "User")
            self.statusLabel.text = "You have blocked this user."
            self.statusLabel.isHidden = false
            self.listingsHeaderLabel.isHidden = true
            self.presentInfo("User Blocked", message: "Their content is now hidden from your account.")
        })
        present(alert, animated: true)
    }

    private func presentInfo(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Listings Table

    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        listings.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ListingCell", for: indexPath)
        guard indexPath.row < listings.count else { return cell }

        let item = listings[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = item.title

        let category = item.category?.trimmingCharacters(in: .whitespacesAndNewlines)
        let price = currencyFormatter.string(from: NSNumber(value: item.price_per_day)) ?? "₹\(item.price_per_day)"
        content.secondaryText = ((category?.isEmpty == false) ? "\(category!) • " : "") + "\(price)/day"
        content.secondaryTextProperties.color = .secondaryLabel

        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        cell.backgroundColor = .clear
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < listings.count else { return }

        let item = listings[indexPath.row]
        let vc = ProductViewController(nibName: "ProductViewController", bundle: nil)
        vc.configure(with: item)
        vc.hidesBottomBarWhenPushed = true

        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .formSheet
            present(nav, animated: true)
        }
    }

    // MARK: - Helpers

    private func makeInitials(from name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)).uppercased() }.joined()
    }

    private func drawInitialsImage(initials: String, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size.width * 0.38, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let str = initials as NSString
            let textSize = str.size(withAttributes: attrs)
            let origin = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            str.draw(at: origin, withAttributes: attrs)
        }
    }

    // MARK: - Static convenience opener

    /// Opens a user profile from any presenting view controller.
    static func open(from presenter: UIViewController, userId: String, displayName: String? = nil) {
        let vc = UserProfileViewController()
        vc.userId = userId
        vc.displayName = displayName
        vc.hidesBottomBarWhenPushed = true

        if let nav = presenter.navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .formSheet
            presenter.present(nav, animated: true)
        }
    }
}
