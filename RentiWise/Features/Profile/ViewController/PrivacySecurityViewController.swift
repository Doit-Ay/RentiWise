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
            return 2 // Manage Data, App Permissions
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
                cell.textLabel?.text = "Manage Data"
            } else {
                cell.textLabel?.text = "App Permissions"
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
                // Manage Data
                let vc = ManageDataViewController()
                vc.hidesBottomBarWhenPushed = true
                navigationController?.pushViewController(vc, animated: true)
            } else {
                // App Permissions
                let vc = AppPermissionsViewController()
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
