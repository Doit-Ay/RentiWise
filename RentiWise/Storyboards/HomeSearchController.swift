// HomeSearchController.swift
import UIKit
import Supabase

final class HomeSearchController: NSObject {

    // MARK: - Public API
    var onSelectItem: ((Item) -> Void)?
    var onResultsChanged: (([Item]) -> Void)?

    // MARK: - Private
    private weak var hostView: UIView?
    private weak var searchBar: UISearchBar?
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var results: [Item] = [] {
        didSet {
            onResultsChanged?(results)
            tableView.reloadData()
            tableView.isHidden = results.isEmpty
        }
    }

    private var debounceWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 0.30

    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    // MARK: - Init
    init(searchBar: UISearchBar, in hostView: UIView) {
        self.hostView = hostView
        self.searchBar = searchBar
        super.init()
        configureSearchBar(searchBar)
        configureTable(in: hostView)
        observeKeyboard()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup
    private func configureSearchBar(_ bar: UISearchBar) {
        bar.delegate = self
        bar.placeholder = "Search items"
        bar.searchBarStyle = .minimal
        bar.autocapitalizationType = .none
        bar.autocorrectionType = .no
        bar.returnKeyType = .search

        // Remove default background/chrome
        bar.setBackgroundImage(UIImage(), for: .any, barMetrics: .default)
        bar.backgroundImage = UIImage()
        bar.backgroundColor = .clear

        // Make the whole bar allow shadow (if applied)
        bar.clipsToBounds = false
        // Optional soft shadow (comment out if you don't want it)
        bar.layer.shadowColor = UIColor.black.cgColor
        bar.layer.shadowOpacity = 0.06
        bar.layer.shadowRadius = 6
        bar.layer.shadowOffset = CGSize(width: 0, height: 2)

        // Round the inner text field to look like iOS pill search
        if let tf = bar.value(forKey: "searchField") as? UITextField {
            tf.borderStyle = .none
            tf.layer.cornerRadius = 18
            tf.layer.masksToBounds = true
            tf.backgroundColor = .secondarySystemBackground

            // Subtle 1pt border like system fields
            tf.layer.borderWidth = 1
            tf.layer.borderColor = UIColor.separator.cgColor

            // Text and placeholder styling
            tf.textColor = .label
            tf.clearButtonMode = .whileEditing
            tf.attributedPlaceholder = NSAttributedString(
                string: bar.placeholder ?? "Search",
                attributes: [.foregroundColor: UIColor.secondaryLabel]
            )

            // Ensure the magnifying glass uses a subtle tint
            if let leftIcon = tf.leftView as? UIImageView {
                leftIcon.tintColor = .secondaryLabel
            }

            // Slight horizontal padding by adjusting left/right views if needed
            // (UISearchBar already provides standard padding via leftView)
            // You can uncomment below to add a tiny spacer on the right if desired:
            /*
            let spacer = UIView(frame: CGRect(x: 0, y: 0, width: 4, height: 1))
            tf.rightView = spacer
            tf.rightViewMode = .always
            */
        }
    }

    private func configureTable(in view: UIView) {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.isHidden = true
        tableView.backgroundColor = .systemGroupedBackground
        tableView.separatorStyle = .none
        tableView.rowHeight = 84
        tableView.estimatedRowHeight = 84
        tableView.dataSource = self
        tableView.delegate = self

        // Register a simple cell
        tableView.register(ResultCell.self, forCellReuseIdentifier: ResultCell.reuseID)

        view.addSubview(tableView)
        // We’ll pin using dynamic top anchor updates in layoutForSearchBarBelow()
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Initial top anchor set once we can compute the search bar’s frame
        layoutForSearchBarBelow()
    }

    // Call in viewDidLayoutSubviews (or after rotations) if you want to keep alignment perfect
    func layoutForSearchBarBelow() {
        guard let view = hostView, let bar = searchBar else { return }
        // Convert the bar’s frame to host coordinate space
        let barFrameInHost = bar.convert(bar.bounds, to: view)
        // Adjust the table’s top anchor by setting a constraint via safeArea
        // Remove any previous top constraints owned by us
        let toRemove = view.constraints.filter { $0.firstItem === tableView && $0.firstAttribute == .top }
        view.removeConstraints(toRemove)

        let spacing: CGFloat = 8
        let top = tableView.topAnchor.constraint(equalTo: view.topAnchor, constant: barFrameInHost.maxY + spacing)
        top.priority = .required
        top.isActive = true

        view.layoutIfNeeded()
    }

    // MARK: - Keyboard
    private func observeKeyboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(kbWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(kbWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func kbWillShow(_ note: Notification) {
        guard let info = note.userInfo,
              let frame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let view = hostView else { return }

        let keyboardHeight = max(0, frame.height - view.safeAreaInsets.bottom)
        var inset = tableView.contentInset
        inset.bottom = keyboardHeight + 8
        tableView.contentInset = inset
        tableView.scrollIndicatorInsets = inset
    }

    @objc private func kbWillHide(_ note: Notification) {
        var inset = tableView.contentInset
        inset.bottom = 0
        tableView.contentInset = inset
        tableView.scrollIndicatorInsets = inset
    }

    // MARK: - Search
    private func performSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            results = []
            return
        }

        Task {
            do {
                // Search title OR description, newest first, limit 25
                let response = try await SupabaseManager.shared.client
                    .from("items")
                    .select()
                    .or("title.ilike.%\(escapeLike(trimmed))%,description.ilike.%\(escapeLike(trimmed))%")
                    .order("created_at", ascending: false)
                    .limit(25)
                    .execute()

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let rows = try decoder.decode([Item].self, from: response.data)

                await MainActor.run {
                    self.results = rows
                }
            } catch {
                await MainActor.run {
                    self.results = []
                }
            }
        }
    }

    // Escape % and _ for ILIKE pattern
    private func escapeLike(_ text: String) -> String {
        var s = text.replacingOccurrences(of: "%", with: "\\%")
        s = s.replacingOccurrences(of: "_", with: "\\_")
        return s
    }
}

// MARK: - UISearchBarDelegate
extension HomeSearchController: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        // Move caret in and open keyboard
        searchBar.becomeFirstResponder()
        // Adjust the table position in case layout changed
        layoutForSearchBarBelow()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Debounce
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.performSearch(query: searchText)
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        // Keep results visible; if you prefer to hide, uncomment:
        // results = []
    }
}

