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
        
        if let profile = profile {
            return profile.phone.isEmpty ? 2 : 3
        }
        return 0
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
        
        guard let profile = profile else { return cell }
        
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
        
        switch indexPath.row {
        case 0:
            label.text = "Full Name"
            valueLabel.text = profile.fullName
        case 1:
            label.text = "Email"
            valueLabel.text = profile.email
        case 2:
            label.text = "Phone"
            valueLabel.text = profile.phone
        default:
            break
        }
        
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
