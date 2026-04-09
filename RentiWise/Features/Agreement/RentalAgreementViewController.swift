//
//  RentalAgreementViewController.swift
//  RentiWise
//
//  Borrower-facing agreement screen. Creates a rental_agreements row
//  and lets the borrower sign. After signing, navigates to waiting screen.
//

import UIKit
import Supabase

final class RentalAgreementViewController: UIViewController {

    // MARK: - Inputs (set before push)
    var requestId: String = ""
    var itemName: String = ""
    var itemId: String = ""
    var lenderId: String = ""
    var borrowerId: String = ""
    var lenderName: String = ""
    var borrowerName: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    var durationDays: Int = 1
    var pricePerDay: Double = 0
    var totalRentalPrice: Double = 0
    var depositAmount: Double = 0

    // MARK: - Internal
    private var agreementId: String?

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

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Rental Agreement"
        view.backgroundColor = bgColor
        navigationController?.navigationBar.tintColor = brandTeal
        setupUI()
        createAgreementRow()
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

        // Agreement Details Card
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

        detailsStack.addArrangedSubview(makeRow("Item", value: itemName))
        detailsStack.addArrangedSubview(makeRow("From", value: dateFormatter.string(from: startDate)))
        detailsStack.addArrangedSubview(makeRow("To", value: dateFormatter.string(from: endDate)))
        detailsStack.addArrangedSubview(makeRow("Duration", value: "\(durationDays) day\(durationDays == 1 ? "" : "s")"))
        detailsStack.addArrangedSubview(makeRow("Daily Rate", value: String(format: "₹%.0f/day", pricePerDay)))
        detailsStack.addArrangedSubview(makeRow("Total", value: String(format: "₹%.0f", totalRentalPrice)))
        detailsStack.addArrangedSubview(makeRow("Deposit", value: String(format: "₹%.0f (direct)", depositAmount)))
        detailsStack.addArrangedSubview(makeSeparator())
        detailsStack.addArrangedSubview(makeRow("Lender", value: lenderName))
        detailsStack.addArrangedSubview(makeRow("Borrower", value: borrowerName))

        detailsCard.addSubview(detailsStack)
        pinToCard(detailsStack, in: detailsCard)
        contentStack.addArrangedSubview(detailsCard)

