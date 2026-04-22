//
//  LenderAgreementViewController.swift
//  RentiWise
//
//  Lender-facing agreement screen. Fetches the existing agreement row,
//  displays pre-filled fields, and lets the lender sign.
//

import UIKit
import Supabase

final class LenderAgreementViewController: UIViewController {

    // MARK: - Inputs
    var agreementId: String = ""
    var requestId: String = ""

    // MARK: - Colors
    private let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
    private let bgColor = UIColor(red: 0xF8/255.0, green: 0xF8/255.0, blue: 0xF6/255.0, alpha: 1.0)
    private let bodyColor = UIColor(red: 0x1A/255.0, green: 0x1A/255.0, blue: 0x1A/255.0, alpha: 1.0)
    private let captionColor = UIColor(red: 0x6B/255.0, green: 0x6B/255.0, blue: 0x6B/255.0, alpha: 1.0)

    // MARK: - UI
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let agreeCheckbox = UIButton(type: .system)
    private let agreeButton = UIButton(type: .system)
    private var isChecked = false
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let loadingSpinner = UIActivityIndicatorView(style: .large)

    // MARK: - Agreement Data
    private struct AgreementData: Decodable {
        let id: String
        let item_name: String
        let start_date: String
        let end_date: String
        let duration_days: Int
        let agreed_price_per_day: Double
        let total_rental_price: Double
        let deposit_amount: Double
        let borrower_agreed_at: String?
        let lender_id: String?
        let borrower_id: String?
    }

    private var agreementData: AgreementData?
    private var lenderName: String = ""
    private var borrowerName: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Review & Sign Agreement"
        view.backgroundColor = bgColor
        navigationController?.navigationBar.tintColor = brandTeal

