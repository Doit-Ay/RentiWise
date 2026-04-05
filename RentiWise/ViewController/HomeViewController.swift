//
//  HomeViewController.swift
//  RentiWise
//
//  Created by admin99 on 03/11/25.

import UIKit
import Supabase

class HomeViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UITabBarDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate {

    @IBOutlet weak var greetingTop: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!

    @IBOutlet weak var Homepagelastline: UILabel!
    @IBOutlet var productclicked: UIView!
    // Single image outlet only
    @IBOutlet weak var homeimage: UIImageView!

    @IBAction func seeAllTrending(_ sender: UIButton) {
    }
    @IBOutlet weak var trendingUiView: UIView!
    @IBOutlet weak var locationTapped: UIButton!
    
    @IBOutlet weak var searchBar: UISearchBar!
    
    @IBOutlet weak var homeBG: UIView!
    
    // Keep a reference so we can resize and avoid duplicates
    // private var homeGradientLayer: CAGradientLayer?

    @IBAction func notificationBellTapped(_ sender: UIButton) {
        let nibName = "NotificationViewController"
        let vc: NotificationViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
            Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            vc = NotificationViewController(nibName: nibName, bundle: nil)
        } else {
            vc = NotificationViewController()
        }
        vc.title = "Notifications"
        vc.hidesBottomBarWhenPushed = true

