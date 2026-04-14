//
//  EditProfileViewController.swift
//  RentiWise
//
//  Created by admin99 on 04/02/26.
//

import UIKit

class EditProfileViewController: UITableViewController {
    
    private let fullNameField = UITextField()
    private let emailField = UITextField()
    private let phoneField = UITextField()
    private let upiIdField = UITextField()

    
    private let profile: UserProfile
    private let validation = AuthValidationService()
    
    var onSaved: ((UserProfile) -> Void)?
    
    private var isSaving = false
    private var errorMessage: String?
    
    init(profile: UserProfile) {
        self.profile = profile
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        self.profile = UserProfile(
            id: "",
            fullName: "",
            email: "",
            phone: "",
            phoneVerified: false,
            kycStatus: "unverified",
            upiId: "",
            collegeEmail: "",
            isCollegeVerified: false,
            averageRating: 0,
            totalRentalsAsBorrower: 0,
            borrowFreezeUntil: nil
        )
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Edit Profile"
        let save = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveTapped))
        save.tintColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
        navigationItem.rightBarButtonItem = save
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTapped))
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.keyboardDismissMode = .interactive
        
        setupTextFields()
        updateSaveButton()
    }
    
    private func setupTextFields() {
        fullNameField.text = profile.fullName
        fullNameField.autocapitalizationType = .words
        fullNameField.autocorrectionType = .no
        fullNameField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
        
        emailField.text = profile.email
        emailField.isEnabled = false
        emailField.textColor = .secondaryLabel
        
        // Phone: show raw 10-digit portion, use numberPad + "+91" prefix
        let rawPhone = profile.phone.hasPrefix("+91") ? String(profile.phone.dropFirst(3)) : profile.phone
        phoneField.text = rawPhone
        phoneField.keyboardType = .numberPad
        phoneField.placeholder = "10-digit mobile number"
        let prefixLabel = UILabel()
        prefixLabel.text = " +91 "
        prefixLabel.font = phoneField.font ?? .systemFont(ofSize: 16)
        prefixLabel.textColor = .secondaryLabel
        prefixLabel.sizeToFit()
        phoneField.leftView = prefixLabel
        phoneField.leftViewMode = .always
        
        upiIdField.text = profile.upiId
        upiIdField.placeholder = "yourname@upi"
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
        Task { await save() }
    }
    
    private func save() async {
        await MainActor.run {
            isSaving = true
            errorMessage = nil
            navigationItem.rightBarButtonItem?.isEnabled = false
        }
        
        defer {
            Task { @MainActor in
                isSaving = false
                updateSaveButton()
            }
        }
        
        let trimmedName = fullNameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedPhoneRaw = phoneField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedUPI = upiIdField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Validate name
        if !validation.isValidFullName(trimmedName) {
            await MainActor.run {
                presentInlineError("Name must contain only letters and spaces (2–50 characters).")
            }
            return
        }

        // Validate phone (if provided)
        let trimmedPhone: String
        if !trimmedPhoneRaw.isEmpty {
            if !validation.isValidPhone(trimmedPhoneRaw) {
                await MainActor.run {
                    presentInlineError("Please enter a valid 10-digit Indian phone number.")
                }
                return
            }
            trimmedPhone = validation.e164Phone(trimmedPhoneRaw)
        } else {
            trimmedPhone = ""
        }

        // Validate UPI (if provided)
        if !trimmedUPI.isEmpty && !validation.isValidUPIId(trimmedUPI) {
            await MainActor.run {
                presentInlineError("UPI ID should look like name@bank (e.g. john@okaxis).")
            }
            return
        }
        
        do {
            let savedProfile = try await ProfileService().saveCurrentUserProfile(
                ProfileSaveInput(
                    fullName: trimmedName,
                    phone: trimmedPhone,
                    upiId: trimmedUPI,
                    collegeEmail: ""
                )
            )
            
            await MainActor.run {
                let successMessage = makeSuccessMessage(for: savedProfile)
                let presenter = self.navigationController?.presentingViewController
                onSaved?(savedProfile)
                dismiss(animated: true) {
                    let target = (presenter as? UINavigationController)?.topViewController ?? presenter
                    guard let target else { return }
                    let alert = UIAlertController(
                        title: "Profile Updated",
                        message: successMessage,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    target.present(alert, animated: true)
                }
            }
        } catch {
            await MainActor.run {
                presentInlineError(error.localizedDescription)
            }
        }
    }
    
    @MainActor
    private func presentInlineError(_ message: String) {
        errorMessage = message
        tableView.reloadData()
    }

    private func makeSuccessMessage(for profile: UserProfile) -> String {
        return "Your profile changes were saved successfully."
    }
    
    // MARK: - TableView DataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return errorMessage != nil ? 3 : 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if errorMessage != nil && section == 2 { return 1 }
        switch section {
        case 0: return 1
        case 1: return 3
        default: return 1
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Name"
        case 1: return "Contact"
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return nil
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.selectionStyle = .none
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        if errorMessage != nil && indexPath.section == 2 {
            cell.textLabel?.text = errorMessage
            cell.textLabel?.textColor = .systemRed
            cell.textLabel?.font = .preferredFont(forTextStyle: .footnote)
            cell.textLabel?.numberOfLines = 0
            return cell
        }
        
        switch indexPath.section {
        case 0:
            embed(field: fullNameField, in: cell, placeholder: "Full Name")
        case 1:
            switch indexPath.row {
            case 0:
                embed(field: emailField, in: cell, placeholder: "Email")
            case 1:
                embed(field: phoneField, in: cell, placeholder: "Phone")
            default:
                embed(field: upiIdField, in: cell, placeholder: "UPI ID")
            }
        default:
            break
        }
        
        return cell
    }
    
    private func embed(field: UITextField, in cell: UITableViewCell, placeholder: String) {
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = placeholder
        cell.contentView.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            field.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            field.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
            field.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12)
        ])
    }
}