// MARK: - UITableViewDataSource/Delegate
extension HomeSearchController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { results.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ResultCell.reuseID, for: indexPath) as! ResultCell
        let item = results[indexPath.section]
        cell.configure(with: item, currencyFormatter: currencyFormatter)
        // Backgrounds
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        return cell
    }

    // Spacing between cards
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 8 }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let v = UIView()
        v.backgroundColor = .clear
        return v
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = results[indexPath.section]
        onSelectItem?(item)
    }
}

// MARK: - ResultCell
private final class ResultCell: UITableViewCell {
    static let reuseID = "ResultCell"

    private let card = UIView()
    private let thumb = UIImageView()
    private let title = UILabel()
    private let price = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        selectionStyle = .none
        contentView.backgroundColor = .clear

        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .clear
        card.layer.cornerRadius = 14
        card.layer.masksToBounds = false
        contentView.addSubview(card)

        // Glass
        card.applyGlassEffect(
            cornerRadius: 14,
            style: .systemThickMaterial,
            addsVibrancy: false,
            showsShadow: true,
            borderAlpha: 0.25,
            tintColorOverride: .white,
            tintAlpha: 0.14
        )

        thumb.translatesAutoresizingMaskIntoConstraints = false
        thumb.contentMode = .scaleAspectFill
        thumb.clipsToBounds = true
        thumb.layer.cornerRadius = 10
        thumb.backgroundColor = .secondarySystemBackground

        title.translatesAutoresizingMaskIntoConstraints = false
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        title.textColor = .label
        title.numberOfLines = 2

        price.translatesAutoresizingMaskIntoConstraints = false
        price.font = .systemFont(ofSize: 15, weight: .regular)
        price.textColor = .label

        card.addSubview(thumb)
        card.addSubview(title)
        card.addSubview(price)

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            thumb.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            thumb.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            thumb.widthAnchor.constraint(equalToConstant: 60),
            thumb.heightAnchor.constraint(equalToConstant: 60),

            title.leadingAnchor.constraint(equalTo: thumb.trailingAnchor, constant: 12),
            title.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            title.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),

            price.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            price.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            price.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            price.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])
    }

    func configure(with item: Item, currencyFormatter: NumberFormatter) {
        title.text = item.title
        let amount = NSNumber(value: item.price_per_day)
        price.text = (currencyFormatter.string(from: amount) ?? "\(item.price_per_day)") + " / day"

        if let path = item.images.first, let url = StorageURLBuilder.publicFileURL(for: path) {
            if let cached = FeaturedImageCache.shared.image(forKey: url.absoluteString) {
                thumb.image = cached
            } else {
                let req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
                URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
                    guard let self = self, let data = data, let img = UIImage(data: data) else { return }
                    FeaturedImageCache.shared.setImage(img, forKey: url.absoluteString)
                    DispatchQueue.main.async { self.thumb.image = img }
                }.resume()
            }
        } else {
            thumb.image = UIImage(systemName: "photo")
            thumb.tintColor = .secondaryLabel
            thumb.contentMode = .scaleAspectFit
        }
    }
}

