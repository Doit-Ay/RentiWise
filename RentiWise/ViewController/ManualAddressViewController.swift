import UIKit
import CoreLocation

final class ManualAddressViewController: UIViewController {

    // Prefill (optional)
    var prefillCity: String?
    var prefillState: String?
    var prefillCountry: String?

    // Edit mode
    var existing: Address?

    // Completion when saved (optional)
    var onSaved: ((Address) -> Void)?

    // Containers
    private let scroll = UIScrollView()
    private let content = UIStackView()

    // Sections
    private let contactSection = UIStackView()
    private let addressSection = UIStackView()
    private let defaultSection = UIStackView()

    // Fields
    private var labelField = UITextField()
    private var fullNameField = UITextField()
    private var phoneField = UITextField()
    private var line1Field = UITextField()
    private var line2Field = UITextField()
    private var cityField = UITextField()
    private var stateField = UITextField()
    private var postalField = UITextField()
    private var countryField = UITextField()
    private let defaultSwitch = UISwitch()

    // Helpers (validation labels)
    private let labelError = UILabel()
    private let fullNameError = UILabel()
    private let phoneError = UILabel()
    private let line1Error = UILabel()
    private let cityError = UILabel()
    private let stateError = UILabel()
    private let postalError = UILabel()
    private let countryError = UILabel()

    // Actions
    private let prefillLocationButton = UIButton(type: .system)

    // Service
    private let service: AddressServicing = AddressService()

    // Geocoder
    private let geocoder = CLGeocoder()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = existing == nil ? "Add Address" : "Edit Address"
        view.backgroundColor = .systemGroupedBackground

        setupNavBar()
        setupLayout()
        setupSections()
        setupFields()
        setupValidationLabels()
        wireFieldDelegates()
        applyPrefill()
        if let ex = existing { populate(from: ex) }
        updateSaveEnabled()

