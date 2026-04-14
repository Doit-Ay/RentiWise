import UIKit

final class AddressDetailViewController: UIViewController {

    // Input address to display
    var address: Address {
        didSet { if isViewLoaded { applyAddress() } }
    }

    // Optional callback when the address was edited (so parent can refresh)
    var onChanged: ((Address) -> Void)?

    // UI
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let contactSection = UIStackView()
    private let addressSection = UIStackView()
    private let metaSection = UIStackView()

    // Service
    private let service: AddressServicing = AddressService()

    // MARK: - Init
    init(address: Address) {
        self.address = address
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) {
        self.address = Address(
            id: UUID().uuidString,
            user_id: "",
            label: nil,
            full_name: nil,
            phone: nil,
            address_line1: "",
            address_line2: nil,
            city: "",
            state: "",
            postal_code: "",
            country: "",
            is_default: false,
            created_at: nil,
            latitude: nil,
            longitude: nil
        )
        super.init(coder: coder)
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Address"
        view.backgroundColor = .systemGroupedBackground

        setupNavBar()
        setupLayout()
        setupSections()
        applyAddress()
    }

    private func setupNavBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Edit",
            style: .plain,
            target: self,
            action: #selector(editTapped)
        )
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
    }

    /// Brand teal used throughout the app
    private var brandTeal: UIColor {
        UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)
    }

    private func addCard(title: String, stack: UIStackView) {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 12
        container.layer.masksToBounds = true
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor(red: 0xD6/255.0, green: 0xEB/255.0, blue: 0xEF/255.0, alpha: 1.0).cgColor

        let inner = UIStackView()
        inner.axis = .vertical
        inner.alignment = .fill
        inner.spacing = 10
        inner.translatesAutoresizingMaskIntoConstraints = false

        let header = UILabel()
        header.text = title
        header.font = .systemFont(ofSize: 15, weight: .semibold)
        header.textColor = brandTeal

        inner.addArrangedSubview(header)
        inner.addArrangedSubview(stack)

        container.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            inner.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            inner.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            inner.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        contentStack.addArrangedSubview(container)
    }

    private func setupSections() {
        contactSection.axis = .vertical
        contactSection.alignment = .fill
        contactSection.spacing = 8

        addressSection.axis = .vertical
        addressSection.alignment = .fill
        addressSection.spacing = 8

        metaSection.axis = .vertical
        metaSection.alignment = .fill
        metaSection.spacing = 8

        addCard(title: "Contact", stack: contactSection)
        addCard(title: "Address", stack: addressSection)
        addCard(title: "Options", stack: metaSection)

        // Buttons row (Set Default / Delete)
        let actionsRow = UIStackView()
        actionsRow.axis = .horizontal
        actionsRow.alignment = .fill
        actionsRow.spacing = 12
        actionsRow.distribution = .fillEqually

        // Default button: theme color filled, white semibold 18, corner radius 14, height 44
        let defaultButton = UIButton(type: .system)
        defaultButton.setTitle(address.is_default ? "Default Address" : "Set as Default", for: .normal)
        defaultButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        defaultButton.layer.cornerRadius = 14
        defaultButton.layer.masksToBounds = true
        defaultButton.backgroundColor = brandTeal
        defaultButton.setTitleColor(.white, for: .normal)
        defaultButton.layer.borderWidth = 0
        defaultButton.addTarget(self, action: #selector(makeDefaultTapped), for: .touchUpInside)

        // Delete button: theme color outline, red text semibold 18, corner radius 14, height 44
        let deleteButton = UIButton(type: .system)
        deleteButton.setTitle("Delete", for: .normal)
        deleteButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        deleteButton.layer.cornerRadius = 14
        deleteButton.layer.masksToBounds = true
        deleteButton.backgroundColor = .clear
        deleteButton.setTitleColor(.systemRed, for: .normal)
        deleteButton.layer.borderWidth = 1.5
        deleteButton.layer.borderColor = brandTeal.cgColor
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)

        actionsRow.addArrangedSubview(defaultButton)
        actionsRow.addArrangedSubview(deleteButton)

        let actionsContainer = UIView()
        actionsContainer.addSubview(actionsRow)
        actionsRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            actionsRow.leadingAnchor.constraint(equalTo: actionsContainer.leadingAnchor),
            actionsRow.trailingAnchor.constraint(equalTo: actionsContainer.trailingAnchor),
            actionsRow.topAnchor.constraint(equalTo: actionsContainer.topAnchor),
            actionsRow.bottomAnchor.constraint(equalTo: actionsContainer.bottomAnchor),
            actionsRow.heightAnchor.constraint(equalToConstant: 44)
        ])
        contentStack.addArrangedSubview(actionsContainer)
    }

    // makeActionButton removed — buttons are now styled directly in setupSections()

    private func labeledValue(_ label: String, _ value: String?) -> UIStackView {
        let title = UILabel()
        title.text = label
        title.font = .systemFont(ofSize: 13, weight: .medium)
        title.textColor = .secondaryLabel

        let val = UILabel()
        let display = (value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? value! : "—"
        val.text = display
        val.font = .systemFont(ofSize: 16, weight: .regular)
        val.textColor = .label
        val.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [title, val])
        row.axis = .vertical
        row.spacing = 4
        return row
    }

    @MainActor
    private func applyAddress() {
        // Clear sections
        [contactSection, addressSection, metaSection].forEach { section in
            section.arrangedSubviews.forEach {
                section.removeArrangedSubview($0)
                $0.removeFromSuperview()
            }
        }

        // Contact details
        contactSection.addArrangedSubview(labeledValue("Label", address.label))
        contactSection.addArrangedSubview(labeledValue("Full name", address.full_name))
        contactSection.addArrangedSubview(labeledValue("Phone", address.phone))

        // Address details
        addressSection.addArrangedSubview(labeledValue("Address line 1", address.address_line1))
        addressSection.addArrangedSubview(labeledValue("Address line 2", address.address_line2))
        addressSection.addArrangedSubview(labeledValue("City", address.city))
        addressSection.addArrangedSubview(labeledValue("State", address.state))
        addressSection.addArrangedSubview(labeledValue("Postal code", address.postal_code))
        addressSection.addArrangedSubview(labeledValue("Country", address.country))

        // Meta
        metaSection.addArrangedSubview(labeledValue("Default", address.is_default ? "Yes" : "No"))
        metaSection.addArrangedSubview(labeledValue("Created", formattedDate(from: address.created_at)))
    }

    private func formattedDate(from string: String?) -> String {
        guard let string = string else { return "—" }
        // Attempt to parse standard ISO8601
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            let displayFmt = DateFormatter()
            displayFmt.dateStyle = .medium
            displayFmt.timeStyle = .short
            return displayFmt.string(from: date)
        }
        return string
    }

    // MARK: - Actions

    @objc private func editTapped() {
        let vc = ManualAddressViewController()
        vc.existing = address
        vc.onSaved = { [weak self] updated in
            guard let self = self else { return }
            self.address = updated
            self.onChanged?(updated)
            self.navigationController?.popViewController(animated: true)
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func makeDefaultTapped() {
        Task {
            do {
                try await service.setDefault(id: address.id)
                // Refresh list from backend to show current is_default
                let list = try await service.list()
                if let refreshed = list.first(where: { $0.id == address.id }) {
                    await MainActor.run {
                        self.address = refreshed
                        self.onChanged?(refreshed)
                        self.updateDefaultButtonTitle()
                    }
                }
            } catch {
                await MainActor.run { self.presentAlert("Failed to set default.\n\(error.localizedDescription)") }
            }
        }
    }

    private func updateDefaultButtonTitle() {
        // Update the button title and style in the last actions row
        if let actionsContainer = contentStack.arrangedSubviews.last,
           let actionsRow = actionsContainer.subviews.first as? UIStackView,
           let defaultButton = actionsRow.arrangedSubviews.first as? UIButton {
            defaultButton.setTitle(address.is_default ? "Default Address" : "Set as Default", for: .normal)
            defaultButton.backgroundColor = brandTeal
            defaultButton.setTitleColor(.white, for: .normal)
            defaultButton.layer.borderWidth = 0
        }
        // Also refresh the meta section
        applyAddress()
    }

    @objc private func deleteTapped() {
        let ac = UIAlertController(title: "Delete Address",
                                   message: "This cannot be undone.",
                                   preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        ac.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            self?.confirmDelete()
        }))
        present(ac, animated: true)
    }

    private func confirmDelete() {
        Task {
            do {
                try await service.delete(id: address.id)
                await MainActor.run {
                    self.onChanged?(self.address) // signal parent to refresh
                    self.navigationController?.popViewController(animated: true)
                }
            } catch {
                await MainActor.run { self.presentAlert("Failed to delete.\n\(error.localizedDescription)") }
            }
        }
    }

    private func presentAlert(_ message: String) {
        let ac = UIAlertController(title: "Address", message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
}