        if let nav = self.navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }
    @IBOutlet weak var notificationBell: UIButton!
    @IBOutlet weak var listingUIView: UIView!
    @IBOutlet weak var additemHome: UIButton!
    @IBOutlet weak var startearninglabel: UILabel!
    @IBOutlet weak var startearningdownlabel: UILabel!
    
    // Home screen “Request” button → push RequestsListViewController (no Dashboard)
    @IBAction func requestsButtonTapped(_ sender: UIButton) {
        Task { [weak self] in
            guard let self else { return }
            do {
                // Require login for Requests
                let session = try await SupabaseManager.shared.client.auth.session
                _ = session.user // throws if not logged in

                let vc = RequestsListViewController()
                vc.title = "Requests"
                vc.hidesBottomBarWhenPushed = true

                if let nav = self.navigationController {
                    nav.setNavigationBarHidden(false, animated: true)
                    nav.pushViewController(vc, animated: true)
                } else {
                    let nav = UINavigationController(rootViewController: vc)
                    nav.modalPresentationStyle = .fullScreen
                    self.present(nav, animated: true)
                }
            } catch {
                let nibName = "SignViewController"
                let signInVC: SignViewController
                if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
                    Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
                    signInVC = SignViewController(nibName: nibName, bundle: nil)
                } else {
                    signInVC = SignViewController(service: SignInService())
                }
                signInVC.routeContext = .default
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
    
    @IBAction func additemHomeTapped(_ sender: UIButton) {
        Task { [weak self] in
            guard let self else { return }
            if await self.ensureAuthenticated(orOpen: .signUp) {
                // Logged in -> start Add Item flow
                let vc = AddItemFirstViewController(nibName: "AddItemFirstViewController", bundle: nil)
                vc.title = "Add item"
                vc.hidesBottomBarWhenPushed = true

                if let nav = self.navigationController {
                    nav.setNavigationBarHidden(false, animated: false)
                    nav.pushViewController(vc, animated: true)
                } else {
                    vc.modalPresentationStyle = .fullScreen
                    self.present(vc, animated: true)
                }
            }
        }
    }
    struct CategoryItem {
        let title: String
        let systemImageName: String
    }

    var categoriesList: [CategoryItem] = [
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
    let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    // MARK: - Home header image rotation
    let rotatingImageNames = ["Home1image", "Home2image", "Home3image"]
    var imageRotationTimer: Timer?
    var currentHomeImageIndex = 0
    let rotationInterval: TimeInterval = 5.0

    // We'll trigger the first image after layout to ensure bounds are valid
    var didSetInitialHomeImageAfterLayout = false

    // Hold onto loaded featured items so we can open details on tap
    var featuredItems: [Item] = []

    // Containers for round glass buttons in the header
    var notificationContainer: UIView?

    var addItemContainer: UIView?

    // MARK: - Manage Listings state
    var isListingDataLoaded = false // track if listing data has been fetched
    var manageContainerView: UIView? // inserted inside listingUIView when user has items

    // MARK: - Cold start tracking
    /// True on first viewWillAppear; flipped to false after first load completes.
    /// Used to decide whether to use PreloadManager cache or force-refresh.
    private var isFirstLoad = true

    // MARK: - Trending collection
    var trendingCollectionView: UICollectionView?
    var trendingItems: [Item] = []

    // Owner name cache for trending items
    var ownerNameCache: [String: String] = [:]

    // MARK: - Search helper
    var homeSearch: HomeSearchController?
    private let safetyService = CommunitySafetyService.shared

    // MARK: - Services
    let itemsService = ItemsService()
    
    // MARK: - Navigation delegate for tab bar hiding
    let tabBarDelegate = TabBarNavigationDelegate()
    
    // MARK: - Notification badge
    var unreadNotificationCount: Int = 0
    var notificationBadge: UIView?

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
        // Make the surrounding area transparent so only tiles are visible
        collectionView.backgroundColor = .clear

        // Style the search bar using the shared native style
        searchBar?.applyRentiWiseStyle()

        // Ensure the location button truncates within its space
        configureLocationButtonAppearance()

        setupProductTap()
        setupFeaturedItemTaps()

        // Trending scroller inside trendingUiView
        setupTrendingCollection()

        Task { await loadFeaturedItems() }

        // Ensure aspect fit and clipping on the single image view
        homeimage?.contentMode = .scaleAspectFit
        homeimage?.clipsToBounds = true

        // Set a fallback initial image immediately (in case timer/animation is delayed)
        if homeimage?.image == nil, let first = rotatingImageNames.first {
            homeimage?.image = UIImage(named: first)
        }
        
        // Refresh location button title ("SRMIST" if none saved) and ensure a real default is persisted
        refreshLocationButtonTitle()

        // Initialize search helper (rounded search bar, keyboard behavior, inline results)
        if let sb = searchBar {
            let hs = HomeSearchController(searchBar: sb, in: view)
            hs.onSelectItem = { [weak self] item in
                self?.openItem(item)
            }
            self.homeSearch = hs
        }

        // Add a background tap to dismiss keyboard when tapping anywhere outside the search bar/results
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboardTap))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        // Set the bottom tagline "You ❤️ Rentiwise" with brand-colored heart
        setBottomTagline()
        
        // Set navigation delegate to auto-hide tab bar on push
        navigationController?.delegate = tabBarDelegate
        
        // Ensure tab bar item shows title
        navigationController?.tabBarItem.title = "Explore"
        
        // Listing section alpha is no longer zeroed out here — the animated
        // splash covers the UI until PreloadManager data is ready, so there's
        // no empty-card flicker to hide.

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBlockedUsersChanged),
            name: CommunitySafetyService.blockedUsersDidChangeNotification,
            object: nil
        )
    }

    @objc private func dismissKeyboardTap() {
        // Resign first responder from the search bar / any field
        view.endEditing(true)
        // Optional: if you want to also hide inline results when dismissing:
        // homeSearch?.clearResults()
        // Keep results table aligned after any layout changes
        homeSearch?.layoutForSearchBarBelow()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Remove manual layoutSearchBarRounded calls to preserve native height and radii

        // After we know bounds, set initial image once (no animation)
        if !didSetInitialHomeImageAfterLayout {
            didSetInitialHomeImageAfterLayout = true
            updateHomeImage(animated: false)
        }

        // Keep the inline results table pinned under the search bar
        homeSearch?.layoutForSearchBarBelow()

        // Gradient temporarily disabled
        // setupHomeBackgroundGradient()

        // Apply glass to featured cards (once; helper reuses existing blur view by tag)
        applyGlassToFeaturedCardsIfNeeded()
        // Apply glass to Rent buttons
        applyGlassToRentButtonsIfNeeded()
        // Apply round glass containers to notification and add-item buttons
        applyGlassToHeaderRoundButtons()
    }

    // MARK: - Verification nudge (session-only)
    private var verificationNudgeBanner: UIView?
    private var hasSeenVerificationNudge = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
        // Always show tab bar when Home screen appears
        tabBarController?.tabBar.isHidden = false
        startHomeImageRotation()
        // Update greeting based on time of day
        updateGreeting()

        // On cold start, use PreloadManager's cache (already fetched).
        // On subsequent appears (tab switches, back-nav), force a network refresh.
        let needsRefresh = !isFirstLoad
        isFirstLoad = false

        Task { await checkAndUpdateListingSection(forceRefresh: needsRefresh) }
        // Refresh location button on appear as well
        refreshLocationButtonTitle()
        // Update notification badge
        Task { await updateNotificationBadge() }
        // Show verification nudge if needed
        Task { await showVerificationNudgeIfNeeded() }
        // Refresh featured items & new arrivals so newly added items appear
        Task { await loadFeaturedItems() }
    }

    private func showVerificationNudgeIfNeeded() async {
        guard !hasSeenVerificationNudge, verificationNudgeBanner == nil else { return }
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let userId = session.user.id.uuidString
            let isVerified = await CollegeVerificationService.shared.isUserVerified(userId: userId)
            if !isVerified {
                await MainActor.run { addVerificationNudgeBanner() }
            }
        } catch { /* not logged in — skip */ }
    }

    private func addVerificationNudgeBanner() {
        guard verificationNudgeBanner == nil else { return }
        let brandTeal = UIColor(red: 0x0A/255.0, green: 0x7B/255.0, blue: 0x6C/255.0, alpha: 1.0)
        let banner = UIView()
        banner.backgroundColor = brandTeal
        banner.layer.cornerRadius = 12
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.tag = 9999

        let label = UILabel()
        label.text = "🎓 Verify an email for extra trust points  →"
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        banner.addSubview(label)

        let dismiss = UIButton(type: .system)
        dismiss.setTitle("✕", for: .normal)
        dismiss.setTitleColor(.white, for: .normal)
        dismiss.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        dismiss.addTarget(self, action: #selector(dismissVerificationNudge), for: .touchUpInside)
        dismiss.translatesAutoresizingMaskIntoConstraints = false
        banner.addSubview(dismiss)

        let tap = UITapGestureRecognizer(target: self, action: #selector(verificationNudgeTapped))
        banner.addGestureRecognizer(tap)

        view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            banner.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            banner.heightAnchor.constraint(equalToConstant: 48),
            label.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 14),
            label.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            dismiss.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -12),
            dismiss.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
        ])
        verificationNudgeBanner = banner
    }

    @objc private func dismissVerificationNudge() {
        hasSeenVerificationNudge = true
        UIView.animate(withDuration: 0.25, animations: { self.verificationNudgeBanner?.alpha = 0 }) { _ in
            self.verificationNudgeBanner?.removeFromSuperview()
            self.verificationNudgeBanner = nil
        }
    }

    @objc private func verificationNudgeTapped() {
        let vc = CollegeVerificationViewController()
        vc.onVerificationComplete = { [weak self] in
            self?.hasSeenVerificationNudge = true
            self?.verificationNudgeBanner?.removeFromSuperview()
            self?.verificationNudgeBanner = nil
        }
        vc.hidesBottomBarWhenPushed = true
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func handleBlockedUsersChanged() {
        Task { await loadFeaturedItems(forceRefresh: true) }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopHomeImageRotation()
    }

    deinit {
        stopHomeImageRotation()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        collectionView.setCollectionViewLayout(generateHorizontalFourUpLayout(), animated: false)
    }

    // MARK: - Search bar styling removed (using extension)

    // MARK: - Location button text behavior (truncate within given space)
    private func configureLocationButtonAppearance() {
        guard let btn = locationTapped else { return }
        // Keep single line and truncate at tail with ellipsis
        btn.titleLabel?.numberOfLines = 1
        btn.titleLabel?.lineBreakMode = .byTruncatingTail
        btn.titleLabel?.adjustsFontSizeToFitWidth = false
        // Keep text left-aligned within its bounds
        btn.contentHorizontalAlignment = .leading
        // Optional: small horizontal padding
        btn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
        // Prefer truncation over expanding horizontally
        btn.setContentCompressionResistancePriority(.required, for: .horizontal)
        // If the button has an image, ensure room between image and text
        if btn.image(for: .normal) != nil {
            btn.semanticContentAttribute = .forceLeftToRight
            btn.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 6)
        }
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

    private func setupFeaturedItemTaps() {
        // Image taps
        let tap1 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured1))
        item1Image?.isUserInteractionEnabled = true
        item1Image?.addGestureRecognizer(tap1)

        let tap2 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured2))
        item2Image?.isUserInteractionEnabled = true
        item2Image?.addGestureRecognizer(tap2)

        let tap3 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured3))
        item3Image?.isUserInteractionEnabled = true
        item3Image?.addGestureRecognizer(tap3)

        let tap4 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured4))
        item4Image?.isUserInteractionEnabled = true
        item4Image?.addGestureRecognizer(tap4)

        // Card taps (make entire card tappable, but NOT the Rent button area)
        let cardTap1 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured1))
        cardTap1.cancelsTouchesInView = false
        cardTap1.delegate = self
        item1CardView?.isUserInteractionEnabled = true
        item1CardView?.addGestureRecognizer(cardTap1)

        let cardTap2 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured2))
        cardTap2.cancelsTouchesInView = false
        cardTap2.delegate = self
        item2CardView?.isUserInteractionEnabled = true
        item2CardView?.addGestureRecognizer(cardTap2)

        let cardTap3 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured3))
        cardTap3.cancelsTouchesInView = false
        cardTap3.delegate = self
        item3CardView?.isUserInteractionEnabled = true
        item3CardView?.addGestureRecognizer(cardTap3)

        let cardTap4 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured4))
        cardTap4.cancelsTouchesInView = false
        cardTap4.delegate = self
        item4CardView?.isUserInteractionEnabled = true
        item4CardView?.addGestureRecognizer(cardTap4)
    }

    @objc private func didTapFeatured1() { openFeatured(at: 0) }
    @objc private func didTapFeatured2() { openFeatured(at: 1) }
    @objc private func didTapFeatured3() { openFeatured(at: 2) }
    @objc private func didTapFeatured4() { openFeatured(at: 3) }

    // MARK: - UIGestureRecognizerDelegate
    // Prevent card tap gestures from firing when the Rent button is tapped
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let view = gestureRecognizer.view else { return true }
        let location = gestureRecognizer.location(in: view)
        // Walk the hit-test tree; if the tapped view is a UIButton, let the button handle it
        if let hitView = view.hitTest(location, with: nil), hitView is UIButton {
            return false
        }
        return true
    }

    private func openFeatured(at index: Int) {
        guard index < featuredItems.count else { return }
        let item = featuredItems[index]
        guard ensureItemVisible(item) else { return }
        // Instantiate ProductViewController
        let nibName = "ProductViewController"
        let productVC: ProductViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil || Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            productVC = ProductViewController(nibName: nibName, bundle: nil)
        } else {
            productVC = ProductViewController()
        }
        productVC.configure(with: item)
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

    // Helper used by trending list to open an item detail
    private func openItem(_ item: Item) {
        guard ensureItemVisible(item) else { return }
        let nibName = "ProductViewController"
        let productVC: ProductViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil || Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            productVC = ProductViewController(nibName: nibName, bundle: nil)
        } else {
            productVC = ProductViewController()
        }
        productVC.configure(with: item)
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
    
    // Helper to open RequestViewController directly from rent button
    func openRequestView(for item: Item) {
        guard ensureItemVisible(item) else { return }
        Task { [weak self] in
            guard let self else { return }
            guard await self.ensureAuthenticated(orOpen: .signUp) else { return }

            let nibName = "RequestViewController"
            let requestVC: RequestViewController
            if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
                Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
                requestVC = RequestViewController(nibName: nibName, bundle: nil)
            } else {
                requestVC = RequestViewController()
            }
            requestVC.configure(with: item)
            requestVC.title = "Request"
            requestVC.hidesBottomBarWhenPushed = true

            if let nav = self.navigationController {
                nav.setNavigationBarHidden(false, animated: true)
                nav.pushViewController(requestVC, animated: true)
            } else {
                let nav = UINavigationController(rootViewController: requestVC)
                nav.modalPresentationStyle = .fullScreen
                self.present(nav, animated: true)
            }
        }
    }

    @objc private func didTapProductView() {
        if let first = featuredItems.first, !ensureItemVisible(first) {
            return
        }
        // Instantiate ProductViewController from XIB if available, else fallback to code
        let nibName = "ProductViewController"
        let productVC: ProductViewController

        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil || Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            productVC = ProductViewController(nibName: nibName, bundle: nil)
        } else {
            productVC = ProductViewController()
        }
        if let first = featuredItems.first { productVC.configure(with: first) }
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
            let rowHeight: CGFloat = 100

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
            categoriesVC.hidesBottomBarWhenPushed = true
            navigationController?.setNavigationBarHidden(false, animated: true)
            navigationController?.pushViewController(categoriesVC, animated: true)
        } else {
            assertionFailure("Storyboard ID 'Categories' is not a CategoriesViewController.")
        }
    }

    // Helper: map category title to background asset name
    private func categoryBackgroundAsset(for title: String) -> String? {
        switch title {
        case "Electronics": return "ElectronicsBG"
        case "Tools":       return "ToolsBG"
        case "Events":      return "EventsBG"
        case "Fitness":     return "FitnessBG"
        case "Hobbies":     return "HobbiesBG"
        case "Outdoor":     return "OutdoorBG"
        default:            return nil
        }
    }

    // MARK: - UICollectionViewDataSource (single implementation branching by collection)
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView === trendingCollectionView {
            return trendingItems.count
        }
        return categoriesList.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView === trendingCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TrendingItemCell.reuseID, for: indexPath) as! TrendingItemCell
            let item = trendingItems[indexPath.item]
            cell.configure(with: item, currencyFormatter: currencyFormatter)
            cell.onRentTapped = { [weak self] in
                self?.openRequestView(for: item)
            }
            // Owner name removed from trending UI; no resolution or setting here.
            return cell
        }

        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Category", for: indexPath) as? CategoryCollectionViewCell else {
            assertionFailure("Could not dequeue CategoryCollectionViewCell with identifier 'Category'")
            return UICollectionViewCell()
        }

        let item = categoriesList[indexPath.item]
        cell.categoryLabel.text = item.title

        // Background image from assets (full-bleed)
        if let assetName = categoryBackgroundAsset(for: item.title) {
            cell.categoryBg.image = UIImage(named: assetName)
            cell.categoryBg.contentMode = .scaleAspectFill
            cell.categoryBg.clipsToBounds = true
        } else {
            cell.categoryBg.image = nil
        }

        // Foreground icon (SF Symbol) and style
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .regular, scale: .medium)
        cell.categoryImage.preferredSymbolConfiguration = config
        cell.categoryImage.image = UIImage(systemName: item.systemImageName)
        // Light icon tint for readability on photos
        cell.categoryImage.tintColor = UIColor(white: 1.0, alpha: 0.92)

        // Label styling for readability
        cell.categoryLabel.textColor = .white
        cell.categoryLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        // Optional subtle text shadow to help over bright areas
        cell.categoryLabel.shadowColor = UIColor.black.withAlphaComponent(0.35)
        cell.categoryLabel.shadowOffset = CGSize(width: 0, height: 1)

        // Rounded corners on the tile
        cell.contentView.layer.cornerRadius = 12
        cell.contentView.layer.masksToBounds = true

        // Clear background so the asset shows cleanly
        cell.contentView.backgroundColor = .clear
        cell.backgroundColor = .clear

        return cell
    }

    // MARK: - UICollectionViewDelegate (single implementation branching by collection)

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if collectionView === trendingCollectionView {
            // Prevent cell selection when the user taps the Rent button
            guard let cell = collectionView.cellForItem(at: indexPath) as? TrendingItemCell else { return true }
            let touchPoint = collectionView.panGestureRecognizer.location(in: cell)
            let buttonFrame = cell.rentButton.convert(cell.rentButton.bounds, to: cell)
            if buttonFrame.contains(touchPoint) {
                cell.rentTapped()
                return false
            }
        }
        return true
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView === trendingCollectionView {
            let item = trendingItems[indexPath.item]
            guard ensureItemVisible(item) else { return }
            openItem(item)
            return
        }
        let item = categoriesList[indexPath.item]
        pushCategories(title: item.title)
    }

    // MARK: - UICollectionViewDelegateFlowLayout (size only for trending; categories use compositional layout)
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView === trendingCollectionView {
            let height = collectionView.bounds.height
            return CGSize(width: 280, height: height)
        }
        // Not used for categories; compositional layout controls it.
        return CGSize(width: 70, height: 70)
    }

    // MARK: - UITabBarDelegate

    // featured item 1
    @IBOutlet weak var item1Image: UIImageView!
    @IBOutlet weak var item1Name: UILabel!
    @IBOutlet weak var item1Rate: UILabel!
    @IBOutlet weak var item1Rating: UILabel!
    @IBOutlet weak var item1Distance: UILabel!
    @IBOutlet weak var item1CardView: UIView!
    @IBOutlet weak var rentButton1: UIButton!
    @IBOutlet weak var item1owner: UILabel!
    
    // featured item 2
    @IBOutlet weak var item2Image: UIImageView!
    @IBOutlet weak var item2Name: UILabel!
    @IBOutlet weak var item2Rate: UILabel!
    @IBOutlet weak var item2Rating: UILabel!
    @IBOutlet weak var item2Distance: UILabel!
    @IBOutlet weak var item2CardView: UIView!
    @IBOutlet weak var rentButton2: UIButton!
    @IBOutlet weak var item2owner: UILabel!
    
    // featured item 3
    @IBOutlet weak var item3Image: UIImageView!
    @IBOutlet weak var item3Name: UILabel!
    @IBOutlet weak var item3Rate: UILabel!
    @IBOutlet weak var item3Rating: UILabel!
    @IBOutlet weak var item3Distance: UILabel!
    @IBOutlet weak var item3CardView: UIView!
    @IBOutlet weak var rentButton3: UIButton!
    @IBOutlet weak var item3owner: UILabel!
    
    // featured item 4
    @IBOutlet weak var item4Image: UIImageView!
    @IBOutlet weak var item4Name: UILabel!
    @IBOutlet weak var item4Rate: UILabel!
    @IBOutlet weak var item4Rating: UILabel!
    @IBOutlet weak var item4Distance: UILabel!
    @IBOutlet weak var item4CardView: UIView!
    @IBOutlet weak var rentButton4: UIButton!
    @IBOutlet weak var item4owner: UILabel!
    
    // MARK: - Greeting helper
    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        
        switch hour {
        case 0..<12:
            // 12:00am - 11:59am
            greeting = "Good morning"
        case 12..<16:
            // 12:00pm - 3:59pm
            greeting = "Good afternoon"
        default:
            // 4:00pm - 11:59pm
            greeting = "Good evening"
        }
        
        greetingTop?.text = greeting
    }
}

