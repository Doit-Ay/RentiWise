//
//  ManageDataViewController.swift
//  RentiWise
//
//  Created by admin99 on 04/02/26.
//

import UIKit
import Supabase

class ManageDataViewController: UITableViewController {
    
    private var isDeleting = false
    private var errorMessage: String?
    private let urlSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()
    
    private enum Section: Int, CaseIterable {
        case data
        case actions
    }
    
    init() {
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Manage Data"
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.backgroundColor = .systemGroupedBackground
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = true
    }
    
    // MARK: - TableView DataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return errorMessage != nil ? 3 : Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if errorMessage != nil && section == 0 { return 1 }
        if errorMessage != nil { return self.tableView(tableView, numberOfRowsInSection: section - 1) }
        
        guard let sectionType = Section(rawValue: section) else { return 0 }
        
        switch sectionType {
        case .data:
            return 1 // Profile Information
        case .actions:
            return 1 // Delete Account
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if errorMessage != nil && section == 0 { return nil }
        if errorMessage != nil { return self.tableViewHeaderTitle(forSection: section - 1) }
        
        guard let sectionType = Section(rawValue: section) else { return nil }
        
        switch sectionType {
        case .data:
            return "Data"
        case .actions:
            return "Actions"
        }
    }
    
    private func tableViewHeaderTitle(forSection section: Int) -> String? {
        
        guard let sectionType = Section(rawValue: section) else { return nil }
        
        switch sectionType {
        case .data:
            return "Data"
        case .actions:
            return "Actions"
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.textColor = .label
        cell.textLabel?.textAlignment = .natural
        
        if errorMessage != nil && indexPath.section == 0 {
            cell.textLabel?.text = errorMessage
            cell.textLabel?.textColor = .systemRed
            cell.textLabel?.font = .preferredFont(forTextStyle: .footnote)
            cell.textLabel?.numberOfLines = 0
            cell.accessoryType = .none
            cell.selectionStyle = .none
            return cell
        }
        
        let actualSection = errorMessage != nil ? indexPath.section - 1 : indexPath.section
        guard let sectionType = Section(rawValue: actualSection) else { return cell }
        
        switch sectionType {
        case .data:
            cell.accessoryType = .disclosureIndicator
            cell.textLabel?.text = "Profile Information"
            
        case .actions:
            cell.accessoryType = .none
            if isDeleting {
                cell.textLabel?.text = "Deleting Account…"
                cell.textLabel?.textColor = .systemRed
                let spinner = UIActivityIndicatorView(style: .medium)
                spinner.startAnimating()
                cell.accessoryView = spinner
            } else {
                cell.textLabel?.text = "Delete Account"
                cell.textLabel?.textColor = .systemRed
                cell.accessoryView = nil
            }
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if errorMessage != nil && indexPath.section == 0 { return }
        
        let actualSection = errorMessage != nil ? indexPath.section - 1 : indexPath.section
        guard let sectionType = Section(rawValue: actualSection) else { return }
        
        switch sectionType {
        case .data:
            let vc = ProfileInformationViewController()
            vc.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(vc, animated: true)
            
        case .actions:
            // Delete Account
            showDeleteConfirmation()
        }
    }
    
    private func showDeleteConfirmation() {
        let alert = UIAlertController(
            title: "Delete your account?",
            message: "This permanently deletes your login, profile, listings, requests, messages, support history, and saved data from RentiWise. This action cannot be undone.",
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: "Delete Account", style: .destructive) { [weak self] _ in
            self?.showTypedDeleteConfirmation()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showTypedDeleteConfirmation() {
        let alert = UIAlertController(
            title: "Type DELETE to confirm",
            message: "We will first verify the secure deletion service before removing any account data.",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "DELETE"
            textField.autocapitalizationType = .allCharacters
            textField.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self, weak alert] _ in
            let typed = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard typed == "DELETE" else {
                self?.errorMessage = "Type DELETE exactly to confirm account deletion."
                self?.tableView.reloadData()
                return
            }
            Task { await self?.deleteAccount() }
        })
        present(alert, animated: true)
    }
    
    private func deleteAccount() async {
        guard !isDeleting else { return }
        
        await MainActor.run {
            isDeleting = true
            tableView.reloadData()
        }
        
        defer {
            Task { @MainActor in
                isDeleting = false
                tableView.reloadData()
            }
        }
        
        do {
            guard let session = try? await SupabaseManager.shared.client.auth.session else {
                throw NSError(domain: "ManageData", code: 2, userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
            }
            let userId = session.user.id.uuidString
            if userId.isEmpty {
                throw NSError(domain: "ManageData", code: 2, userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
            }

            try await attemptPrivilegedAccountDeletion(session: session, dryRun: true)
            try await attemptPrivilegedAccountDeletion(session: session, dryRun: false)

            try? await SupabaseManager.shared.signOut()
            // Reset location to default (Chennai, Tamil Nadu)
            SavedAddressesStore.shared.resetToDefault()

            await MainActor.run {
                errorMessage = nil
                navigationController?.popToRootViewController(animated: true)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                tableView.reloadData()
            }
        }
    }

    private func attemptPrivilegedAccountDeletion(session: Session, dryRun: Bool) async throws {
        struct EdgeResponse: Decodable {
            let error: String?
            let details: String?
        }

        let supabaseUrl = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
        guard let url = URL(string: "\(supabaseUrl)/functions/v1/delete-account") else {
            throw AccountDeletionError.missingConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? "", forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "user_id": session.user.id.uuidString,
            "dry_run": dryRun
        ])

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AccountDeletionError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200, 204:
            debugLog("[ManageData] delete-account edge function completed (dry_run=\(dryRun))")
        case 404:
            debugLog("[ManageData] delete-account edge function is not deployed (dry_run=\(dryRun))")
            throw AccountDeletionError.serviceUnavailable
        default:
            let edgeResponse = try? JSONDecoder().decode(EdgeResponse.self, from: data)
            let message = edgeResponse?.details ?? edgeResponse?.error
            debugLog("[ManageData] delete-account edge function returned \(httpResponse.statusCode) (dry_run=\(dryRun))")
            throw AccountDeletionError.serverError(httpResponse.statusCode, message)
        }
    }
}

// MARK: - Account Deletion Error Types

enum AccountDeletionError: LocalizedError {
    case missingConfiguration
    case invalidResponse
    case serviceUnavailable
    case serverError(Int, String?)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Unable to reach the account deletion service. Please contact support."
        case .invalidResponse:
            return "Received an invalid response from the deletion service."
        case .serviceUnavailable:
            return "Full account deletion could not start because the secure deletion service is unavailable. No account data was removed. Contact support@rentiwise.com for help."
        case .serverError(let code, let message):
            if let message, !message.isEmpty {
                return "Account deletion failed (code \(code)): \(message)"
            }
            return "Account deletion failed (code \(code)). No account data was removed."
        }
    }
}