        // Terms Card
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
            "1. The borrower agrees to return the item in the same condition it was received.",
            "2. The deposit (₹\(String(format: "%.0f", depositAmount))) is paid directly to the lender and is refundable upon safe return of the item.",
            "3. Rentiwise is a facilitation platform and is not responsible for item condition or payment disputes.",
            "4. Both parties agree to resolve any disputes directly between themselves.",
            "5. Late returns may incur additional charges as agreed between both parties.",
            "6. By signing this agreement, both parties confirm the rental details above are accurate."
        ]
        for term in terms {
            let lbl = UILabel()
            lbl.text = term
            lbl.font = .systemFont(ofSize: 14)
            lbl.textColor = bodyColor
            lbl.numberOfLines = 0

            let style = NSMutableParagraphStyle()
            style.lineSpacing = 4
            lbl.attributedText = NSAttributedString(string: term, attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: bodyColor,
                .paragraphStyle: style
            ])
            termsStack.addArrangedSubview(lbl)
        }

        termsCard.addSubview(termsStack)
        pinToCard(termsStack, in: termsCard)
        contentStack.addArrangedSubview(termsCard)

        // Checkbox row
        let checkRow = UIStackView()
        checkRow.axis = .horizontal
        checkRow.spacing = 12
        checkRow.alignment = .center

        agreeCheckbox.setImage(UIImage(systemName: "square"), for: .normal)
        agreeCheckbox.tintColor = UIColor.systemGray3
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
        agreeButton.setTitle("I Agree & Continue", for: .normal)
        agreeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        agreeButton.backgroundColor = UIColor.systemGray4
        agreeButton.setTitleColor(.white, for: .normal)
        agreeButton.layer.cornerRadius = 12
        agreeButton.isEnabled = false
        agreeButton.translatesAutoresizingMaskIntoConstraints = false
        agreeButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        agreeButton.addTarget(self, action: #selector(agreeTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(agreeButton)

        // Spinner
        spinner.hidesWhenStopped = true
        spinner.color = brandTeal
        contentStack.addArrangedSubview(spinner)

        // Signing caption
        let caption = UILabel()
        caption.text = "Signing as: \(borrowerName)\n[timestamp will be recorded]"
        caption.font = .preferredFont(forTextStyle: .caption1)
        caption.textColor = captionColor
        caption.textAlignment = .center
        caption.numberOfLines = 0
        contentStack.addArrangedSubview(caption)
    }

    // MARK: - Actions
    @objc private func checkboxTapped() {
        isChecked.toggle()
        let img = isChecked ? "checkmark.square.fill" : "square"
        agreeCheckbox.setImage(UIImage(systemName: img), for: .normal)
        agreeCheckbox.tintColor = isChecked ? brandTeal : .systemGray3
        agreeButton.isEnabled = isChecked
        agreeButton.backgroundColor = isChecked ? brandTeal : .systemGray4
    }

    @objc private func agreeTapped() {
        guard isChecked, let agreementId else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        agreeButton.isEnabled = false
        spinner.startAnimating()

        Task {
            do {
                let now = ISO8601DateFormatter().string(from: Date())

                // Update agreement
                struct AgreementSign: Encodable { let borrower_agreed_at: String }
                try await SupabaseManager.shared.client
                    .from("rental_agreements")
                    .update(AgreementSign(borrower_agreed_at: now))
                    .eq("id", value: agreementId)
                    .execute()

                // Update request
                struct RequestSign: Encodable { let borrower_agreed_at: String }
                try await SupabaseManager.shared.client
                    .from("requests")
                    .update(RequestSign(borrower_agreed_at: now))
                    .eq("id", value: requestId)
                    .execute()

                await MainActor.run {
                    self.spinner.stopAnimating()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    // Navigate to waiting screen
                    let waitVC = AgreementWaitingViewController()
                    waitVC.agreementId = agreementId
                    waitVC.lenderName = self.lenderName
                    waitVC.requestId = self.requestId
                    self.navigationController?.pushViewController(waitVC, animated: true)
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

    // MARK: - Create Agreement Row
    private func createAgreementRow() {
        Task {
            do {
                struct AgreementInsert: Encodable {
                    let request_id: String
                    let item_name: String
                    let item_id: String
                    let lender_id: String
                    let borrower_id: String
                    let start_date: String
                    let end_date: String
                    let duration_days: Int
                    let agreed_price_per_day: Double
                    let total_rental_price: Double
                    let deposit_amount: Double
                }

                struct AgreementRow: Decodable { let id: String }

                let insert = AgreementInsert(
                    request_id: requestId,
                    item_name: itemName,
                    item_id: itemId,
                    lender_id: lenderId,
                    borrower_id: borrowerId,
                    start_date: dateFormatter.string(from: startDate),
                    end_date: dateFormatter.string(from: endDate),
                    duration_days: durationDays,
                    agreed_price_per_day: pricePerDay,
                    total_rental_price: totalRentalPrice,
                    deposit_amount: depositAmount
                )

                let resp = try await SupabaseManager.shared.client
                    .from("rental_agreements")
                    .insert(insert)
                    .select("id")
                    .single()
                    .execute()

                let row = try JSONDecoder().decode(AgreementRow.self, from: resp.data)
                agreementId = row.id

                // Link agreement to request
                struct LinkUpdate: Encodable { let agreement_id: String }
                try await SupabaseManager.shared.client
                    .from("requests")
                    .update(LinkUpdate(agreement_id: row.id))
                    .eq("id", value: requestId)
                    .execute()

            } catch {
                await MainActor.run {
                    let alert = UIAlertController(title: "Error", message: "Failed to create agreement: \(error.localizedDescription)", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                        self.navigationController?.popViewController(animated: true)
                    })
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
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14)
        titleLabel.textColor = captionColor

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 14, weight: .medium)
        valueLabel.textColor = bodyColor
        valueLabel.textAlignment = .right

        let row = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
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
