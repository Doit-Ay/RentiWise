import UIKit

final class ManageAddressesViewController: UIViewController {

    var onPicked: ((Address) -> Void)?

    private let table = UITableView(frame: .zero, style: .insetGrouped)
    private var addresses: [Address] = []
    private let service: AddressServicing = AddressService()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Saved Addresses"
        view.backgroundColor = .systemGroupedBackground
        setupTable()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add,
                                                            target: self,
                                                            action: #selector(addTapped))
        Task { await load() }
    }

    private func setupTable() {
        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = self
        table.delegate = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(table)
        NSLayoutConstraint.activate([
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func addTapped() {
        let vc = ManualAddressViewController()
        vc.onSaved = { [weak self] _ in Task { await self?.load() } }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func edit(address: Address) {
        let vc = ManualAddressViewController()
        vc.existing = address
        vc.onSaved = { [weak self] _ in Task { await self?.load() } }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func setDefault(address: Address) {
        Task {
            do {
                try await service.setDefault(id: address.id)
                await load()
            } catch {
                await MainActor.run { self.presentError(error.localizedDescription) }
            }
        }
    }

    private func presentError(_ message: String) {
        let ac = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }

    @MainActor
    private func reloadUI() {
        table.reloadData()
    }

    private func deleteAddress(at indexPath: IndexPath) {
        let addr = addresses[indexPath.row]
        Task {
            do {
                try await service.delete(id: addr.id)
                await load()
            } catch {
                await MainActor.run { self.presentError(error.localizedDescription) }
            }
        }
    }

    @MainActor
    private func apply(_ list: [Address]) {
        addresses = list
        table.reloadData()
    }

    private func load() async {
        do {
            let list = try await service.list()
            await MainActor.run { self.apply(list) }
        } catch {
            await MainActor.run { self.presentError(error.localizedDescription) }
        }
    }
}

extension ManageAddressesViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 1 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { addresses.count }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let addr = addresses[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        let title = (addr.label?.isEmpty == false ? "\(addr.label!) — " : "") + addr.address_line1
        config.text = title
        config.secondaryText = "\(addr.city), \(addr.state) \(addr.postal_code)"
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        if addr.is_default {
            cell.imageView?.image = UIImage(systemName: "bookmark.fill")
            cell.imageView?.tintColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)  // Brand teal
        } else {
            cell.imageView?.image = UIImage(systemName: "bookmark")
            cell.imageView?.tintColor = .secondaryLabel
        }
        return cell
    }

    // NEW: open detail screen on tap
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let addr = addresses[indexPath.row]
        let detail = AddressDetailViewController(address: addr)
        detail.onChanged = { [weak self] _ in
            Task { await self?.load() }
        }
        navigationController?.pushViewController(detail, animated: true)
    }

    // Keep swipe actions: Edit, Delete, Set Default
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let addr = addresses[indexPath.row]

        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
            self?.deleteAddress(at: indexPath)
            done(true)
        }

        let edit = UIContextualAction(style: .normal, title: "Edit") { [weak self] _, _, done in
            self?.edit(address: addr)
            done(true)
        }
        edit.backgroundColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)  // Brand teal

        let makeDefault = UIContextualAction(style: .normal, title: "Default") { [weak self] _, _, done in
            self?.setDefault(address: addr)
            done(true)
        }
        makeDefault.backgroundColor = .systemGreen

        return UISwipeActionsConfiguration(actions: [delete, edit, makeDefault])
    }
}
