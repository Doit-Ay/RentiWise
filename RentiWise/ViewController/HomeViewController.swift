//
//  HomeViewController.swift
//  RentiWise
//
//  Created by admin99 on 03/11/25.

import UIKit
import Supabase

class HomeViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UITabBarDelegate {

    @IBOutlet weak var collectionView: UICollectionView!

    @IBOutlet var ProfileImageTapped: UIImageView!
    @IBOutlet var productclicked: UIView!

    // Single image outlet only
    @IBOutlet weak var homeimage: UIImageView!

    private struct CategoryItem {
        let title: String
        let systemImageName: String
    }

    private let categories: [CategoryItem] = [
        .init(title: "Electronics", systemImageName: "drone"),
        .init(title: "Tools",       systemImageName: "hammer"),
        .init(title: "Events",      systemImageName: "hifispeaker"),
        .init(title: "Fitness",     systemImageName: "dumbbell"),
        .init(title: "Hobbies",     systemImageName: "guitars"),
        .init(title: "Outdoor",     systemImageName: "tent"),
    ]

    // Desired tint color (#70A7B4)
    private let categoryIconTintColor = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)

    // Currency formatter for rates
    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    // MARK: - Home header image rotation
    private let rotatingImageNames = ["Home1image", "Home2image", "Home3image"]
    private var imageRotationTimer: Timer?
    private var currentHomeImageIndex = 0
    private let rotationInterval: TimeInterval = 5.0

    // We’ll trigger the first image after layout to ensure bounds are valid
    private var didSetInitialHomeImageAfterLayout = false

    override func viewDidLoad() {
        super.viewDidLoad()

        title = ""
        navigationController?.navigationBar.tintColor = .label
        if #available(iOS 14.0, *) {
            navigationItem.backButtonDisplayMode = .minimal
        } else {
            navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        }

        // Basic setup
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.alwaysBounceVertical = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.setCollectionViewLayout(generateHorizontalFourUpLayout(), animated: false)

        setupProfileImageTap()
        setupProductTap()

        Task { await loadFeaturedItems() }

        // Ensure aspect fit and clipping on the single image view
        homeimage?.contentMode = .scaleAspectFit
        homeimage?.clipsToBounds = true

        // Set a fallback initial image immediately (in case timer/animation is delayed)
        if homeimage?.image == nil, let first = rotatingImageNames.first {
            homeimage?.image = UIImage(named: first)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // After we know bounds, set initial image once (no animation)
        if !didSetInitialHomeImageAfterLayout {
            didSetInitialHomeImageAfterLayout = true
            updateHomeImage(animated: false)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        startHomeImageRotation()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopHomeImageRotation()
    }

    deinit { stopHomeImageRotation() }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        collectionView.setCollectionViewLayout(generateHorizontalFourUpLayout(), animated: false)
    }

    // MARK: - Profile tap setup
    private func setupProfileImageTap() {
        guard let imageView = ProfileImageTapped else { return }
        imageView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapProfileImage))
        imageView.addGestureRecognizer(tap)
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = "Profile"
        imageView.accessibilityTraits = .button
    }

    // MARK: - Product tap setup
    private func setupProductTap() {
        guard let productView = productclicked else { return }
        productView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapProductView))
        productView.addGestureRecognizer(tap)
        productView.isAccessibilityElement = true
        productView.accessibilityLabel = "Product details"
        productView.accessibilityTraits = .button
    }

    @objc private func didTapProfileImage() {
        // Check Supabase auth session to decide where to route
        Task { [weak self] in
            guard let self else { return }
            do {
                let session = try await SupabaseManager.shared.client.auth.session
                _ = session.user
                // Logged in -> open Profile
                let profileVC = ProfileMainViewController()
                profileVC.title = ""
                profileVC.hidesBottomBarWhenPushed = true
                if let nav = self.navigationController {
                    nav.setNavigationBarHidden(false, animated: true)
                    nav.pushViewController(profileVC, animated: true)
                } else {
                    let nav = UINavigationController(rootViewController: profileVC)
                    nav.modalPresentationStyle = .fullScreen
                    self.present(nav, animated: true)
                }
            } catch {
                // Not logged in -> open Sign In, and tag context to route to Profile after success
                let nibName = "SignViewController"
                let signInVC: SignViewController
                if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
                    Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
                    signInVC = SignViewController(nibName: nibName, bundle: nil)
                } else {
                    signInVC = SignViewController(service: SignInService())
                }
                signInVC.routeContext = .fromProfile
                signInVC.title = "Sign in"
                signInVC.hidesBottomBarWhenPushed = true

                if let nav = self.navigationController {
                    nav.setNavigationBarHidden(false, animated: true)
                    nav.pushViewController(signInVC, animated: true)
                } else {
                    let nav = UINavigationController(rootViewController: signInVC)
                    nav.modalPresentationStyle = .fullScreen
                    self.present(nav, animated: true)
                }
            }
        }
    }

    @objc private func didTapProductView() {
        // Instantiate ProductViewController from XIB if available, else fallback to code
        let nibName = "ProductViewController"
        let productVC: ProductViewController

        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil || Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            productVC = ProductViewController(nibName: nibName, bundle: nil)
        } else {
            productVC = ProductViewController()
        }
        productVC.title = "Product Detail"
        productVC.hidesBottomBarWhenPushed = true
        if let nav = self.navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(productVC, animated: true)
        } else {
            productVC.modalPresentationStyle = .fullScreen
            present(productVC, animated: true)
        }
    }

    // MARK: - Compositional Layout: Horizontal row, 4 items visible per page
    private func generateHorizontalFourUpLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { (_, _) -> NSCollectionLayoutSection? in

            let interItemSpacing: CGFloat = 10
            let contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)

            // Each item is 1/4 of the group's width and full group height
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(0.25),
                heightDimension: .fractionalHeight(1.0)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                         leading: interItemSpacing / 2,
                                                         bottom: 0,
                                                         trailing: interItemSpacing / 2)

            // Height for the row (tweak as needed)
            let rowHeight: CGFloat = 70

            // Group spans the full width so that 4 items are visible per "page"
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(rowHeight)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = contentInsets

            // Snap page-by-page so each page shows exactly 4 items
            section.orthogonalScrollingBehavior = .groupPaging

            return section
        }
        return layout
    }

    // MARK: - Simple push helper
    private func pushCategories(title: String) {
        // Instantiate CategoriesViewController from storyboard "AppStarting"
        let sb = UIStoryboard(name: "AppStarting", bundle: nil)
        let vc = sb.instantiateViewController(withIdentifier: "Categories")

        // Ensure we got the right type and pass the selected category
        if let categoriesVC = vc as? CategoriesViewController {
            categoriesVC.category = title
            categoriesVC.title = title
            navigationController?.setNavigationBarHidden(false, animated: true)
            navigationController?.pushViewController(categoriesVC, animated: true)
        } else {
            assertionFailure("Storyboard ID 'Categories' is not a CategoriesViewController.")
        }
    }

    // MARK: - UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return categories.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Category", for: indexPath) as? CategoryCollectionViewCell else {
            assertionFailure("Could not dequeue CategoryCollectionViewCell with identifier 'Category'")
            return UICollectionViewCell()
        }

        let item = categories[indexPath.item]
        cell.categoryLabel.text = item.title

        let config = UIImage.SymbolConfiguration(pointSize: 32, weight: .regular, scale: .medium)
        cell.categoryImage.preferredSymbolConfiguration = config
        cell.categoryImage.image = UIImage(systemName: item.systemImageName)
        cell.categoryImage.tintColor = categoryIconTintColor

        cell.contentView.layer.cornerRadius = 12
        cell.contentView.layer.masksToBounds = true
        cell.contentView.backgroundColor = UIColor.white

        return cell
    }

    // MARK: - UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = categories[indexPath.item]
        pushCategories(title: item.title)
    }

    // MARK: - UITabBarDelegate

    // featured item 1
    @IBOutlet weak var item1Image: UIImageView!
    @IBOutlet weak var item1Name: UILabel!
    @IBOutlet weak var item1Rate: UILabel!
    @IBOutlet weak var item1Rating: UILabel!
    @IBOutlet weak var item1Distance: UILabel!
    @IBOutlet weak var item1wishlist: UIImageView!

    // featured item 2
    @IBOutlet weak var item2Image: UIImageView!
    @IBOutlet weak var item2Name: UILabel!
    @IBOutlet weak var item2Rate: UILabel!
    @IBOutlet weak var item2Rating: UILabel!
    @IBOutlet weak var item2Distance: UILabel!
    @IBOutlet weak var item2Wishlist: UIImageView!

    // featured item 3
    @IBOutlet weak var item3Image: UIImageView!
    @IBOutlet weak var item3Name: UILabel!
    @IBOutlet weak var item3Rate: UILabel!
    @IBOutlet weak var item3Rating: UILabel!
    @IBOutlet weak var item3Distance: UILabel!
    @IBOutlet weak var item3Wishlist: UIImageView!

    // featured item 4
    @IBOutlet weak var item4Image: UIImageView!
    @IBOutlet weak var item4Name: UILabel!
    @IBOutlet weak var item4Rate: UILabel!
    @IBOutlet weak var item4Rating: UILabel!
    @IBOutlet weak var item4Distance: UILabel!
    @IBOutlet weak var item4Wishlist: UIImageView!
}

