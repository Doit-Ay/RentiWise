//
//  ChangePasswordViewController.swift
//  RentiWise
//
//  Created by admin99 on 04/02/26.
//

import UIKit
import Supabase

class ChangePasswordViewController: UITableViewController {
    
    private let currentPasswordField = UITextField()
    private let newPasswordField = UITextField()
    private let confirmPasswordField = UITextField()
    
    private var showCurrent = false
    private var showNew = false
    private var showConfirm = false
    
    private var isUpdating = false
    private var statusMessage: String?
    
    private let brandTeal = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)
    
    init() {
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Change Password"
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.backgroundColor = .systemGroupedBackground
        tableView.keyboardDismissMode = .interactive
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Update", style: .done, target: self, action: #selector(updateTapped))
        navigationItem.rightBarButtonItem?.tintColor = brandTeal
        
        setupTextFields()
        
        Task {
            if await SupabaseManager.shared.currentUserId() == nil {
                await MainActor.run {
                    self.navigationItem.rightBarButtonItem?.isEnabled = false
                    self.statusMessage = "Please sign in to update your password."
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = true
    }
    
    private func setupTextFields() {
        currentPasswordField.isSecureTextEntry = true
        currentPasswordField.textContentType = .password
        currentPasswordField.autocorrectionType = .no
        currentPasswordField.autocapitalizationType = .none
        currentPasswordField.placeholder = "Current Password"
        
        newPasswordField.isSecureTextEntry = true
        newPasswordField.textContentType = .newPassword
        newPasswordField.autocorrectionType = .no
        newPasswordField.autocapitalizationType = .none
        newPasswordField.placeholder = "New Password"
        
        confirmPasswordField.isSecureTextEntry = true
        confirmPasswordField.textContentType = .newPassword
        confirmPasswordField.autocorrectionType = .no
        confirmPasswordField.autocapitalizationType = .none
        confirmPasswordField.placeholder = "Confirm New Password"
    }
    
    @objc private func updateTapped() {
        Task { await updatePassword() }
    }
    
    private func updatePassword() async {
        await MainActor.run {
            isUpdating = true
            statusMessage = nil
            navigationItem.rightBarButtonItem?.isEnabled = false
        }
        
        defer {
            Task { @MainActor in
                isUpdating = false
                navigationItem.rightBarButtonItem?.isEnabled = true
                tableView.reloadData()
            }
        }
        
        do {
            // UI-only per request: no validation. Attempt password update via Supabase.
            try await SupabaseManager.shared.client.auth.update(user: .init(password: newPasswordField.text ?? ""))
            await MainActor.run { statusMessage = "Password updated." }
        } catch {
            await MainActor.run { statusMessage = error.localizedDescription }
        }
    }
    
    // MARK: - TableView DataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return statusMessage != nil ? 2 : 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 3 : 1 // 3 password fields, 1 status message
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.selectionStyle = .none
        
        // Clear previous content
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        if indexPath.section == 1 {
            // Status message
            let label = UILabel()
            label.text = statusMessage
            label.font = .preferredFont(forTextStyle: .footnote)
            label.textColor = .secondaryLabel
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                label.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                label.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                label.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8)
            ])
            return cell
        }
        
        // Password field rows
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(container)
        
        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let field: UITextField
        let toggleButton = UIButton(type: .system)
        var isSecure: Bool
        
        switch indexPath.row {
        case 0:
            titleLabel.text = "Current Password"
            field = currentPasswordField
            isSecure = !showCurrent
            toggleButton.addTarget(self, action: #selector(toggleCurrentPassword), for: .touchUpInside)
        case 1:
            titleLabel.text = "New Password"
            field = newPasswordField
            isSecure = !showNew
            toggleButton.addTarget(self, action: #selector(toggleNewPassword), for: .touchUpInside)
        default:
            titleLabel.text = "Confirm New Password"
            field = confirmPasswordField
            isSecure = !showConfirm
            toggleButton.addTarget(self, action: #selector(toggleConfirmPassword), for: .touchUpInside)
        }
        
        field.isSecureTextEntry = isSecure
        toggleButton.setImage(UIImage(systemName: isSecure ? "eye.slash" : "eye"), for: .normal)
        toggleButton.tintColor = brandTeal
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, field])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        field.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(stack)
        container.addSubview(toggleButton)
        
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            container.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
            container.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
            
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: toggleButton.leadingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            toggleButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            toggleButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            toggleButton.widthAnchor.constraint(equalToConstant: 40)
        ])
        
        return cell
    }
    
    @objc private func toggleCurrentPassword() {
        showCurrent.toggle()
        tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
    }
    
    @objc private func toggleNewPassword() {
        showNew.toggle()
        tableView.reloadRows(at: [IndexPath(row: 1, section: 0)], with: .none)
    }
    
    @objc private func toggleConfirmPassword() {
        showConfirm.toggle()
        tableView.reloadRows(at: [IndexPath(row: 2, section: 0)], with: .none)
    }
}
