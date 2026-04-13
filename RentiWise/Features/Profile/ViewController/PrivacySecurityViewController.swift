//
//  PrivacySecurityViewController.swift
//  RentiWise
//
//  Created by admin99 on 04/02/26.
//

import UIKit

class PrivacySecurityViewController: UITableViewController {
    
    private enum Section: Int, CaseIterable {
        case privacy
        case security
    }
    
    init() {
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Privacy & Security"
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.backgroundColor = .systemGroupedBackground
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = true
    }
    
    // MARK: - TableView DataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        
        switch sectionType {
        case .privacy:
            return 3 // Terms, Privacy Policy, Blocked Users
        case .security:
            return 1 // Change Password
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }
        
        switch sectionType {
        case .privacy:
            return "Privacy"
        case .security:
            return "Security"
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.accessoryType = .disclosureIndicator
        
        guard let sectionType = Section(rawValue: indexPath.section) else { return cell }
        
        switch sectionType {
        case .privacy:
            if indexPath.row == 0 {
                cell.textLabel?.text = "Terms of Service"
            } else if indexPath.row == 1 {
                cell.textLabel?.text = "Privacy Policy"
            } else if indexPath.row == 2 {
                cell.textLabel?.text = "Blocked Users"
            }
        case .security:
            cell.textLabel?.text = "Change Password"
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let sectionType = Section(rawValue: indexPath.section) else { return }
        
        switch sectionType {
        case .privacy:
            if indexPath.row == 0 {
                let vc = LegalDocumentViewController(document: .termsOfService)
                vc.hidesBottomBarWhenPushed = true
                navigationController?.pushViewController(vc, animated: true)
            } else if indexPath.row == 1 {
                let vc = LegalDocumentViewController(document: .privacyPolicy)
                vc.hidesBottomBarWhenPushed = true
                navigationController?.pushViewController(vc, animated: true)
            } else if indexPath.row == 2 {
                let vc = BlockedUsersViewController()
                vc.hidesBottomBarWhenPushed = true
                navigationController?.pushViewController(vc, animated: true)
            }
        case .security:
            // Change Password
            let vc = ChangePasswordViewController()
            vc.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

enum LegalDocument {
    case termsOfService
    case privacyPolicy

    var title: String {
        switch self {
        case .termsOfService:
            return "Terms of Service"
        case .privacyPolicy:
            return "Privacy Policy"
        }
    }

    var body: String {
        switch self {
        case .termsOfService:
            return """
            Rentiwise helps people discover, request, lend, and borrow real-world items from each other.

            Payments and transactions:
            - Rental fees are arranged directly between users, typically through UPI or another method both users agree on.
            - Rentiwise does not store card numbers, hold funds, issue credit, or act as a bank or escrow service.
            - Lenders and borrowers must review the item details, pricing, duration, pickup plan, and payment terms before completing a handoff.

            User responsibilities:
            - Lenders must post accurate item descriptions, prices, photos, and availability.
            - Borrowers must return items on time and in the agreed condition.
            - Users are responsible for any damage, late return, fraud, or payment dispute they create.

            Safety rules:
            - Illegal, hazardous, counterfeit, stolen, or otherwise prohibited items may not be listed.
            - Users can report listings, conversations, and profiles, and can block other users inside the app.
            - Rentiwise may remove content, suspend accounts, or restrict activity to protect the community.

            Damage and returns:
            - Borrowers must return items by the agreed return date and in substantially the same condition shown at handoff, allowing for normal disclosed wear.
            - If an item is damaged, the lender should file an in-app damage report with photos and a description as soon as the item is returned.
            - If an item is not returned, the lender should open an in-app dispute immediately so the platform can review the record and account activity.

            Refunds and dispute resolution:
            - Users should first document and discuss issues in the in-app chat.
            - Damage, non-return, refund, or conduct issues should also be reported through the in-app Support screen.
            - Approved rental refunds are generally processed within the timeline shown in the relevant in-app payment or support status, and may vary based on the payment rail used between users.
            - Rentiwise may review listing data, chat history, timestamps, return proof, and safety reports to help resolve disputes.
            - You can contact the team at support@rentiwise.com for escalations or account help.

            Liability and platform limits:
            - Rentiwise is not a party to the final lending agreement between users.
            - Users remain responsible for item damage, loss, non-return, fraudulent conduct, and any payment dispute they create.
            - To the extent permitted by law, Rentiwise’s liability is limited to the platform services it directly provides and does not extend to independent agreements or off-platform conduct between users.
            - We may review platform activity, listing data, support tickets, and safety reports to investigate abuse or policy violations.
            - By using the app, you accept responsibility for the lending decisions you make with other users.
            """
        case .privacyPolicy:
            return """
            Rentiwise collects the information needed to operate the marketplace, keep users safer, and support lending transactions.

            Data we collect:
            - Account information such as your name, email address, phone number, and profile details
            - Listing information, item photos, reviews, request history, messages, and support tickets
            - Approximate location data used to show nearby items and pickup relevance
            - College or identity-verification details you choose to provide for trust and safety checks
            - UPI ID or payout details you enter so other users can pay you directly

            How we use data:
            - To create and manage your account
            - To show listings, coordinate requests, and support item handoffs
            - To investigate reports, enforce safety rules, and reduce fraud or abusive behavior
            - To provide support and resolve disputes, returns, or account issues

            Payments:
            - Rentiwise does not collect raw card numbers or store card credentials.
            - Rental payments are arranged directly between users, so the app only stores the payment identifiers you choose to share, such as a UPI ID.

            Storage and sharing:
            - Rentiwise uses Supabase services to store app data and operate backend features.
            - If you start identity verification, verification data may also be processed by our verification providers for that flow.
            - We do not sell your personal data.
            - We may disclose information when required for legal compliance, safety investigations, fraud prevention, or dispute handling.

            Your choices:
            - You can update profile information inside the app.
            - You can review blocked users from Privacy & Security.
            - You can delete your account from the Manage Data section in the app. That flow is designed to remove your login, profile, listings, requests, messages, support history, and saved data from Rentiwise.
            - If the secure deletion flow is unavailable or you need privacy help, contact support@rentiwise.com.
            """
        }
    }
}

final class LegalDocumentViewController: UIViewController {

    private let document: LegalDocument

    init(document: LegalDocument) {
        self.document = document
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.document = .termsOfService
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = document.title
        view.backgroundColor = .systemBackground

        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.alwaysBounceVertical = true
        textView.backgroundColor = .clear
        textView.textColor = .label
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 24, right: 20)
        textView.text = document.body

        view.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
