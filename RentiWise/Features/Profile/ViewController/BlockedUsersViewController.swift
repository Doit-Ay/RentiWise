import UIKit

final class BlockedUsersViewController: UITableViewController {

    private let safetyService = CommunitySafetyService.shared
    private var blockedUsers: [BlockedUser] = []

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Blocked Users"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.backgroundColor = .systemGroupedBackground

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadBlockedUsers),
            name: CommunitySafetyService.blockedUsersDidChangeNotification,
            object: nil
        )

        reloadBlockedUsers()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = true
    }

    @objc private func reloadBlockedUsers() {
        blockedUsers = safetyService.blockedUsers()
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(blockedUsers.count, 1)
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard !blockedUsers.isEmpty else { return nil }
        return "Blocked users are hidden from listings, search, and chat until you unblock them."
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        if blockedUsers.isEmpty {
            var config = cell.defaultContentConfiguration()
            config.text = "No blocked users"
            config.secondaryText = "People you block will appear here."
            config.secondaryTextProperties.color = .secondaryLabel
            cell.contentConfiguration = config
            cell.selectionStyle = .none
            cell.accessoryType = .none
            return cell
        }
        guard indexPath.row < blockedUsers.count else { return cell }

        let user = blockedUsers[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = user.displayName
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        config.secondaryText = "Blocked \(formatter.localizedString(for: user.blockedAt, relativeTo: Date()))"
        config.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < blockedUsers.count else { return }

        let user = blockedUsers[indexPath.row]
        let alert = UIAlertController(
            title: "Unblock \(user.displayName)?",
            message: "They will be visible again in listings and chat.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Unblock", style: .destructive) { [weak self] _ in
            self?.safetyService.unblock(userId: user.id)
        })
        present(alert, animated: true)
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        indexPath.row < blockedUsers.count
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.row < blockedUsers.count else { return nil }
        let user = blockedUsers[indexPath.row]
        let unblock = UIContextualAction(style: .normal, title: "Unblock") { [weak self] _, _, completion in
            self?.safetyService.unblock(userId: user.id)
            completion(true)
        }
        unblock.backgroundColor = .systemGreen
        return UISwipeActionsConfiguration(actions: [unblock])
    }
}