// MARK: - Home header image rotation + slide animation (Aspect Fit)
private extension HomeViewController {

    func startHomeImageRotation() {
        stopHomeImageRotation()
        guard !rotatingImageNames.isEmpty else { return }
        imageRotationTimer = Timer.scheduledTimer(withTimeInterval: rotationInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentHomeImageIndex = (self.currentHomeImageIndex + 1) % self.rotatingImageNames.count
            self.updateHomeImage(animated: true)
        }
    }

    func stopHomeImageRotation() {
        imageRotationTimer?.invalidate()
        imageRotationTimer = nil
    }

    func updateHomeImage(animated: Bool) {
        guard let imageView = homeimage, !rotatingImageNames.isEmpty else {
            return
        }

        // Ensure the image view has a valid size
        guard imageView.bounds.width > 0, imageView.bounds.height > 0 else {
            return
        }

        let name = rotatingImageNames[currentHomeImageIndex]
        let nextImage = UIImage(named: name)

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true

        guard animated else {
            imageView.image = nextImage
            return
        }

        slideInFromRight(newImage: nextImage, in: imageView, duration: 0.35)
    }

    // Slides inside the image view’s bounds so it never overflows
    func slideInFromRight(newImage: UIImage?, in imageView: UIImageView, duration: TimeInterval) {
        imageView.layoutIfNeeded()
        let baseFrame = imageView.bounds

        // Outgoing snapshot
        let outgoing = UIImageView(image: imageView.image)
        outgoing.frame = baseFrame
        outgoing.contentMode = .scaleAspectFit
        outgoing.clipsToBounds = true

        // Incoming image starts to the right
        let incoming = UIImageView(image: newImage)
        incoming.frame = baseFrame
        incoming.contentMode = .scaleAspectFit
        incoming.clipsToBounds = true
        incoming.transform = CGAffineTransform(translationX: baseFrame.width, y: 0)

        // Add inside imageView (which clips)
        imageView.addSubview(outgoing)
        imageView.addSubview(incoming)

        // Hide the real content during animation
        let previousImage = imageView.image
        imageView.image = nil

        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseInOut], animations: {
            outgoing.transform = CGAffineTransform(translationX: -baseFrame.width, y: 0)
            incoming.transform = .identity
        }, completion: { _ in
            imageView.image = newImage
            outgoing.removeFromSuperview()
            incoming.removeFromSuperview()

            // Safety fallback if newImage was nil for any reason
            if imageView.image == nil {
                imageView.image = previousImage
            }
        })
    }
}

