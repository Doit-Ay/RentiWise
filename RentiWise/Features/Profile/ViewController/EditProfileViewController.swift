//
//  EditProfileViewController.swift
//  RentiWise
//
//  Created by admin99 on 04/02/26.
//

import UIKit
import Supabase

class EditProfileViewController: UITableViewController {
    
    private let fullNameField = UITextField()
    private let emailField = UITextField()
    private let phoneField = UITextField()
    
    private var fullName: String
    private let email: String
    private var phone: String
    
    var onSaved: ((_ newName: String, _ newPhone: String) -> Void)?
    
    private var isSaving = false
    private var errorMessage: String?
    
    init(fullName: String, email: String, phone: String) {
        self.fullName = fullName
        self.email = email
        self.phone = phone
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Edit Profile"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveTapped))
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.keyboardDismissMode = .interactive
        
        setupTextFields()
        updateSaveButton()
    }
    
    private func setupTextFields() {
        fullNameField.text = fullName
        fullNameField.autocapitalizationType = .words
        fullNameField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
        
        emailField.text = email
        emailField.isEnabled = false
        emailField.textColor = .secondaryLabel
        
        phoneField.text = phone
        phoneField.keyboardType = .phonePad
    }
    
    @objc private func textFieldChanged() {
        updateSaveButton()
    }
    
    private func updateSaveButton() {
        let trimmed = fullNameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        navigationItem.rightBarButtonItem?.isEnabled = !trimmed.isEmpty && !isSaving
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveTapped() {
        Task { await save() }
    }
    
    private func save() async {
        await MainActor.run {
            isSaving = true
            navigationItem.rightBarButtonItem?.isEnabled = false
        }
        
        defer {
            Task { @MainActor in
                isSaving = false
                updateSaveButton()
            }
        }
        
        let trimmedName = fullNameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedPhone = phoneField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        do {
            guard let userId = await SupabaseManager.shared.currentUserId() else {
                throw NSError(domain: "Profile", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
            }
            
            struct UpdateRow: Encodable {
                let full_name: String
                let phone: String
            }
            
            _ = try await SupabaseManager.shared.client
                .from("users")
                .update(UpdateRow(full_name: trimmedName, phone: trimmedPhone))
                .eq("id", value: userId)
                .execute()
            
            await MainActor.run {
                onSaved?(trimmedName, trimmedPhone)
                dismiss(animated: true)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                tableView.reloadData()
            }
        }
    }
    
    // MARK: - TableView DataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return errorMessage != nil ? 3 : 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 2 ? 1 : section == 0 ? 1 : 2
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 { return "Name" }
        if section == 1 { return "Contact" }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.selectionStyle = .none
        
        // Clear previous content
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        if indexPath.section == 2 {
            // Error message
            cell.textLabel?.text = errorMessage
            cell.textLabel?.textColor = .systemRed
            cell.textLabel?.font = .preferredFont(forTextStyle: .footnote)
            cell.textLabel?.numberOfLines = 0
            return cell
        }
        
        if indexPath.section == 0 {
            // Full name
            fullNameField.translatesAutoresizingMaskIntoConstraints = false
            fullNameField.placeholder = "Full Name"
            cell.contentView.addSubview(fullNameField)
            NSLayoutConstraint.activate([
                fullNameField.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                fullNameField.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                fullNameField.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
                fullNameField.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12)
            ])
        } else if indexPath.section == 1 {
            if indexPath.row == 0 {
                // Email
                emailField.translatesAutoresizingMaskIntoConstraints = false
                emailField.placeholder = "Email"
                cell.contentView.addSubview(emailField)
                NSLayoutConstraint.activate([
                    emailField.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                    emailField.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                    emailField.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
                    emailField.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12)
                ])
            } else {
                // Phone
                phoneField.translatesAutoresizingMaskIntoConstraints = false
                phoneField.placeholder = "Phone"
                cell.contentView.addSubview(phoneField)
                NSLayoutConstraint.activate([
                    phoneField.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                    phoneField.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                    phoneField.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
                    phoneField.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12)
                ])
            }
        }
        
        return cell
    }
}
