//
//  CollegeVerifiedDetailViewController.swift
//  RentiWise
//
//  Simple read-only screen showing college verification details.
//

import UIKit
import Supabase

final class CollegeVerifiedDetailViewController: UIViewController {

    // MARK: - Colors
    private let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
    private let bgColor = UIColor(red: 0xF8/255.0, green: 0xF8/255.0, blue: 0xF6/255.0, alpha: 1.0)
    private let bodyColor = UIColor(red: 0x1A/255.0, green: 0x1A/255.0, blue: 0x1A/255.0, alpha: 1.0)
    private let captionColor = UIColor(red: 0x6B/255.0, green: 0x6B/255.0, blue: 0x6B/255.0, alpha: 1.0)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "College Verified"
        view.backgroundColor = bgColor
        navigationController?.navigationBar.tintColor = brandTeal
        buildUI()
    }

    private func buildUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])

        // Icon
        let icon = UILabel()
        icon.text = "🎓"
        icon.font = .systemFont(ofSize: 64)
        icon.textAlignment = .center
        stack.addArrangedSubview(icon)

        // Title
        let title = UILabel()
        title.text = "College Verified"
        title.font = .systemFont(ofSize: 22, weight: .bold)
        title.textColor = brandTeal
        title.textAlignment = .center
        stack.addArrangedSubview(title)

        // Card
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowRadius = 8
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = 16
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])

        let emailLabel = UILabel()
        emailLabel.text = "Verified email:\nLoading..."
        emailLabel.font = .systemFont(ofSize: 16)
        emailLabel.textColor = bodyColor
        emailLabel.numberOfLines = 0
        cardStack.addArrangedSubview(emailLabel)

        let dateLabel = UILabel()
        dateLabel.text = "Verified on:\nLoading..."
        dateLabel.font = .systemFont(ofSize: 16)
        dateLabel.textColor = bodyColor
        dateLabel.numberOfLines = 0
        cardStack.addArrangedSubview(dateLabel)

        // Caption
        let caption = UILabel()
        caption.text = "This verification adds +25 points to your Trust Score."
        caption.font = .systemFont(ofSize: 15)
        caption.textColor = captionColor
        caption.textAlignment = .center
        caption.numberOfLines = 0
        stack.addArrangedSubview(caption)

        // Fetch data
        Task {
            guard let userId = await SupabaseManager.shared.currentUserId() else { return }
            struct ColRow: Decodable {
                let college_email: String?
                let college_verified_at: String?
            }
            do {
                let resp = try await SupabaseManager.shared.client
                    .from("users")
                    .select("college_email, college_verified_at")
                    .eq("id", value: userId)
                    .single()
                    .execute()
                let row = try JSONDecoder().decode(ColRow.self, from: resp.data)
                await MainActor.run {
                    emailLabel.text = "Verified email:\n\(row.college_email ?? "—")"
                    if let ts = row.college_verified_at, let date = ISO8601DateFormatter().date(from: ts) {
                        let f = DateFormatter()
                        f.dateFormat = "dd MMM yyyy, h:mm a"
                        dateLabel.text = "Verified on:\n\(f.string(from: date))"
                    } else {
                        dateLabel.text = "Verified on:\n—"
                    }
                }
            } catch { /* show defaults */ }
        }
    }
}
