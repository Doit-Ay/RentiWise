import UIKit

final class CardsViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let storage = StorageService()

    private var selectedRealItem: Item?
    private var itemMap: [String: Item] = [:]

    // Demo data – replace with your ItemsService fetch results
    private struct DemoItem {
        let title: String
        let pricePerDay: Double
        let ratingText: String
        let distanceText: String
        let imagePath: String
    }

    private var demoItems: [DemoItem] = [
        DemoItem(title: "Item Name", pricePerDay: 350, ratingText: "★ 4.5 (23)", distanceText: "2.3 km",
                 imagePath: "B17E0037-93CC-4B9E-9E33-E3FA4C853EEC/item_1763575596_0.jpg"),
        DemoItem(title: "Another Item", pricePerDay: 499, ratingText: "★ 4.2 (11)", distanceText: "1.1 km",
                 imagePath: "B17E0037-93CC-4B9E-9E33-E3FA4C853EEC/item_1763575596_0.jpg")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Cards"
        view.backgroundColor = .systemGroupedBackground

        setupLayout()
        loadCards()
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 0 // spacing visually comes from CardView.contentInsets

        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func loadCards() {
        let currencyFormatter: NumberFormatter = {
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.minimumFractionDigits = 2
            f.maximumFractionDigits = 2
            return f
        }()

        for item in demoItems {
            let card = CardView()
            let priceText = (currencyFormatter.string(from: NSNumber(value: item.pricePerDay)) ?? "\(item.pricePerDay)") + " / day"
            card.configure(title: item.title, priceText: priceText, ratingText: item.ratingText, distanceText: item.distanceText)

            // Adjust outer spacing if you want bigger gaps
            card.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)

            // Add Rent Now button as accessory or subview
            let rentButton = UIButton(type: .system)
            rentButton.setTitle("Rent Now", for: .normal)
            rentButton.addTarget(self, action: #selector(handleRentNow(_:)), for: .touchUpInside)
            if card.responds(to: Selector(("addArrangedAccessory:"))) {
                // Using addArrangedAccessory if available
                (card.perform(Selector(("addArrangedAccessory:")), with: rentButton))
            } else {
                // fallback: add as subview to card.contentView
                if let contentView = card.value(forKey: "contentView") as? UIView {
                    rentButton.translatesAutoresizingMaskIntoConstraints = false
                    contentView.addSubview(rentButton)
                    NSLayoutConstraint.activate([
                        rentButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                        rentButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
                    ])
                } else {
                    // fallback: add to card itself
                    rentButton.translatesAutoresizingMaskIntoConstraints = false
                    card.addSubview(rentButton)
                    NSLayoutConstraint.activate([
                        rentButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
                        rentButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
                    ])
                }
            }

            // Construct a real Item from DemoItem
            let demo = item
            let now = Date()
            let constructed = Item(
                id: UUID().uuidString,
                owner_id: "demo-owner",
                title: demo.title,
                description: "",
                category: "Demo",
                condition: "Good",
                price_per_day: demo.pricePerDay,
                deposit_amount: 0,
                images: [demo.imagePath],
                is_active: true,
                created_at: now,
                updated_at: now
            )
            itemMap[constructed.id] = constructed
            rentButton.accessibilityValue = constructed.id

            stack.addArrangedSubview(card)

            // Load image (choose ONE: public or private)
            Task {
                do {
                    // PRIVATE bucket (signed URL)
                    // Change "itemimages" to your real bucket name
                    let url = try await storage.signedURL(bucket: "itemimages", path: item.imagePath, expiresIn: 3600)
                    card.setImage(from: url)

                    // PUBLIC bucket example (if your bucket is public and StorageURLBuilder is configured):
                    // if let url = StorageURLBuilder.publicFileURL(for: item.imagePath) {
                    //     card.setImage(from: url)
                    // }
                } catch {
                    // handle image error if needed
                }
            }
        }
    }

    @objc private func handleRentNow(_ sender: UIButton) {
        guard let id = sender.accessibilityValue, let selected = itemMap[id] else { return }
        let vc = RequestViewController(nibName: "RequestViewController", bundle: nil)
        vc.hidesBottomBarWhenPushed = true
        vc.configure(with: selected)
        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }
}

