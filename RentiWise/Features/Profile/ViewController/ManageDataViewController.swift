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
            return 2 // Profile Information, Payment History
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
            if indexPath.row == 0 {
                cell.textLabel?.text = "Profile Information"
            } else {
                cell.textLabel?.text = "Payment History"
            }
            
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
            if indexPath.row == 0 {
                // Profile Information
                let vc = ProfileInformationViewController()
                vc.hidesBottomBarWhenPushed = true
                navigationController?.pushViewController(vc, animated: true)
            } else {
                // Payment History
                let vc = PaymentHistoryViewController()
                vc.hidesBottomBarWhenPushed = true
                navigationController?.pushViewController(vc, animated: true)
            }
            
        case .actions:
            // Delete Account
            showDeleteConfirmation()
        }
    }
    
    private func showDeleteConfirmation() {
        let alert = UIAlertController(
            title: "Delete your account?",
            message: "This will permanently delete your profile, bookings, and payments. This action cannot be undone.",
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: "Delete Account", style: .destructive) { [weak self] _ in
            Task { await self?.deleteAccount() }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
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
            guard let userId = await SupabaseManager.shared.currentUserId() else {
                throw NSError(domain: "ManageData", code: 2, userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
            }
            
            let client = SupabaseManager.shared.client
            // Delete related rows (order matters if FKs don't cascade)
            _ = try await client.from("payments").delete().eq("user_id", value: userId).execute()
            _ = try await client.from("bookings").delete().eq("user_id", value: userId).execute()
            _ = try await client.from("wishlist").delete().eq("user_id", value: userId).execute()
            _ = try await client.from("users").delete().eq("id", value: userId).execute()
            
            try await SupabaseManager.shared.signOut()
            
            // Navigate back to profile
            await MainActor.run {
                navigationController?.popToRootViewController(animated: true)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                tableView.reloadData()
            }
        }
    }
}
