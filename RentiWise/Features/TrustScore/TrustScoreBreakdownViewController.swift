//
//  TrustScoreBreakdownViewController.swift
//  RentiWise
//
//  Shows a detailed breakdown of the user's trust score with progress bar,
//  scoring components, and "Improve your score" CTAs.
//

import UIKit
import Supabase

final class TrustScoreBreakdownViewController: UIViewController {

    // MARK: - Input
    var userId: String = ""

    // MARK: - UI
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let brandTeal = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)

    // Score data
    private var trustScore: Int = 0
    private var badgeTier: String = "newcomer"
    private var hasPhone: Bool = false
    private var isCollegeVerified: Bool = false
    private var hasProfilePhoto: Bool = false
    private var avgRating: Double = 0
    private var completedRentals: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Trust Score"
        view.backgroundColor = .systemBackground
        setupUI()
        Task { await fetchScoreData() }
    }

    // MARK: - UI Setup
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -48),
        ])

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = brandTeal
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        spinner.startAnimating()
    }

    // MARK: - Fetch Data
    private func fetchScoreData() async {
        if userId.isEmpty {
            userId = await SupabaseManager.shared.currentUserId() ?? ""
        }
        guard !userId.isEmpty else {
            await MainActor.run { spinner.stopAnimating() }
            return
        }

        do {
            struct UserScoreRow: Decodable {
                let trust_score: Int?
                let badge_tier: String?
                let phone: String?
                let is_college_verified: Bool?
                let profile_image_url: String?
            }

            let resp = try await SupabaseManager.shared.client
                .from("users")
                .select("trust_score, badge_tier, phone, is_college_verified, profile_image_url")
                .eq("id", value: userId)
                .single()
                .execute()

            let row = try JSONDecoder().decode(UserScoreRow.self, from: resp.data)
            trustScore = row.trust_score ?? 0
            badgeTier = row.badge_tier ?? "newcomer"
            hasPhone = !(row.phone ?? "").isEmpty
            isCollegeVerified = row.is_college_verified ?? false
            hasProfilePhoto = !(row.profile_image_url ?? "").isEmpty

            // Fetch avg rating
            let itemsResp = try await SupabaseManager.shared.client
                .from("items")
                .select("id")
                .eq("owner_id", value: userId)
                .execute()
            struct ItemIdRow: Decodable { let id: String }
            let items = try JSONDecoder().decode([ItemIdRow].self, from: itemsResp.data)

            if !items.isEmpty {
                let itemIds = items.map { $0.id }
                let reviewsResp = try await SupabaseManager.shared.client
                    .from("reviews")
                    .select("rating")
                    .in("item_id", values: itemIds)
                    .execute()
                struct RatingRow: Decodable { let rating: Int }
                let ratings = try JSONDecoder().decode([RatingRow].self, from: reviewsResp.data)
                if !ratings.isEmpty {
                    let sum = ratings.reduce(0) { $0 + $1.rating }
                    avgRating = Double(sum) / Double(ratings.count)
                }
            }

            // Fetch completed rentals count
            let lenderResp = try await SupabaseManager.shared.client
                .from("requests")
                .select("id", head: true, count: .exact)
                .eq("owner_id", value: userId)
                .eq("status", value: "completed")
                .execute()
            let borrowerResp = try await SupabaseManager.shared.client
                .from("requests")
                .select("id", head: true, count: .exact)
                .eq("borrower_id", value: userId)
                .eq("status", value: "completed")
                .execute()
            completedRentals = (lenderResp.count ?? 0) + (borrowerResp.count ?? 0)

        } catch {
            debugLog("[TrustScore] Error fetching data: \(error)")
        }

        await MainActor.run {
            spinner.stopAnimating()
            buildBreakdownUI()
        }
    }

    // MARK: - Build Breakdown UI
    private func buildBreakdownUI() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // --- Badge + Score Header ---
        let headerStack = UIStackView()
        headerStack.axis = .vertical
        headerStack.alignment = .center
        headerStack.spacing = 12

        let badge = TrustBadgeView()
        badge.badgeTier = badgeTier
        badge.trustScore = trustScore
        badge.translatesAutoresizingMaskIntoConstraints = false
        headerStack.addArrangedSubview(badge)

        // Progress bar
        let progressContainer = UIView()
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.heightAnchor.constraint(equalToConstant: 10).isActive = true

        let trackView = UIView()
        trackView.backgroundColor = .systemGray5
        trackView.layer.cornerRadius = 5
        trackView.translatesAutoresizingMaskIntoConstraints = false

        let fillView = UIView()
        let tier = TrustTier(rawValue: badgeTier) ?? .newcomer
        fillView.backgroundColor = tier.backgroundColor
        fillView.layer.cornerRadius = 5
        fillView.translatesAutoresizingMaskIntoConstraints = false

        progressContainer.addSubview(trackView)
        progressContainer.addSubview(fillView)

        NSLayoutConstraint.activate([
            trackView.topAnchor.constraint(equalTo: progressContainer.topAnchor),
            trackView.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor),
            trackView.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            trackView.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),

            fillView.topAnchor.constraint(equalTo: progressContainer.topAnchor),
            fillView.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor),
            fillView.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            fillView.widthAnchor.constraint(equalTo: progressContainer.widthAnchor, multiplier: CGFloat(min(trustScore, 100)) / 100.0),
        ])

        headerStack.addArrangedSubview(progressContainer)
        progressContainer.widthAnchor.constraint(equalTo: headerStack.widthAnchor, multiplier: 0.8).isActive = true

        let scoreLabel = UILabel()
        scoreLabel.text = "\(trustScore) / 100"
        scoreLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        scoreLabel.textColor = .secondaryLabel
        scoreLabel.textAlignment = .center
        headerStack.addArrangedSubview(scoreLabel)

        contentStack.addArrangedSubview(headerStack)

        // --- Scoring Components ---
        let componentsCard = makeCard()
        let componentsStack = UIStackView()
        componentsStack.axis = .vertical
        componentsStack.spacing = 16
        componentsStack.translatesAutoresizingMaskIntoConstraints = false

        let phonePoints = hasPhone ? 30 : 0
        componentsStack.addArrangedSubview(makeScoreRow(
            icon: "📱", title: "Phone Verified",
            earned: phonePoints, total: 30, isComplete: hasPhone
        ))

        let collegePoints = isCollegeVerified ? 25 : 0
        componentsStack.addArrangedSubview(makeScoreRow(
            icon: "🎓", title: "College Email",
            earned: collegePoints, total: 25, isComplete: isCollegeVerified
        ))

        let photoPoints = hasProfilePhoto ? 10 : 0
        componentsStack.addArrangedSubview(makeScoreRow(
            icon: "📷", title: "Profile Photo",
            earned: photoPoints, total: 10, isComplete: hasProfilePhoto
        ))

        let ratingPoints = min(35, Int(round(avgRating * 7)))
        componentsStack.addArrangedSubview(makeScoreRow(
            icon: "⭐", title: "Avg Rating (\(String(format: "%.1f", avgRating)))",
            earned: ratingPoints, total: 35, isComplete: avgRating >= 4.0
        ))

        let rentalPoints = min(20, completedRentals)
        componentsStack.addArrangedSubview(makeScoreRow(
            icon: "🤝", title: "Completed Rentals (\(completedRentals))",
            earned: rentalPoints, total: 20, isComplete: completedRentals >= 20
        ))

        componentsCard.addSubview(componentsStack)
        NSLayoutConstraint.activate([
            componentsStack.topAnchor.constraint(equalTo: componentsCard.topAnchor, constant: 16),
            componentsStack.leadingAnchor.constraint(equalTo: componentsCard.leadingAnchor, constant: 16),
            componentsStack.trailingAnchor.constraint(equalTo: componentsCard.trailingAnchor, constant: -16),
            componentsStack.bottomAnchor.constraint(equalTo: componentsCard.bottomAnchor, constant: -16),
        ])
        contentStack.addArrangedSubview(componentsCard)

        // --- Improve CTA ---
        let improveButton = UIButton(type: .system)
        improveButton.setTitle("Improve Your Score", for: .normal)
        improveButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        improveButton.backgroundColor = brandTeal
        improveButton.setTitleColor(.white, for: .normal)
        improveButton.layer.cornerRadius = 14
        improveButton.translatesAutoresizingMaskIntoConstraints = false
        improveButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        improveButton.addTarget(self, action: #selector(improveTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(improveButton)
    }

    @objc private func improveTapped() {
        // Navigate to Edit Profile
        if let nav = navigationController {
            nav.popViewController(animated: true)
        }
    }

    // MARK: - Helpers

    private func makeCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }

    private func makeScoreRow(icon: String, title: String, earned: Int, total: Int, isComplete: Bool) -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center

        let iconLabel = UILabel()
        iconLabel.text = icon
        iconLabel.font = .systemFont(ofSize: 20)
        iconLabel.widthAnchor.constraint(equalToConstant: 28).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15)
        titleLabel.textColor = .label

        let pointsLabel = UILabel()
        pointsLabel.text = "+\(earned)/\(total)"
        pointsLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        pointsLabel.textColor = isComplete ? .systemGreen : .secondaryLabel
        pointsLabel.textAlignment = .right
        pointsLabel.setContentHuggingPriority(.required, for: .horizontal)

        let statusLabel = UILabel()
        statusLabel.text = isComplete ? "✓" : "○"
        statusLabel.font = .systemFont(ofSize: 16)
        statusLabel.textColor = isComplete ? .systemGreen : .systemGray
        statusLabel.widthAnchor.constraint(equalToConstant: 20).isActive = true

        stack.addArrangedSubview(iconLabel)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(pointsLabel)
        stack.addArrangedSubview(statusLabel)

        return stack
    }
}
