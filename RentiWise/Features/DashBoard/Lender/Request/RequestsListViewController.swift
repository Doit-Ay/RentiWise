//
//  RequestsListViewController.swift
//  RentiWise
//
//  Created by admin99 on 08/12/25.
//

import UIKit
import Supabase

final class RequestsListViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var rows: [RequestWithItem] = []

    // Auto-refresh
    private var refreshTask: Task<Void, Never>?
    private let refreshInterval: Duration = .seconds(12)
    private var refreshObserver: NSObjectProtocol?

    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Requests"

        // Match Categories page look so gaps aren’t white and shadows read cleanly
        view.backgroundColor = .systemGroupedBackground

        setupTable()
        Task { await loadRequests() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Start auto-refresh while visible
        startAutoRefresh()
        // Observe external refresh trigger (e.g., after Accept/Deny elsewhere)
        if refreshObserver == nil {
            refreshObserver = NotificationCenter.default.addObserver(
                forName: Notification.Name("requestsShouldRefresh"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                Task { await self.loadRequests() }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop auto-refresh when leaving
        stopAutoRefresh()
    }

    deinit {
        stopAutoRefresh()
        if let obs = refreshObserver {
            NotificationCenter.default.removeObserver(obs)
            refreshObserver = nil
        }
    }

    private func startAutoRefresh() {
        stopAutoRefresh()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            // Immediate refresh on start to feel responsive
            await self.loadRequests()
            while !Task.isCancelled {
                try? await Task.sleep(for: refreshInterval)
                if Task.isCancelled { break }
                await self.loadRequests()
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Table setup
    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .systemGroupedBackground
        tableView.separatorStyle = .none
        tableView.rowHeight = 130
        tableView.estimatedRowHeight = 130
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0) // nice breathing space

        // Register your existing cell nib
        tableView.register(UINib(nibName: "LenderRequestTableViewCell", bundle: nil), forCellReuseIdentifier: "Request")

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Data
    private func showEmptyStateIfNeeded() {
        if rows.isEmpty {
            let label = UILabel()
            label.text = "No requests yet"
            label.textAlignment = .center
            label.textColor = .secondaryLabel
            label.numberOfLines = 0
            label.font = .systemFont(ofSize: 16, weight: .medium)
            tableView.backgroundView = label
        } else {
            tableView.backgroundView = nil
        }
    }

    private func loadRequests() async {
        guard let userId = await SupabaseManager.shared.currentUserId() else {
            await MainActor.run {
                self.rows = []
                self.tableView.reloadData()
                self.showEmptyStateIfNeeded()
                self.presentLoginAlert()
            }
            return
        }

        // Same select as LenderView.loadMyRequests
        let select =
        """
        id,item_id,owner_id,borrower_id,start_date,end_date,pickup_time,status,created_at,
        items(id,title,images,price_per_day)
        """

        do {
            let response = try await SupabaseManager.shared.client
                .from("requests")
                .select(select)
                .eq("owner_id", value: userId)
                .order("created_at", ascending: false)
                .execute()

            let rows = try JSONDecoder().decode([RequestWithItem].self, from: response.data)
            await MainActor.run {
                self.rows = rows
                self.tableView.reloadData()
                self.showEmptyStateIfNeeded()
            }
        } catch {
            await MainActor.run {
                self.rows = []
                self.tableView.reloadData()
                self.showEmptyStateIfNeeded()
            }
        }
    }

    private func presentLoginAlert() {
        let ac = UIAlertController(title: "Sign in required", message: "Please sign in to view your requests.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension RequestsListViewController: UITableViewDataSource {
    // One card per section so we can add spacing via footers
    func numberOfSections(in tableView: UITableView) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "Request", for: indexPath) as? LenderRequestTableViewCell else {
            return UITableViewCell()
        }
        guard indexPath.section < rows.count else {
            return cell
        }

        let req = rows[indexPath.section]

        // Name: prefer item title, fallback to item_id
        cell.itemNameRequest.text = req.items?.title ?? req.item_id
        cell.itemNameRequest.numberOfLines = 1
        cell.itemNameRequest.lineBreakMode = .byTruncatingTail

        // Rate: from items.price_per_day if available; else show date range
        if let p = req.items?.price_per_day {
            let text = (currencyFormatter.string(from: NSNumber(value: p)) ?? "\(p)") + " / day"
            cell.itemRateRequest.text = text
        } else {
            let sql = DateFormatter()
            sql.calendar = Calendar(identifier: .gregorian)
            sql.timeZone = .current
            sql.dateFormat = "yyyy-MM-dd"
            let display = DateFormatter()
            display.calendar = Calendar(identifier: .gregorian)
            display.timeZone = .current
            display.dateFormat = "d MMM yyyy"
            if let s = sql.date(from: req.start_date),
               let e = sql.date(from: req.end_date) {
                cell.itemRateRequest.text = "\(display.string(from: s)) — \(display.string(from: e))"
            } else {
                cell.itemRateRequest.text = "—"
            }
        }

        // Borrower/status label (using status for now)
        cell.itemBorrowerRequest.text = req.status.capitalized

        // Image: first item image if any
        if let path = req.items?.images.first,
           let url = StorageURLBuilder.publicFileURL(for: path) {
            cell.setImage(from: url)
        } else {
            cell.itemImageRequest.image = UIImage(systemName: "photo")
            cell.itemImageRequest.tintColor = .secondaryLabel
            cell.itemImageRequest.contentMode = .scaleAspectFit
        }

        // Transparent cell so grouped background shows between cards (no white lines)
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear

        return cell
    }
}

// MARK: - UITableViewDelegate
extension RequestsListViewController: UITableViewDelegate {
    // 16pt spacing between cards via section footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        16
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let v = UIView()
        v.backgroundColor = .clear
        return v
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section < rows.count else { return }

        let detail = DashboardLenderRequestViewController(nibName: "DashboardLenderRequestViewController", bundle: nil)
        detail.title = "Details"
        detail.hidesBottomBarWhenPushed = true

        // Inject the selected request
        detail.request = rows[indexPath.section]

        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.pushViewController(detail, animated: true)
    }
}