// MARK: - Featured items loading
private extension HomeViewController {

    func loadFeaturedItems() async {
        do {
            // newest first, limit 4; RLS already restricts to is_active = true for public
            let response = try await SupabaseManager.shared.client
                .from("items")
                .select()
                .order("created_at", ascending: false)
                .limit(4)
                .execute()

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let items = try decoder.decode([Item].self, from: response.data)

            await MainActor.run {
                self.applyFeatured(items: items)
            }
        } catch {
            // Optional: clear featured UI on error
            await MainActor.run {
                self.applyFeatured(items: [])
            }
        }
    }

    func applyFeatured(items: [Item]) {
        // Map items to the four slots
        let slots: [(UIImageView?, UILabel?, UILabel?, UILabel?, UILabel?)] = [
            (item1Image, item1Name, item1Rate, item1Rating, item1Distance),
            (item2Image, item2Name, item2Rate, item2Rating, item2Distance),
            (item3Image, item3Name, item3Rate, item3Rating, item3Distance),
            (item4Image, item4Name, item4Rate, item4Rating, item4Distance)
        ]

        for i in 0..<slots.count {
            let slot = slots[i]
            if i < items.count {
                let item = items[i]
                configureFeaturedSlot(slot, with: item)
            } else {
                clearFeaturedSlot(slot)
            }
        }
    }

