// swift-extract-localization: off
//
//  SupportTicketListViewController.swift
//  RentiWise
//
//  Ticket list view — shows all support tickets for the current user
//  grouped by Active (open/in_progress) and Past (resolved/closed).
//

import UIKit
import Supabase

final class SupportTicketListViewController: UITableViewController {

    // MARK: - Data

    private var activeTickets: [SupportTicketSummary] = []
    private var pastTickets: [SupportTicketSummary] = []
    private var isLoading = true
    private var errorMessage: String?

    private let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)

    // MARK: - Lightweight model for the list

    private struct SupportTicketSummary {
        let id: String
        let subject: String
        let status: String
        let priority: String
        let createdAt: Date
        let lastMessagePreview: String?
    }

    // MARK: - Lifecycle

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Support"
        view.backgroundColor = .systemGroupedBackground
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TicketCell")

        // New ticket button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus.message"),
            style: .plain,
            target: self,
            action: #selector(newTicketTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = brandTeal

        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)

        Task { await loadTickets() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = true
        Task { await loadTickets() }
    }

    // MARK: - Data Loading

    private func loadTickets() async {
        guard let userId = await SupabaseManager.shared.currentUserId() else {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Please sign in to view support tickets."
                self.tableView.reloadData()
            }
            return
        }

        do {
            struct TicketRow: Decodable {
                let id: String
                let subject: String
                let status: String
                let priority: String
                let created_at: String
            }

            let rows: [TicketRow] = try await SupabaseManager.shared.client
                .from("support_tickets")
                .select("id, subject, status, priority, created_at")
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value

            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let isoFallback = ISO8601DateFormatter()

            let summaries: [SupportTicketSummary] = rows.map { row in
                let date = iso.date(from: row.created_at) ?? isoFallback.date(from: row.created_at) ?? Date()
                return SupportTicketSummary(
                    id: row.id,
                    subject: row.subject,
                    status: row.status,
                    priority: row.priority,
                    createdAt: date,
                    lastMessagePreview: nil
                )
            }

            await MainActor.run {
                self.activeTickets = summaries.filter { $0.status == "open" || $0.status == "in_progress" }
                self.pastTickets = summaries.filter { $0.status == "resolved" || $0.status == "closed" }
                self.isLoading = false
                self.errorMessage = nil
                self.tableView.reloadData()
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                self.tableView.reloadData()
            }
        }
    }

    // MARK: - Actions

    @objc private func newTicketTapped() {
        let vc = SupportChatViewController()
        vc.title = "New Ticket"
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func handleRefresh() {
        Task {
            await loadTickets()
            await MainActor.run { self.refreshControl?.endRefreshing() }
        }
    }

    // MARK: - Table View DataSource

    private enum Section: Int, CaseIterable {
        case active
        case past
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        if isLoading || errorMessage != nil { return 1 }
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isLoading { return 1 }
        if errorMessage != nil { return 1 }

        guard let sectionType = Section(rawValue: section) else { return 0 }
        switch sectionType {
        case .active:
            return max(activeTickets.count, 1) // empty state row
        case .past:
            return pastTickets.count
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if isLoading || errorMessage != nil { return nil }
        guard let sectionType = Section(rawValue: section) else { return nil }
        switch sectionType {
        case .active: return "Active Tickets"
        case .past: return pastTickets.isEmpty ? nil : "Past Tickets"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TicketCell", for: indexPath)
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.accessoryType = .none
        cell.selectionStyle = .default

        // Loading state
        if isLoading {
            cell.selectionStyle = .none
            cell.accessoryType = .none
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            spinner.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(spinner)
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                spinner.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 20),
                spinner.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -20)
            ])
            return cell
        }

        // Error state
        if let error = errorMessage {
            cell.selectionStyle = .none
            let lbl = UILabel()
            lbl.text = error
            lbl.textColor = .systemRed
            lbl.font = .preferredFont(forTextStyle: .footnote)
            lbl.numberOfLines = 0
            lbl.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(lbl)
            NSLayoutConstraint.activate([
                lbl.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                lbl.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                lbl.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
                lbl.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12)
            ])
            return cell
        }

        guard let sectionType = Section(rawValue: indexPath.section) else { return cell }

        // Active section empty state
        if sectionType == .active && activeTickets.isEmpty {
            cell.selectionStyle = .none
            cell.accessoryType = .none
            let lbl = UILabel()
            lbl.text = "No active tickets. Tap + to create one."
            lbl.textColor = .secondaryLabel
            lbl.font = .preferredFont(forTextStyle: .subheadline)
            lbl.textAlignment = .center
            lbl.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(lbl)
            NSLayoutConstraint.activate([
                lbl.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                lbl.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                lbl.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 16),
                lbl.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -16)
            ])
            return cell
        }

        // Ticket cell
        let ticket: SupportTicketSummary
        switch sectionType {
        case .active: ticket = activeTickets[indexPath.row]
        case .past: ticket = pastTickets[indexPath.row]
        }

        cell.accessoryType = .disclosureIndicator
        configureTicketCell(cell, with: ticket)
        return cell
    }

    private func configureTicketCell(_ cell: UITableViewCell, with ticket: SupportTicketSummary) {
        // Status badge
        let badgeLabel = UILabel()
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 4
        badgeLabel.layer.masksToBounds = true

        switch ticket.status {
        case "open":
            badgeLabel.text = "  OPEN  "
            badgeLabel.textColor = .white
            badgeLabel.backgroundColor = .systemGreen
        case "in_progress":
            badgeLabel.text = "  IN PROGRESS  "
            badgeLabel.textColor = .white
            badgeLabel.backgroundColor = .systemOrange
        case "resolved":
            badgeLabel.text = "  RESOLVED  "
            badgeLabel.textColor = .white
            badgeLabel.backgroundColor = .systemBlue
        case "closed":
            badgeLabel.text = "  CLOSED  "
            badgeLabel.textColor = .white
            badgeLabel.backgroundColor = .systemGray
        default:
            badgeLabel.text = "  \(ticket.status.uppercased())  "
            badgeLabel.textColor = .white
            badgeLabel.backgroundColor = .systemGray
        }

        // Subject
        let subjectLabel = UILabel()
        subjectLabel.translatesAutoresizingMaskIntoConstraints = false
        subjectLabel.text = ticket.subject
        subjectLabel.font = .systemFont(ofSize: 16, weight: .medium)
        subjectLabel.textColor = .label
        subjectLabel.numberOfLines = 2

        // Date
        let dateLabel = UILabel()
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        dateLabel.text = formatter.localizedString(for: ticket.createdAt, relativeTo: Date())
        dateLabel.font = .systemFont(ofSize: 12)
        dateLabel.textColor = .secondaryLabel

        // Priority icon
        let priorityIcon = UILabel()
        priorityIcon.translatesAutoresizingMaskIntoConstraints = false
        switch ticket.priority {
        case "urgent": priorityIcon.text = "🔴"
        case "high": priorityIcon.text = "🟠"
        case "medium": priorityIcon.text = "🟡"
        default: priorityIcon.text = "🟢"
        }
        priorityIcon.font = .systemFont(ofSize: 12)

        cell.contentView.addSubview(subjectLabel)
        cell.contentView.addSubview(badgeLabel)
        cell.contentView.addSubview(dateLabel)
        cell.contentView.addSubview(priorityIcon)

        NSLayoutConstraint.activate([
            subjectLabel.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
            subjectLabel.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            subjectLabel.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -80),

            badgeLabel.topAnchor.constraint(equalTo: subjectLabel.bottomAnchor, constant: 6),
            badgeLabel.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            badgeLabel.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),

            priorityIcon.centerYAnchor.constraint(equalTo: badgeLabel.centerYAnchor),
            priorityIcon.leadingAnchor.constraint(equalTo: badgeLabel.trailingAnchor, constant: 8),

            dateLabel.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 14),
            dateLabel.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
        ])
    }

    // MARK: - Table View Delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard !isLoading, errorMessage == nil else { return }
        guard let sectionType = Section(rawValue: indexPath.section) else { return }

        let ticket: SupportTicketSummary?
        switch sectionType {
        case .active:
            ticket = activeTickets.isEmpty ? nil : activeTickets[indexPath.row]
        case .past:
            ticket = pastTickets.isEmpty ? nil : pastTickets[indexPath.row]
        }

        guard let t = ticket else { return }

        let vc = SupportChatViewController()
        vc.preloadedTicketId = t.id
        vc.title = t.subject
        vc.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(vc, animated: true)
    }
}
