//
//  AgreementViewerViewController.swift
//  RentiWise
//
//  Read-only post-signing agreement viewer, accessible from rental history.
//

import UIKit
import Supabase

final class AgreementViewerViewController: UIViewController {

    // MARK: - Inputs
    var agreementId: String = ""

    // MARK: - Colors
    private let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
    private let bgColor = UIColor(red: 0xF8/255.0, green: 0xF8/255.0, blue: 0xF6/255.0, alpha: 1.0)
    private let bodyColor = UIColor(red: 0x1A/255.0, green: 0x1A/255.0, blue: 0x1A/255.0, alpha: 1.0)
    private let captionColor = UIColor(red: 0x6B/255.0, green: 0x6B/255.0, blue: 0x6B/255.0, alpha: 1.0)

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let loadingSpinner = UIActivityIndicatorView(style: .large)
    private var agreementText: String = ""

    private struct FullAgreement: Decodable {
        let id: String
        let item_name: String
        let start_date: String
        let end_date: String
        let duration_days: Int
        let agreed_price_per_day: Double
        let total_rental_price: Double
        let deposit_amount: Double
        let borrower_agreed_at: String?
        let lender_agreed_at: String?
        let lender_id: String?
        let borrower_id: String?
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Signed Agreement"
        view.backgroundColor = bgColor
        navigationController?.navigationBar.tintColor = brandTeal

        // Share button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(shareTapped)
        )