    func configureFeaturedSlot(_ slot: (UIImageView?, UILabel?, UILabel?, UILabel?, UILabel?), with item: Item) {
        let (imageView, nameLabel, rateLabel, ratingLabel, distanceLabel) = slot

        nameLabel?.text = item.title

        let amount = NSNumber(value: item.price_per_day)
        let priceText = (currencyFormatter.string(from: amount) ?? "\(item.price_per_day)") + " / day"
        rateLabel?.text = priceText

        // No rating/distance in schema; placeholders for now
        ratingLabel?.text = "★ 4.5 (23)"
        distanceLabel?.text = "2.3 km"

        // Load first image (public bucket)
        if let path = item.images.first, let url = StorageURLBuilder.publicFileURL(for: path) {
            setImage(into: imageView, from: url)
        } else {
            imageView?.image = UIImage(systemName: "photo")
            imageView?.tintColor = .secondaryLabel
            imageView?.contentMode = .scaleAspectFit
        }
    }

    func clearFeaturedSlot(_ slot: (UIImageView?, UILabel?, UILabel?, UILabel?, UILabel?)) {
        let (imageView, nameLabel, rateLabel, ratingLabel, distanceLabel) = slot
        imageView?.image = nil
        nameLabel?.text = nil
        rateLabel?.text = nil
        ratingLabel?.text = nil
        distanceLabel?.text = nil
    }

    func setImage(into imageView: UIImageView?, from url: URL) {
        guard let imageView = imageView else { return }

        // Basic cache
        if let cached = FeaturedImageCache.shared.image(forKey: url.absoluteString) {
            imageView.image = cached
            imageView.contentMode = .scaleAspectFit
            imageView.clipsToBounds = true
            return
        }

        let req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data, let img = UIImage(data: data) else { return }
            FeaturedImageCache.shared.setImage(img, forKey: url.absoluteString)
            DispatchQueue.main.async {
                imageView.image = img
                imageView.contentMode = .scaleAspectFit
                imageView.clipsToBounds = true
            }
        }.resume()
    }
}

// Simple cache for featured images
private final class FeaturedImageCache {
    static let shared = FeaturedImageCache()
    private let cache = NSCache<NSString, UIImage>()
    func image(forKey key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func setImage(_ img: UIImage, forKey key: String) { cache.setObject(img, forKey: key as NSString) }
}