        // Dismiss keyboard on scroll tap
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        scroll.addGestureRecognizer(tap)
    }

    private func setupNavBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Save",
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )
    }

    private func setupLayout() {
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        content.axis = .vertical
        content.alignment = .fill
        content.spacing = 16
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -16),
            content.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -32)
        ])
    }

    private func addSection(title: String, stack: UIStackView) {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 12
        container.layer.masksToBounds = true

        let v = UIStackView()
        v.axis = .vertical
        v.alignment = .fill
        v.spacing = 10
        v.translatesAutoresizingMaskIntoConstraints = false

        let header = UILabel()
        header.text = title
        header.font = .systemFont(ofSize: 15, weight: .semibold)
        header.textColor = .secondaryLabel

        v.addArrangedSubview(header)
        v.addArrangedSubview(stack)

        container.addSubview(v)
        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            v.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            v.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            v.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        content.addArrangedSubview(container)
    }

    private func setupSections() {
        contactSection.axis = .vertical
        contactSection.alignment = .fill
        contactSection.spacing = 10

        addressSection.axis = .vertical
        addressSection.alignment = .fill
        addressSection.spacing = 10

        defaultSection.axis = .vertical
        defaultSection.alignment = .fill
        defaultSection.spacing = 10

        addSection(title: "Contact", stack: contactSection)
        addSection(title: "Address", stack: addressSection)
        addSection(title: "Default", stack: defaultSection)
    }

    // Improved styled text field
    private func makeStyledField(_ placeholder: String,
                                 keyboard: UIKeyboardType = .default,
                                 contentType: UITextContentType? = nil,
                                 returnKey: UIReturnKeyType = .next,
                                 autocap: UITextAutocapitalizationType = .words) -> UITextField {
        let tf = PaddedTextField()
        tf.borderStyle = .none
        tf.placeholder = placeholder
        tf.keyboardType = keyboard
        tf.textContentType = contentType
        tf.autocapitalizationType = autocap
        tf.autocorrectionType = .no
        tf.backgroundColor = UIColor.secondarySystemBackground
        tf.returnKeyType = returnKey
        tf.clearButtonMode = .whileEditing
        tf.layer.cornerRadius = 10
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor.separator.withAlphaComponent(0.6).cgColor
        tf.font = .systemFont(ofSize: 16)
        tf.textColor = .label

        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

        tf.addTarget(self, action: #selector(editingDidBegin(_:)), for: .editingDidBegin)
        tf.addTarget(self, action: #selector(editingDidEnd(_:)), for: .editingDidEnd)

        return tf
    }

    private func labeledRow(label: String, field: UIView) -> UIStackView {
        let title = UILabel()
        title.text = label
        title.font = .systemFont(ofSize: 14, weight: .medium)
        title.textColor = .label

        let row = UIStackView(arrangedSubviews: [title, field])
        row.axis = .vertical
        row.alignment = .fill
        row.spacing = 6
        return row
    }

    private func setupFields() {
        // Contact
        labelField = makeStyledField("Home, Office, Hostel…",
                                     keyboard: .default,
                                     contentType: .nickname,
                                     returnKey: .next,
                                     autocap: .words)

        fullNameField = makeStyledField("Enter full name",
                                        keyboard: .default,
                                        contentType: .name,
                                        returnKey: .next,
                                        autocap: .words)

        phoneField = makeStyledField("Enter phone number",
                                     keyboard: .phonePad,
                                     contentType: .telephoneNumber,
                                     returnKey: .next,
                                     autocap: .none)
        phoneField.smartDashesType = .no
        phoneField.smartQuotesType = .no
        phoneField.smartInsertDeleteType = .no
        phoneField.inputAccessoryView = makeDoneToolbar()

        contactSection.addArrangedSubview(labeledRow(label: "Label (optional)", field: labelField))
        contactSection.addArrangedSubview(labeledRow(label: "Full name", field: fullNameField))
        contactSection.addArrangedSubview(labeledRow(label: "Phone", field: phoneField))

        // Address fields
        line1Field = makeStyledField("House/Flat, Street",
                                     keyboard: .default,
                                     contentType: .fullStreetAddress,
                                     returnKey: .next,
                                     autocap: .words)
        line2Field = makeStyledField("Landmark, Area (optional)",
                                     keyboard: .default,
                                     contentType: .fullStreetAddress,
                                     returnKey: .next,
                                     autocap: .words)
        cityField = makeStyledField("City",
                                    keyboard: .default,
                                    contentType: .addressCity,
                                    returnKey: .next,
                                    autocap: .words)
        stateField = makeStyledField("State",
                                     keyboard: .default,
                                     contentType: .addressState,
                                     returnKey: .next,
                                     autocap: .words)
        postalField = makeStyledField("Postal code",
                                      keyboard: .numbersAndPunctuation,
                                      contentType: .postalCode,
                                      returnKey: .next,
                                      autocap: .none)
        postalField.smartDashesType = .no
        postalField.smartQuotesType = .no
        postalField.smartInsertDeleteType = .no

        countryField = makeStyledField("Country",
                                       keyboard: .default,
                                       contentType: .countryName,
                                       returnKey: .done,
                                       autocap: .words)

        // Rows
        let line1Row = labeledRow(label: "Address line 1", field: line1Field)
        let line2Row = labeledRow(label: "Address line 2 (optional)", field: line2Field)
        addressSection.addArrangedSubview(line1Row)
        addressSection.addArrangedSubview(line2Row)

        let rowCityState = UIStackView()
        rowCityState.axis = .horizontal
        rowCityState.alignment = .fill
        rowCityState.spacing = 10
        let cityCol = labeledRow(label: "City", field: cityField)
        let stateCol = labeledRow(label: "State", field: stateField)
        rowCityState.addArrangedSubview(cityCol)
        rowCityState.addArrangedSubview(stateCol)
        cityCol.widthAnchor.constraint(equalTo: stateCol.widthAnchor).isActive = true
        addressSection.addArrangedSubview(rowCityState)

        let rowPostalCountry = UIStackView()
        rowPostalCountry.axis = .horizontal
        rowPostalCountry.alignment = .fill
        rowPostalCountry.spacing = 10
        let postalCol = labeledRow(label: "Postal code", field: postalField)
        let countryCol = labeledRow(label: "Country", field: countryField)
        rowPostalCountry.addArrangedSubview(postalCol)
        rowPostalCountry.addArrangedSubview(countryCol)
        postalCol.widthAnchor.constraint(equalTo: countryCol.widthAnchor).isActive = true
        addressSection.addArrangedSubview(rowPostalCountry)

        // Prefill location button
        prefillLocationButton.setTitle("Use current location to prefill City/State/Country", for: .normal)
        prefillLocationButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        prefillLocationButton.addTarget(self, action: #selector(prefillFromLocation), for: .touchUpInside)
        addressSection.addArrangedSubview(prefillLocationButton)

        // Default row
        let h = UIStackView()
        h.axis = .horizontal
        h.alignment = .center
        h.spacing = 8
        let defaultLabel = UILabel()
        defaultLabel.text = "Set as default"
        defaultLabel.font = .systemFont(ofSize: 16, weight: .regular)
        h.addArrangedSubview(defaultLabel)
        h.addArrangedSubview(UIView())
        h.addArrangedSubview(defaultSwitch)
        defaultSection.addArrangedSubview(h)
    }

    private func setupValidationLabels() {
        [labelError, fullNameError, phoneError, line1Error, cityError, stateError, postalError, countryError].forEach {
            $0.textColor = .systemRed
            $0.font = .systemFont(ofSize: 12, weight: .regular)
            $0.numberOfLines = 0
            $0.isHidden = true
        }

        if let fullNameRowIndex = contactSection.arrangedSubviews.firstIndex(where: { ($0 as? UIStackView)?.arrangedSubviews.first is UILabel && (($0 as? UIStackView)?.arrangedSubviews.first as? UILabel)?.text == "Full name" }) {
            contactSection.insertArrangedSubview(fullNameError, at: fullNameRowIndex + 1)
        } else {
            contactSection.addArrangedSubview(fullNameError)
        }

        if let phoneRowIndex = contactSection.arrangedSubviews.firstIndex(where: { ($0 as? UIStackView)?.arrangedSubviews.first is UILabel && (($0 as? UIStackView)?.arrangedSubviews.first as? UILabel)?.text == "Phone" }) {
            contactSection.insertArrangedSubview(phoneError, at: phoneRowIndex + 1)
        } else {
            contactSection.addArrangedSubview(phoneError)
        }

        if addressSection.arrangedSubviews.indices.contains(0) {
            addressSection.insertArrangedSubview(line1Error, at: 1)
        } else {
            addressSection.addArrangedSubview(line1Error)
        }

        if let cityStateIndex = addressSection.arrangedSubviews.firstIndex(where: { ($0 as? UIStackView)?.axis == .horizontal }) {
            addressSection.insertArrangedSubview(cityError, at: cityStateIndex + 1)
            addressSection.insertArrangedSubview(stateError, at: cityStateIndex + 2)
        } else {
            addressSection.addArrangedSubview(cityError)
            addressSection.addArrangedSubview(stateError)
        }

        if let postalCountryIndex = addressSection.arrangedSubviews.lastIndex(where: { ($0 as? UIStackView)?.axis == .horizontal }) {
            addressSection.insertArrangedSubview(postalError, at: postalCountryIndex + 1)
            addressSection.insertArrangedSubview(countryError, at: postalCountryIndex + 2)
        } else {
            addressSection.addArrangedSubview(postalError)
            addressSection.addArrangedSubview(countryError)
        }
    }

    private func wireFieldDelegates() {
        [labelField, fullNameField, phoneField, line1Field, line2Field, cityField, stateField, postalField, countryField].forEach {
            $0.delegate = self
            $0.addTarget(self, action: #selector(textDidChange(_:)), for: .editingChanged)
        }
    }

    private func applyPrefill() {
        if existing == nil {
            if let c = prefillCity, cityField.text?.isEmpty ?? true { cityField.text = c }
            if let s = prefillState, stateField.text?.isEmpty ?? true { stateField.text = s }
            if let ctry = prefillCountry, countryField.text?.isEmpty ?? true { countryField.text = ctry }
            if countryField.text?.isEmpty ?? true { countryField.text = "India" }
        }
    }

    private func populate(from a: Address) {
        labelField.text = a.label
        fullNameField.text = a.full_name
        phoneField.text = a.phone
        line1Field.text = a.address_line1
        line2Field.text = a.address_line2
        cityField.text = a.city
        stateField.text = a.state
        postalField.text = a.postal_code
        countryField.text = a.country
        defaultSwitch.isOn = a.is_default
    }

    private func validate() -> Bool {
        var ok = true

        func required(_ tf: UITextField, _ err: UILabel, _ message: String) {
            let t = tf.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let valid = !t.isEmpty
            err.text = valid ? nil : message
            err.isHidden = valid
            if !valid { ok = false }
        }

        required(fullNameField, fullNameError, "Full name is required.")
        required(phoneField, phoneError, "Phone number is required.")
        required(line1Field, line1Error, "Address line 1 is required.")
        required(cityField, cityError, "City is required.")
        required(stateField, stateError, "State is required.")
        required(postalField, postalError, "Postal code is required.")
        required(countryField, countryError, "Country is required.")

        if ok == false {
            if !fullNameError.isHidden { scrollToView(fullNameField); return false }
            if !phoneError.isHidden { scrollToView(phoneField); return false }
            if !line1Error.isHidden { scrollToView(line1Field); return false }
            if !cityError.isHidden { scrollToView(cityField); return false }
            if !stateError.isHidden { scrollToView(stateField); return false }
            if !postalError.isHidden { scrollToView(postalField); return false }
            if !countryError.isHidden { scrollToView(countryField); return false }
        }
        return ok
    }

    private func updateSaveEnabled() {
        let requiredFilled = [fullNameField, phoneField, line1Field, cityField, stateField, postalField, countryField].allSatisfy {
            !($0.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }
        navigationItem.rightBarButtonItem?.isEnabled = requiredFilled
    }

    private func scrollToView(_ v: UIView) {
        let rect = v.convert(v.bounds, to: scroll)
        scroll.scrollRectToVisible(rect.insetBy(dx: 0, dy: -20), animated: true)
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }

    @objc private func editingDidBegin(_ sender: UITextField) {
        sender.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.9).cgColor
        sender.layer.borderWidth = 1.0
    }

    @objc private func editingDidEnd(_ sender: UITextField) {
        sender.layer.borderColor = UIColor.separator.withAlphaComponent(0.6).cgColor
        sender.layer.borderWidth = 1.0
    }

    @objc private func textDidChange(_ sender: UITextField) {
        let isEmpty = (sender.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch sender {
        case fullNameField: fullNameError.isHidden = !isEmpty
        case phoneField: phoneError.isHidden = !isEmpty
        case line1Field: line1Error.isHidden = !isEmpty
        case cityField: cityError.isHidden = !isEmpty
        case stateField: stateError.isHidden = !isEmpty
        case postalField: postalError.isHidden = !isEmpty
        case countryField: countryError.isHidden = !isEmpty
        default: break
        }
        updateSaveEnabled()
    }

    private func makeDoneToolbar() -> UIToolbar {
        let tb = UIToolbar()
        tb.sizeToFit()
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))
        tb.items = [flex, done]
        return tb
    }

    @objc private func prefillFromLocation() {
        Task {
            do {
                let loc = try await AppLocationManager.shared.currentLocation()
                let name = try await AppLocationManager.shared.placename(for: loc)
                let parts = name.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                await MainActor.run {
                    if parts.count >= 1 { self.cityField.text = parts[0] }
                    if parts.count >= 2 { self.stateField.text = parts[1] }
                    if parts.count >= 3 { self.countryField.text = parts[2] }
                    self.updateSaveEnabled()
                }
            } catch {
                await MainActor.run {
                    let ac = UIAlertController(title: "Location", message: error.localizedDescription, preferredStyle: .alert)
                    ac.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(ac, animated: true)
                }
            }
        }
    }

    // Build full and fallback address strings for geocoding
    private func fullAddressString() -> String {
        let parts = [
            line1Field.text,
            line2Field.text,
            cityField.text,
            stateField.text,
            postalField.text,
            countryField.text
        ]
        return parts
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private func cityStateCountryString() -> String {
        let parts = [
            cityField.text,
            stateField.text,
            countryField.text
        ]
        return parts
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    // Try multiple strategies to obtain coordinates
    private func resolveCoordinatesForSave() async -> (Double?, Double?) {
        // 1) Full address
        let primary = fullAddressString()
        if !primary.isEmpty {
            do {
                let placemarks = try await geocoder.geocodeAddressString(primary)
                if let loc = placemarks.first?.location {
                    print("[Address] Geocoded full address OK: \(primary) -> \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
                    return (loc.coordinate.latitude, loc.coordinate.longitude)
                } else {
                    print("[Address] Geocode returned no results for full address: \(primary)")
                }
            } catch {
                print("[Address] Geocode error for full address '\(primary)': \(error.localizedDescription)")
            }
        }

        // 2) Fallback: city, state, country
        let fallback = cityStateCountryString()
        if !fallback.isEmpty {
            do {
                let placemarks = try await geocoder.geocodeAddressString(fallback)
                if let loc = placemarks.first?.location {
                    print("[Address] Geocoded fallback OK: \(fallback) -> \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
                    return (loc.coordinate.latitude, loc.coordinate.longitude)
                } else {
                    print("[Address] Geocode returned no results for fallback: \(fallback)")
                }
            } catch {
                print("[Address] Geocode error for fallback '\(fallback)': \(error.localizedDescription)")
            }
        }

        // 3) Optional: as a last resort, try current GPS (if allowed)
        do {
            let loc = try await AppLocationManager.shared.currentLocation()
            print("[Address] Using current GPS as last resort: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
            return (loc.coordinate.latitude, loc.coordinate.longitude)
        } catch {
            print("[Address] GPS fallback not available: \(error.localizedDescription)")
        }

        // Failed to resolve coords; proceed without
        return (nil, nil)
    }

    @objc private func saveTapped() {
        view.endEditing(true)
        guard validate() else { return }

        Task {
            // 1) Build the payload basics
            let label = emptyToNil(labelField.text)
            let fullName = fullNameField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
            let phone = phoneField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
            let line1 = line1Field.text!.trimmingCharacters(in: .whitespacesAndNewlines)
            let line2 = emptyToNil(line2Field.text)
            let city = cityField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
            let state = stateField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
            let postal = postalField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
            let country = countryField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
            let isDefault = defaultSwitch.isOn

            // 2) Resolve coordinates with robust fallbacks
            let (lat, lon) = await resolveCoordinatesForSave()
            print("[Address] Final coords to save: lat=\(String(describing: lat)) lon=\(String(describing: lon))")

            do {
                let userId = try await service.currentUserId()

                if let existing = existing {
                    // Update
                    let patch = AddressPatch(
                        label: label,
                        full_name: fullName,
                        phone: phone,
                        address_line1: line1,
                        address_line2: line2,
                        city: city,
                        state: state,
                        postal_code: postal,
                        country: country,
                        is_default: isDefault,
                        latitude: lat,
                        longitude: lon
                    )
                    let updated = try await service.update(id: existing.id, patch: patch)
                    await MainActor.run {
                        self.onSaved?(updated)
                        self.navigationController?.popViewController(animated: true)
                    }
                } else {
                    // Create
                    let input = AddressInput(
                        user_id: userId,
                        label: label,
                        full_name: fullName,
                        phone: phone,
                        address_line1: line1,
                        address_line2: line2,
                        city: city,
                        state: state,
                        postal_code: postal,
                        country: country,
                        is_default: isDefault,
                        latitude: lat,
                        longitude: lon
                    )
                    let created = try await service.create(input)
                    await MainActor.run {
                        self.onSaved?(created)
                        self.navigationController?.popViewController(animated: true)
                    }
                }
            } catch {
                await MainActor.run { self.presentAlert(error.localizedDescription) }
            }
        }
    }

    private func emptyToNil(_ s: String?) -> String? {
        let t = (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private func presentAlert(_ message: String) {
        let ac = UIAlertController(title: "Address", message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension ManualAddressViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case labelField: fullNameField.becomeFirstResponder()
        case fullNameField: phoneField.becomeFirstResponder()
        case phoneField: line1Field.becomeFirstResponder()
        case line1Field: line2Field.becomeFirstResponder()
        case line2Field: cityField.becomeFirstResponder()
        case cityField: stateField.becomeFirstResponder()
        case stateField: postalField.becomeFirstResponder()
        case postalField: countryField.becomeFirstResponder()
        default:
            textField.resignFirstResponder()
        }
        return true
    }
}

// Simple padded text field to add left/right insets
private final class PaddedTextField: UITextField {
    private let inset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: inset)
    }
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: inset)
    }
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: inset)
    }
}