private extension HomeViewController {
    func ensureItemVisible(_ item: Item) -> Bool {
        guard !safetyService.isBlocked(item.owner_id) else {
            let alert = UIAlertController(
                title: "User Blocked",
                message: "You blocked the owner of this item. Unblock them in Privacy & Security to view their listing again.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return false
        }
        return true
    }
}

// MARK: - Location handling (sheet + persistence)
extension HomeViewController {
    func refreshLocationButtonTitle() {
        if SavedAddressesStore.shared.getDefaultSelectedAddress() == nil {
            let defaultGeocodable = "Chennai, Tamil Nadu, India"
            SavedAddressesStore.shared.setDefaultSelectedAddress(defaultGeocodable)
        }

        let storedAddress = SavedAddressesStore.shared.getDefaultSelectedAddress() ?? "Chennai"
        
        let displayText: String = {
            let trimmed = storedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return "Chennai" }
            let components = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if let firstComponent = components.first(where: { !$0.isEmpty }) {
                return firstComponent
            }
            return trimmed
        }()
        
        locationTapped?.setTitle(displayText, for: .normal)
        locationTapped?.setTitleColor(UIColor(red: 112/255, green: 167/255, blue: 180/255, alpha: 1.0), for: .normal)
        locationTapped?.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        configureLocationButtonAppearance()
    }

