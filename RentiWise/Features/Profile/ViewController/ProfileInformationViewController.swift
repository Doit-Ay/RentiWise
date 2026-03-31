//
//  ProfileInformationViewController.swift
//  RentiWise
//
//  Created by admin99 on 04/02/26.
//

import UIKit
import Supabase

class ProfileInformationViewController: UITableViewController {
    
    private var profile: UserProfile?
    private var isLoading = false
    private var errorMessage: String?
    
    private var profileRows: [(String, String)] {
        guard let profile else { return [] }

        var rows: [(String, String)] = [
            ("Full Name", profile.fullName.isEmpty ? "Not set" : profile.fullName),
            ("Email", profile.email.isEmpty ? "Not set" : profile.email),
            ("Phone", profile.phone.isEmpty ? "Not set" : profile.phone),
            ("UPI ID", profile.upiId.isEmpty ? "Not set" : profile.upiId),
            ("College Email", profile.collegeEmail.isEmpty ? "Not set" : profile.collegeEmail),
            ("College Verified", profile.isCollegeVerified ? "Yes" : "No")
        ]

        if profile.averageRating > 0 {
            rows.append(("Borrow Rating", String(format: "%.1f", profile.averageRating)))
        }

        if let freeze = profile.borrowFreezeUntil, freeze > Date() {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            rows.append(("Borrow Freeze Until", formatter.string(from: freeze)))
        }

        return rows
    }
    
    init() {
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Profile Information"
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.backgroundColor = .systemGroupedBackground
        
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        
        Task { await load() }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = true
    }
    
    @objc private func handleRefresh() {
        Task {
            await load()
            await MainActor.run {
                refreshControl?.endRefreshing()
            }
        }
    }
    
    private func load() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
                tableView.reloadData()
            }
        }
        
        do {
            let p = try await ProfileService().fetchCurrentUserProfile()
            await MainActor.run { profile = p }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
    
    // MARK: - TableView DataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if errorMessage != nil { return 1 }
        if isLoading { return 1 }
        return profile != nil ? 1 : 0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if errorMessage != nil { return 1 }
        if isLoading { return 1 }
        return profileRows.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if errorMessage != nil || isLoading { return nil }
        return "Profile"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.selectionStyle = .none
        
        if let errorMessage {
            cell.textLabel?.text = errorMessage
            cell.textLabel?.textColor = .systemRed
            cell.textLabel?.font = .preferredFont(forTextStyle: .footnote)
            cell.textLabel?.numberOfLines = 0
            return cell
        }
        
        if isLoading {
            cell.textLabel?.text = nil
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            spinner.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 44)
            cell.contentView.addSubview(spinner)
            return cell
        }
        
        guard indexPath.row < profileRows.count else { return cell }
        let row = profileRows[indexPath.row]
        
        // Create labeled content cell
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = UILabel()
        valueLabel.font = .preferredFont(forTextStyle: .body)
        valueLabel.textColor = .label
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        label.text = row.0
        valueLabel.text = row.1
        
        cell.contentView.addSubview(label)
        cell.contentView.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            
            valueLabel.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            valueLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8)
        ])
        
        return cell
    }
}