        // Show loading
        loadingSpinner.color = brandTeal
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingSpinner)
        NSLayoutConstraint.activate([
            loadingSpinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        loadingSpinner.startAnimating()

        fetchAgreement()
    }

    // MARK: - Fetch Agreement
    private func fetchAgreement() {
        Task {
            do {
                let resp = try await SupabaseManager.shared.client
                    .from("rental_agreements")
                    .select("*")
                    .eq("id", value: agreementId)
                    .single()
                    .execute()

                let data = try JSONDecoder().decode(AgreementData.self, from: resp.data)
                guard data.borrower_agreed_at != nil else {
                    await MainActor.run {
                        let alert = UIAlertController(title: "Not Ready", message: "Borrower hasn't signed yet.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                            self.navigationController?.popViewController(animated: true)
                        })
                        self.present(alert, animated: true)
                    }
                    return
                }

                self.agreementData = data

                // Fetch names
                struct UserName: Decodable { let full_name: String? }
                if let lid = data.lender_id {
                    let r = try await SupabaseManager.shared.client.from("user_profiles").select("full_name").eq("id", value: lid).single().execute()
                    let n = try? JSONDecoder().decode(UserName.self, from: r.data)
                    lenderName = n?.full_name ?? "Lender"
                }
                if let bid = data.borrower_id {
                    let r = try await SupabaseManager.shared.client.from("user_profiles").select("full_name").eq("id", value: bid).single().execute()
                    let n = try? JSONDecoder().decode(UserName.self, from: r.data)
                    borrowerName = n?.full_name ?? "Borrower"
                }

                await MainActor.run {
                    self.loadingSpinner.stopAnimating()
                    self.loadingSpinner.removeFromSuperview()
                    self.buildUI()
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

    // MARK: - Build UI
    private func buildUI() {
        guard let data = agreementData else { return }

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
        let detailsCard = makeCard()
        let detailsStack = UIStackView()
        detailsStack.axis = .vertical
        detailsStack.spacing = 12
        detailsStack.translatesAutoresizingMaskIntoConstraints = false

        let cardTitle = UILabel()
        cardTitle.text = "📄 RENTAL AGREEMENT"
        cardTitle.font = .systemFont(ofSize: 15, weight: .bold)
        cardTitle.textColor = bodyColor
        detailsStack.addArrangedSubview(cardTitle)
        detailsStack.addArrangedSubview(makeSeparator())

        detailsStack.addArrangedSubview(makeRow("Item", value: data.item_name))
        detailsStack.addArrangedSubview(makeRow("From", value: data.start_date))
        detailsStack.addArrangedSubview(makeRow("To", value: data.end_date))
        detailsStack.addArrangedSubview(makeRow("Duration", value: "\(data.duration_days) day\(data.duration_days == 1 ? "" : "s")"))
        detailsStack.addArrangedSubview(makeRow("Daily Rate", value: String(format: "₹%.0f/day", data.agreed_price_per_day)))
        detailsStack.addArrangedSubview(makeRow("Total", value: String(format: "₹%.0f", data.total_rental_price)))
        detailsStack.addArrangedSubview(makeRow("Deposit", value: String(format: "₹%.0f (direct)", data.deposit_amount)))
        detailsStack.addArrangedSubview(makeSeparator())
        detailsStack.addArrangedSubview(makeRow("Lender", value: lenderName))
        detailsStack.addArrangedSubview(makeRow("Borrower", value: borrowerName))

        detailsCard.addSubview(detailsStack)
        pinToCard(detailsStack, in: detailsCard)
        contentStack.addArrangedSubview(detailsCard)

        // Terms card (same as borrower)
        let termsCard = makeCard()
        let termsStack = UIStackView()
        termsStack.axis = .vertical
        termsStack.spacing = 10
        termsStack.translatesAutoresizingMaskIntoConstraints = false

        let termsTitle = UILabel()
        termsTitle.text = "Terms & Conditions"
        termsTitle.font = .systemFont(ofSize: 15, weight: .bold)
        termsTitle.textColor = bodyColor
        termsStack.addArrangedSubview(termsTitle)

        let terms = [
            "1. The borrower agrees to return the item in the same condition.",
            "2. The deposit is paid directly to the lender and refundable on safe return.",
            "3. Rentiwise is a facilitation platform and is not responsible for disputes.",
            "4. Both parties agree to resolve disputes directly.",
            "5. Late returns may incur additional charges.",
            "6. Both parties confirm the rental details above are accurate."
        ]
        for term in terms {
            let lbl = UILabel()
            lbl.text = term
            lbl.font = .systemFont(ofSize: 14)
            lbl.textColor = bodyColor
            lbl.numberOfLines = 0
            termsStack.addArrangedSubview(lbl)
        }

        termsCard.addSubview(termsStack)
        pinToCard(termsStack, in: termsCard)
        contentStack.addArrangedSubview(termsCard)

        // Borrower signed badge
        let signedBadge = UILabel()
        signedBadge.text = "Borrower (\(borrowerName)) has signed"
        signedBadge.font = .systemFont(ofSize: 14, weight: .medium)
        signedBadge.textColor = brandTeal
        signedBadge.textAlignment = .center
        contentStack.addArrangedSubview(signedBadge)

        // Checkbox
        let checkRow = UIStackView()
        checkRow.axis = .horizontal
        checkRow.spacing = 12
        checkRow.alignment = .center

        agreeCheckbox.setImage(UIImage(systemName: "square"), for: .normal)
        agreeCheckbox.tintColor = .systemGray3
        agreeCheckbox.addTarget(self, action: #selector(checkboxTapped), for: .touchUpInside)
        agreeCheckbox.translatesAutoresizingMaskIntoConstraints = false
        agreeCheckbox.widthAnchor.constraint(equalToConstant: 28).isActive = true
        agreeCheckbox.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let checkLabel = UILabel()
        checkLabel.text = "I have read and agree to these terms"
        checkLabel.font = .systemFont(ofSize: 15)
        checkLabel.textColor = bodyColor
        checkLabel.numberOfLines = 0

        checkRow.addArrangedSubview(agreeCheckbox)
        checkRow.addArrangedSubview(checkLabel)
        contentStack.addArrangedSubview(checkRow)

        // Agree button
        agreeButton.setTitle("I Agree & Hand Over Item", for: .normal)
        agreeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        agreeButton.backgroundColor = UIColor.systemGray4
        agreeButton.setTitleColor(.white, for: .normal)
        agreeButton.layer.cornerRadius = 12
        agreeButton.isEnabled = false
        agreeButton.translatesAutoresizingMaskIntoConstraints = false
        agreeButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        agreeButton.addTarget(self, action: #selector(agreeTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(agreeButton)

        spinner.hidesWhenStopped = true
        spinner.color = brandTeal
        contentStack.addArrangedSubview(spinner)

        let caption = UILabel()
        caption.text = "Signing as: \(lenderName)"
        caption.font = .preferredFont(forTextStyle: .caption1)
        caption.textColor = captionColor
        caption.textAlignment = .center
        contentStack.addArrangedSubview(caption)
    }

    // MARK: - Actions
    @objc private func checkboxTapped() {
        isChecked.toggle()
        agreeCheckbox.setImage(UIImage(systemName: isChecked ? "checkmark.square.fill" : "square"), for: .normal)
        agreeCheckbox.tintColor = isChecked ? brandTeal : .systemGray3
        agreeButton.isEnabled = isChecked
        agreeButton.backgroundColor = isChecked ? brandTeal : .systemGray4
    }

    @objc private func agreeTapped() {
        guard isChecked else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        agreeButton.isEnabled = false
        spinner.startAnimating()

        Task {
            do {
                let now = ISO8601DateFormatter().string(from: Date())

                struct LenderSign: Encodable { let lender_agreed_at: String }
                try await SupabaseManager.shared.client
                    .from("rental_agreements")
                    .update(LenderSign(lender_agreed_at: now))
                    .eq("id", value: agreementId)
                    .execute()

                struct RequestSign: Encodable { let lender_agreed_at: String }
                try await SupabaseManager.shared.client
                    .from("requests")
                    .update(RequestSign(lender_agreed_at: now))
                    .eq("id", value: requestId)
                    .execute()

                await MainActor.run {
                    self.spinner.stopAnimating()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    // Navigate to lender OTP input
                    let otpVC = LenderOTPInputViewController()
                    otpVC.requestId = self.requestId
                    self.navigationController?.pushViewController(otpVC, animated: true)
                }
            } catch {
                await MainActor.run {
                    self.spinner.stopAnimating()
                    self.agreeButton.isEnabled = true
                    let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
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
        let pixelScale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 2.0
        sep.heightAnchor.constraint(equalToConstant: 1.0 / pixelScale).isActive = true
        return sep
    }
}