    func makeFullAddressString(from addr: Address) -> String {
        let parts = [
            addr.address_line1,
            addr.address_line2,
            addr.city,
            addr.state,
            addr.postal_code,
            addr.country
        ]
        return parts
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    @IBAction func locationTappedAction(_ sender: UIButton) {
        assert(locationTapped == nil || sender === locationTapped, "locationTappedAction fired from a different control than locationTapped outlet.")

        let vc = LocationSelectorViewController()

        if #available(iOS 15.0, *) {
            vc.modalPresentationStyle = .pageSheet
        } else {
            vc.modalPresentationStyle = .pageSheet
        }

        vc.onSelectedAddress = { [weak self] _ in
            self?.refreshLocationButtonTitle()
        }

        vc.onEnterManualAddress = { [weak self] completion in
            guard let self = self else { return }
            let form = ManualAddressViewController()
            form.onSaved = { saved in
                let display = [saved.label, saved.city, saved.state].compactMap { $0 }.first ?? saved.city
                let fullString = self.makeFullAddressString(from: saved)
                SavedAddressesStore.shared.setDefaultSelectedAddress(fullString)
                self.refreshLocationButtonTitle()
                completion(display)
            }
            if let nav = self.navigationController {
                nav.setNavigationBarHidden(false, animated: true)
                nav.pushViewController(form, animated: true)
            } else {
                let nav = UINavigationController(rootViewController: form)
                nav.modalPresentationStyle = .fullScreen
                self.present(nav, animated: true)
            }
        }

        vc.onManageSavedAddresses = { [weak self] in
            guard let self = self else { return }
            let list = ManageAddressesViewController()
            list.onPicked = { [weak self] addr in
                guard let self = self else { return }
                let display = [addr.label, addr.city, addr.state].compactMap { $0 }.first ?? addr.city
                let fullString = self.makeFullAddressString(from: addr)
                SavedAddressesStore.shared.setDefaultSelectedAddress(fullString)
                self.refreshLocationButtonTitle()
            }
            if let nav = self.navigationController {
                nav.setNavigationBarHidden(false, animated: true)
                nav.pushViewController(list, animated: true)
            } else {
                let nav = UINavigationController(rootViewController: list)
                nav.modalPresentationStyle = .fullScreen
                self.present(nav, animated: true)
            }
        }

        if let sheet = vc.presentationController as? UISheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 16
        }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()

        present(vc, animated: true) {
            generator.impactOccurred()
        }
    }

    func presentSavedAddressesManager() {
        let listVC = ManageAddressesViewController()
        if let nav = self.navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(listVC, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: listVC)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }

    func presentAddAddressPrompt() {
        let form = ManualAddressViewController()
        if let nav = self.navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(form, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: form)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }
}
