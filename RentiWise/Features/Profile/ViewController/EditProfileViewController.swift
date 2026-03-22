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
    private let upiIdField = UITextField()
    
    private var fullName: String
    private let email: String
    private var phone: String
    private var upiId: String
    
    var onSaved: ((_ newName: String, _ newPhone: String, _ newUpiId: String) -> Void)?
    
    private var isSaving = false
    private var errorMessage: String?
    
    init(fullName: String, email: String, phone: String, upiId: String = "") {
        self.fullName = fullName
        self.email = email
        self.phone = phone
        self.upiId = upiId
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Edit Profile"
        let save = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveTapped))
        // Use the same brand tint as elsewhere
        save.tintColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
        navigationItem.rightBarButtonItem = save
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTapped))
        
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
        
        upiIdField.text = upiId
        upiIdField.placeholder = "name@upi or 9876543210@paytm"
        upiIdField.keyboardType = .emailAddress
        upiIdField.autocapitalizationType = .none
        upiIdField.autocorrectionType = .no
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
        // Validate UPI ID format if provided
        let trimmedUPI = upiIdField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedUPI.isEmpty && !trimmedUPI.contains("@") {
            errorMessage = "UPI ID must contain '@' (e.g., name@upi)"
            tableView.reloadData()
            return
        }
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
        let trimmedUPI = upiIdField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        do {
            guard let userId = await SupabaseManager.shared.currentUserId() else {
                throw NSError(domain: "Profile", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
            }
            
            struct UpdateRow: Encodable {
                let full_name: String
                let phone: String
                let upi_id: String?
            }
            
            _ = try await SupabaseManager.shared.client
                .from("users")
                .update(UpdateRow(full_name: trimmedName, phone: trimmedPhone, upi_id: trimmedUPI.isEmpty ? nil : trimmedUPI))
                .eq("id", value: userId)
                .execute()
            
            await MainActor.run {
                onSaved?(trimmedName, trimmedPhone, trimmedUPI)
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
        // Sections: 0=Name, 1=Contact, 2=UPI, 3=Error (if any)
        return errorMessage != nil ? 4 : 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1       // Full name
        case 1: return 2       // Email + Phone
        case 2: return 1       // UPI ID
        case 3: return 1       // Error message
        default: return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Name"
        case 1: return "Contact"
        case 2: return "UPI"
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 2 {
            return "Your UPI ID is shown to borrowers so they can pay you directly."
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.selectionStyle = .none
        
        // Clear previous content
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        if indexPath.section == 3 {
            // Error message
            cell.textLabel?.text = errorMessage
            cell.textLabel?.textColor = .systemRed
            cell.textLabel?.font = .preferredFont(forTextStyle: .footnote)
            cell.textLabel?.numberOfLines = 0
            return cell
        }
        
        let field: UITextField
        let placeholder: String
        
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            field = fullNameField
            placeholder = "Full Name"
        case (1, 0):
            field = emailField
            placeholder = "Email"
        case (1, 1):
            field = phoneField
            placeholder = "Phone"
        case (2, 0):
            field = upiIdField
            placeholder = "UPI ID (e.g., name@upi)"
        default:
            return cell
        }
        
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = placeholder
        cell.contentView.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            field.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            field.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
            field.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12)
        ])
        
        return cell
    }
}