        loadingSpinner.color = brandTeal
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingSpinner)
        NSLayoutConstraint.activate([
            loadingSpinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        loadingSpinner.startAnimating()

        fetchAndDisplay()
    }

    private func fetchAndDisplay() {
        Task {
            do {
                let resp = try await SupabaseManager.shared.client
                    .from("rental_agreements")
                    .select("*")
                    .eq("id", value: agreementId)
                    .single()
                    .execute()

                let data = try JSONDecoder().decode(FullAgreement.self, from: resp.data)

                // Fetch names
                struct UserName: Decodable { let full_name: String? }
                var lenderName = "Lender"
                var borrowerName = "Borrower"
                if let lid = data.lender_id {
                    let r = try await SupabaseManager.shared.client.from("users").select("full_name").eq("id", value: lid).single().execute()
                    lenderName = (try? JSONDecoder().decode(UserName.self, from: r.data))?.full_name ?? "Lender"
                }
                if let bid = data.borrower_id {
                    let r = try await SupabaseManager.shared.client.from("users").select("full_name").eq("id", value: bid).single().execute()
                    borrowerName = (try? JSONDecoder().decode(UserName.self, from: r.data))?.full_name ?? "Borrower"
                }

                // Build plain text for sharing
                agreementText = """
                RentiWise Rental Agreement
                ──────────────────────────
                Item: \(data.item_name)
                Period: \(data.start_date) to \(data.end_date)
                Duration: \(data.duration_days) days
                Daily Rate: ₹\(String(format: "%.0f", data.agreed_price_per_day))
                Total: ₹\(String(format: "%.0f", data.total_rental_price))
                Deposit: ₹\(String(format: "%.0f", data.deposit_amount))
                ──────────────────────────
                Lender: \(lenderName)
                Borrower: \(borrowerName)
                ──────────────────────────
                Borrower signed: \(data.borrower_agreed_at ?? "—")
                Lender signed: \(data.lender_agreed_at ?? "—")
                Agreement ID: \(String(data.id.prefix(8)))
                """

                await MainActor.run {
                    self.loadingSpinner.stopAnimating()
                    self.loadingSpinner.removeFromSuperview()
                    self.buildUI(data: data, lenderName: lenderName, borrowerName: borrowerName)
                }
            } catch {
                await MainActor.run {
                    self.loadingSpinner.stopAnimating()
                    let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                        self.navigationController?.popViewController(animated: true)
                    })
                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func buildUI(data: FullAgreement, lenderName: String, borrowerName: String) {
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

        // Details card
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "📄 SIGNED RENTAL AGREEMENT"
        title.font = .systemFont(ofSize: 15, weight: .bold)
        title.textColor = bodyColor
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(makeSeparator())

        stack.addArrangedSubview(makeRow("Item", value: data.item_name))
        stack.addArrangedSubview(makeRow("From", value: data.start_date))
        stack.addArrangedSubview(makeRow("To", value: data.end_date))
        stack.addArrangedSubview(makeRow("Duration", value: "\(data.duration_days) day\(data.duration_days == 1 ? "" : "s")"))
        stack.addArrangedSubview(makeRow("Daily Rate", value: String(format: "₹%.0f/day", data.agreed_price_per_day)))
        stack.addArrangedSubview(makeRow("Total", value: String(format: "₹%.0f", data.total_rental_price)))
        stack.addArrangedSubview(makeRow("Deposit", value: String(format: "₹%.0f", data.deposit_amount)))
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(makeRow("Lender", value: lenderName))
        stack.addArrangedSubview(makeRow("Borrower", value: borrowerName))

        card.addSubview(stack)
        pinToCard(stack, in: card)
        contentStack.addArrangedSubview(card)

        // Signatures card
        let sigCard = makeCard()
        let sigStack = UIStackView()
        sigStack.axis = .vertical
        sigStack.spacing = 12
        sigStack.translatesAutoresizingMaskIntoConstraints = false

        let sigTitle = UILabel()
        sigTitle.text = "✅ Signatures"
        sigTitle.font = .systemFont(ofSize: 15, weight: .bold)
        sigTitle.textColor = brandTeal
        sigStack.addArrangedSubview(sigTitle)

        let borrowerSig = UILabel()
        borrowerSig.text = "Borrower signed: \(formatTimestamp(data.borrower_agreed_at))"
        borrowerSig.font = .systemFont(ofSize: 14)
        borrowerSig.textColor = bodyColor
        sigStack.addArrangedSubview(borrowerSig)

        let lenderSig = UILabel()
        lenderSig.text = "Lender signed: \(formatTimestamp(data.lender_agreed_at))"
        lenderSig.font = .systemFont(ofSize: 14)
        lenderSig.textColor = bodyColor
        sigStack.addArrangedSubview(lenderSig)

        let agreementIdLabel = UILabel()
        agreementIdLabel.text = "Agreement ID: \(String(data.id.prefix(8)))"
        agreementIdLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        agreementIdLabel.textColor = captionColor
        sigStack.addArrangedSubview(agreementIdLabel)

        sigCard.addSubview(sigStack)
        pinToCard(sigStack, in: sigCard)
        contentStack.addArrangedSubview(sigCard)
    }

    @objc private func shareTapped() {
        let activityVC = UIActivityViewController(activityItems: [agreementText], applicationActivities: nil)
        present(activityVC, animated: true)
    }

    private func formatTimestamp(_ ts: String?) -> String {
        guard let ts, let date = ISO8601DateFormatter().date(from: ts) else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy, HH:mm"
        return f.string(from: date)
    }

    // MARK: - Helpers
    private func makeCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowRadius = 8
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }

    private func pinToCard(_ stack: UIStackView, in card: UIView) {
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
    }

    private func makeRow(_ title: String, value: String) -> UIStackView {
        let t = UILabel()
        t.text = title
        t.font = .systemFont(ofSize: 14)
        t.textColor = captionColor
        let v = UILabel()
        v.text = value
        v.font = .systemFont(ofSize: 14, weight: .medium)
        v.textColor = bodyColor
        v.textAlignment = .right
        let row = UIStackView(arrangedSubviews: [t, v])
        row.axis = .horizontal
        row.distribution = .fill
        return row
    }

    private func makeSeparator() -> UIView {
        let sep = UIView()
        sep.backgroundColor = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale).isActive = true
        return sep
    }
}
