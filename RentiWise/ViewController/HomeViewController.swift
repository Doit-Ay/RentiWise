//
//  HomeViewController.swift
//  RentiWise
//
//  Created by admin99 on 03/11/25.
//

import UIKit
import Supabase
import CoreLocation

final class HomeViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate {

    private typealias FeaturedCardComponents = (
        card: UIView,
        imageView: UIImageView,
        nameLabel: UILabel,
        rateLabel: UILabel,
        ratingLabel: UILabel,
        distanceLabel: UILabel,
        ownerLabel: UILabel,
        rentButton: UIButton
    )

    struct CategoryItem {
        let title: String
        let systemImageName: String
    }

    private let scrollView = UIScrollView()
    var homeBG: UIView!
    var contentStackView: UIStackView!

    var greetingTop: UILabel!
    var locationTapped: UIButton!
    var searchBar: UISearchBar!
    var collectionView: UICollectionView!
    var notificationBell: UIButton!
    var listingUIView: UIView!
    var trendingTitleLabel: UILabel!
    var trendingUiView: UIView!
    var newArrivalsTitleLabel: UILabel!
    var featuredCardsStackView: UIStackView!
    var Homepagelastline: UILabel!

    var item1Image: UIImageView!
    var item1Name: UILabel!
    var item1Rate: UILabel!
    var item1Rating: UILabel!
    var item1Distance: UILabel!
    var item1CardView: UIView!
    var rentButton1: UIButton!
    var item1owner: UILabel!

    var item2Image: UIImageView!
    var item2Name: UILabel!
    var item2Rate: UILabel!
    var item2Rating: UILabel!
    var item2Distance: UILabel!
    var item2CardView: UIView!
    var rentButton2: UIButton!
    var item2owner: UILabel!

    var item3Image: UIImageView!
    var item3Name: UILabel!
    var item3Rate: UILabel!
    var item3Rating: UILabel!
    var item3Distance: UILabel!
    var item3CardView: UIView!
    var rentButton3: UIButton!
    var item3owner: UILabel!

    var item4Image: UIImageView!
    var item4Name: UILabel!
    var item4Rate: UILabel!
    var item4Rating: UILabel!
    var item4Distance: UILabel!
    var item4CardView: UIView!
    var rentButton4: UIButton!
    var item4owner: UILabel!

    var categoriesList: [CategoryItem] = [
        .init(title: "Electronics", systemImageName: "drone"),
        .init(title: "Tools", systemImageName: "hammer"),
        .init(title: "Events", systemImageName: "hifispeaker"),
        .init(title: "Fitness", systemImageName: "dumbbell"),
        .init(title: "Hobbies", systemImageName: "guitars"),
        .init(title: "Outdoor", systemImageName: "tent"),
    ]

    let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    var featuredItems: [Item] = []

    var isListingDataLoaded = false
    var manageContainerView: UIView?
    var emptyListingBannerView: UIView?
    var homeFeedEmptyBannerView: UIView?
    var shouldPreferHomeFeedEmptyBanner = false

    private var isFirstLoad = true
    private(set) var isUserLoggedIn = false
    private var loggedOutOverlayView: UIView?
    private var loadingSpinner: UIActivityIndicatorView?

    var trendingCollectionView: UICollectionView?
    var trendingItems: [Item] = []
    var trendingSortGeneration: UUID?
    var ownerNameCache: [String: String] = [:]

    private var lastFeaturedRentTap: (index: Int, timestamp: TimeInterval)?
    private var lastTrendingRentTap: (itemId: String, timestamp: TimeInterval)?
    private let rentTapSuppressionWindow: TimeInterval = 0.6

    var homeSearch: HomeSearchController?
    private let safetyService = CommunitySafetyService.shared
    let itemsService = ItemsService()
    let tabBarDelegate = TabBarNavigationDelegate()

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

        setupUI()

        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.alwaysBounceVertical = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.setCollectionViewLayout(generateHorizontalFourUpLayout(), animated: false)
        collectionView.backgroundColor = .clear

        searchBar.applyRentiWiseStyle()
        configureLocationButtonAppearance()

        setupFeaturedItemTaps()
        // Hide all content sections initially — will be revealed based on auth state
        listingUIView.isHidden = true
        featuredCardsStackView.isHidden = true
        newArrivalsTitleLabel.isHidden = true
        trendingTitleLabel.isHidden = true
        trendingUiView.isHidden = true
        collectionView.isHidden = true
        searchBar.isHidden = true
        locationTapped.isHidden = true
        Homepagelastline.isHidden = true

        setupTrendingCollection()
        refreshLocationButtonTitle()

        let homeSearch = HomeSearchController(searchBar: searchBar, in: view)
        homeSearch.onSelectItem = { [weak self] item in
            self?.openItem(item)
        }
        self.homeSearch = homeSearch

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboardTap))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)

        setBottomTagline()
        navigationController?.delegate = tabBarDelegate
        navigationController?.tabBarItem.title = "Explore"

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBlockedUsersChanged),
            name: CommunitySafetyService.blockedUsersDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotificationsUpdated),
            name: .notificationsDidUpdate,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleItemsShouldRefresh),
            name: Notification.Name("itemsShouldRefresh"),
            object: nil
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        homeSearch?.layoutForSearchBarBelow()
        applyGlassToFeaturedCardsIfNeeded()
        applyGlassToRentButtonsIfNeeded()
        applyGlassToHeaderRoundButtons()
        refreshEmptyListingBannerLayoutIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
        tabBarController?.tabBar.isHidden = false
        updateGreeting()

        let isColdStart = isFirstLoad
        isFirstLoad = false

        Task {
            // Check auth state first
            let userId = await SupabaseManager.shared.currentUserId()
            let loggedIn = userId != nil

            await MainActor.run {
                self.isUserLoggedIn = loggedIn
                self.applyAuthState()
            }

            guard loggedIn else { return }

            // Logged in — show loading state and fetch data
            await MainActor.run {
                self.showContentLoadingState()
            }

            if isColdStart, !PreloadManager.shared.isComplete {
                await PreloadManager.shared.waitForCompletion(timeout: 4.0)
            }

            self.refreshLocationButtonTitle()

            async let listings: () = checkAndUpdateListingSection(forceRefresh: !isColdStart)
            async let badge: () = updateNotificationBadge()
            async let featured: () = loadFeaturedItems(forceRefresh: true)
            _ = await (listings, badge, featured)

            await MainActor.run {
                self.hideContentLoadingState()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        collectionView.setCollectionViewLayout(generateHorizontalFourUpLayout(), animated: false)
    }

    @objc private func handleItemsShouldRefresh() {
        Task {
            await checkAndUpdateListingSection(forceRefresh: true)
            await loadFeaturedItems(forceRefresh: true)
        }
    }

    @objc private func dismissKeyboardTap() {
        view.endEditing(true)
        homeSearch?.layoutForSearchBarBelow()
    }

    @objc private func handleBlockedUsersChanged() {
        Task { await loadFeaturedItems(forceRefresh: true) }
    }

    @objc private func handleNotificationsUpdated() {
        Task { await updateNotificationBadge() }
    }

    @objc func notificationBellTapped(_ sender: UIButton) {
        guard isUserLoggedIn else {
            Task { _ = await ensureAuthenticated(orOpen: .signUp) }
            return
        }
        let nibName = "NotificationViewController"
        let viewController: NotificationViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
            Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            viewController = NotificationViewController(nibName: nibName, bundle: nil)
        } else {
            viewController = NotificationViewController()
        }
        viewController.title = "Notifications"
        viewController.hidesBottomBarWhenPushed = true

        if let navigationController {
            navigationController.setNavigationBarHidden(false, animated: true)
            navigationController.pushViewController(viewController, animated: true)
        } else {
            let navigationController = UINavigationController(rootViewController: viewController)
            navigationController.modalPresentationStyle = .fullScreen
            present(navigationController, animated: true)
        }
    }

    @objc func requestsButtonTapped(_ sender: UIButton) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let session = try await SupabaseManager.shared.client.auth.session
                _ = session.user

                let viewController = RequestsListViewController()
                viewController.title = "Requests"
                viewController.hidesBottomBarWhenPushed = true

                if let navigationController = self.navigationController {
                    navigationController.setNavigationBarHidden(false, animated: true)
                    navigationController.pushViewController(viewController, animated: true)
                } else {
                    let navigationController = UINavigationController(rootViewController: viewController)
                    navigationController.modalPresentationStyle = .fullScreen
                    self.present(navigationController, animated: true)
                }
            } catch {
                let signInViewController = SignViewController()
                signInViewController.routeContext = .default
                signInViewController.title = "Sign in"
                signInViewController.hidesBottomBarWhenPushed = true

                if let navigationController = self.navigationController {
                    navigationController.setNavigationBarHidden(false, animated: true)
                    navigationController.pushViewController(signInViewController, animated: true)
                } else {
                    let navigationController = UINavigationController(rootViewController: signInViewController)
                    navigationController.modalPresentationStyle = .fullScreen
                    self.present(navigationController, animated: true)
                }
            }
        }
    }

    @objc func additemHomeTapped(_ sender: UIButton) {
        Task { [weak self] in
            guard let self else { return }
            if await self.ensureAuthenticated(orOpen: .signUp) {
                let viewController = AddItemFirstViewController(nibName: "AddItemFirstViewController", bundle: nil)
                viewController.title = "Add item"
                viewController.hidesBottomBarWhenPushed = true

                if let navigationController = self.navigationController {
                    navigationController.setNavigationBarHidden(false, animated: false)
                    navigationController.pushViewController(viewController, animated: true)
                } else {
                    viewController.modalPresentationStyle = .fullScreen
                    self.present(viewController, animated: true)
                }
            }
        }
    }

    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .interactive

        homeBG = UIView()
        homeBG.translatesAutoresizingMaskIntoConstraints = false
        homeBG.backgroundColor = .clear
        homeBG.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 20, leading: 16, bottom: 32, trailing: 16)

        contentStackView = UIStackView()
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.spacing = 20

        view.addSubview(scrollView)
        scrollView.addSubview(homeBG)
        homeBG.addSubview(contentStackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            homeBG.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            homeBG.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            homeBG.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            homeBG.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            homeBG.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            contentStackView.topAnchor.constraint(equalTo: homeBG.layoutMarginsGuide.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: homeBG.layoutMarginsGuide.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: homeBG.layoutMarginsGuide.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: homeBG.layoutMarginsGuide.bottomAnchor)
        ])

        let headerView = buildHeaderView()
        locationTapped = buildLocationButton()
        searchBar = buildSearchBar()
        collectionView = buildCategoriesCollectionView()
        listingUIView = buildListingContainer()
        trendingTitleLabel = makeSectionTitleLabel(text: "Trending near you")
        trendingUiView = buildTrendingContainer()
        newArrivalsTitleLabel = makeSectionTitleLabel(text: "New Arrivals")
        featuredCardsStackView = buildFeaturedCardsStack()
        Homepagelastline = buildTaglineLabel()

        contentStackView.addArrangedSubview(headerView)
        contentStackView.addArrangedSubview(locationTapped)
        contentStackView.addArrangedSubview(searchBar)
        contentStackView.addArrangedSubview(collectionView)
        contentStackView.addArrangedSubview(listingUIView)
        contentStackView.addArrangedSubview(trendingTitleLabel)
        contentStackView.addArrangedSubview(trendingUiView)
        contentStackView.addArrangedSubview(newArrivalsTitleLabel)
        contentStackView.addArrangedSubview(featuredCardsStackView)
        contentStackView.addArrangedSubview(Homepagelastline)

        contentStackView.setCustomSpacing(10, after: headerView)
        contentStackView.setCustomSpacing(10, after: locationTapped)
        contentStackView.setCustomSpacing(16, after: searchBar)
        contentStackView.setCustomSpacing(16, after: listingUIView)
        contentStackView.setCustomSpacing(16, after: trendingTitleLabel)
        contentStackView.setCustomSpacing(16, after: newArrivalsTitleLabel)
        contentStackView.setCustomSpacing(24, after: featuredCardsStackView)

        buildFeaturedCards()
    }

    private func buildHeaderView() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        greetingTop = UILabel()
        greetingTop.translatesAutoresizingMaskIntoConstraints = false
        greetingTop.font = .systemFont(ofSize: 30, weight: .bold)
        greetingTop.textColor = .label
        greetingTop.numberOfLines = 1

        notificationBell = UIButton(type: .system)
        notificationBell.translatesAutoresizingMaskIntoConstraints = false
        notificationBell.tintColor = .white
        notificationBell.backgroundColor = .clear
        notificationBell.setImage(
            UIImage(
                systemName: "bell",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
            ),
            for: .normal
        )
        notificationBell.addTarget(self, action: #selector(notificationBellTapped(_:)), for: .touchUpInside)
        notificationBell.accessibilityLabel = "Notifications"

        container.addSubview(greetingTop)
        container.addSubview(notificationBell)

        NSLayoutConstraint.activate([
            greetingTop.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            greetingTop.topAnchor.constraint(equalTo: container.topAnchor),
            greetingTop.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            notificationBell.leadingAnchor.constraint(greaterThanOrEqualTo: greetingTop.trailingAnchor, constant: 16),
            notificationBell.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            notificationBell.centerYAnchor.constraint(equalTo: greetingTop.centerYAnchor),
            notificationBell.widthAnchor.constraint(equalToConstant: 44),
            notificationBell.heightAnchor.constraint(equalToConstant: 44)
        ])

        return container
    }

    private func buildLocationButton() -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = UIColor(red: 112 / 255, green: 167 / 255, blue: 180 / 255, alpha: 1)
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(
            systemName: "mappin.and.ellipse",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        )
        configuration.imagePadding = 7
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
        configuration.titleAlignment = .leading
        button.configuration = configuration
        button.contentHorizontalAlignment = .leading
        button.addTarget(self, action: #selector(locationTappedAction(_:)), for: .touchUpInside)
        return button
    }

    private func buildSearchBar() -> UISearchBar {
        let searchBar = UISearchBar()
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = "Search items"
        NSLayoutConstraint.activate([
            searchBar.heightAnchor.constraint(equalToConstant: 56)
        ])
        return searchBar
    }

    private func buildCategoriesCollectionView() -> UICollectionView {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: generateHorizontalFourUpLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(CategoryCollectionViewCell.self, forCellWithReuseIdentifier: CategoryCollectionViewCell.reuseIdentifier)
        NSLayoutConstraint.activate([
            collectionView.heightAnchor.constraint(equalToConstant: 120)
        ])
        return collectionView
    }

    private func buildListingContainer() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .clear
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 182)
        ])
        return container
    }

    private func buildTrendingContainer() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .systemGroupedBackground
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 300)
        ])
        return container
    }

    private func buildFeaturedCardsStack() -> UIStackView {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 16
        return stackView
    }

    private func buildTaglineLabel() -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 17, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 1
        return label
    }

    private func makeSectionTitleLabel(text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }

    private func buildFeaturedCards() {
        let card1 = makeFeaturedCard()
        item1CardView = card1.card
        item1Image = card1.imageView
        item1Name = card1.nameLabel
        item1Rate = card1.rateLabel
        item1Rating = card1.ratingLabel
        item1Distance = card1.distanceLabel
        item1owner = card1.ownerLabel
        rentButton1 = card1.rentButton

        let card2 = makeFeaturedCard()
        item2CardView = card2.card
        item2Image = card2.imageView
        item2Name = card2.nameLabel
        item2Rate = card2.rateLabel
        item2Rating = card2.ratingLabel
        item2Distance = card2.distanceLabel
        item2owner = card2.ownerLabel
        rentButton2 = card2.rentButton

        let card3 = makeFeaturedCard()
        item3CardView = card3.card
        item3Image = card3.imageView
        item3Name = card3.nameLabel
        item3Rate = card3.rateLabel
        item3Rating = card3.ratingLabel
        item3Distance = card3.distanceLabel
        item3owner = card3.ownerLabel
        rentButton3 = card3.rentButton

        let card4 = makeFeaturedCard()
        item4CardView = card4.card
        item4Image = card4.imageView
        item4Name = card4.nameLabel
        item4Rate = card4.rateLabel
        item4Rating = card4.ratingLabel
        item4Distance = card4.distanceLabel
        item4owner = card4.ownerLabel
        rentButton4 = card4.rentButton

        featuredCardsStackView.addArrangedSubview(card1.card)
        featuredCardsStackView.addArrangedSubview(card2.card)
        featuredCardsStackView.addArrangedSubview(card3.card)
        featuredCardsStackView.addArrangedSubview(card4.card)
    }

    private func makeFeaturedCard() -> FeaturedCardComponents {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .clear

        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .secondarySystemBackground

        let nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.numberOfLines = 2

        let rateLabel = UILabel()
        rateLabel.translatesAutoresizingMaskIntoConstraints = false
        rateLabel.font = .systemFont(ofSize: 12, weight: .regular)
        rateLabel.textColor = .secondaryLabel

        let ratingLabel = UILabel()
        ratingLabel.translatesAutoresizingMaskIntoConstraints = false
        ratingLabel.font = .systemFont(ofSize: 13, weight: .medium)
        ratingLabel.textColor = .label

        let distanceIcon = UIImageView(
            image: UIImage(
                systemName: "mappin.and.ellipse",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            )
        )
        distanceIcon.translatesAutoresizingMaskIntoConstraints = false
        distanceIcon.tintColor = UIColor(red: 112 / 255, green: 167 / 255, blue: 180 / 255, alpha: 1)
        distanceIcon.contentMode = .scaleAspectFit

        let distanceLabel = UILabel()
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        distanceLabel.font = .systemFont(ofSize: 13, weight: .regular)
        distanceLabel.textColor = .secondaryLabel

        let byLabel = UILabel()
        byLabel.translatesAutoresizingMaskIntoConstraints = false
        byLabel.text = "By:"
        byLabel.font = .systemFont(ofSize: 14, weight: .regular)
        byLabel.textColor = .secondaryLabel

        let ownerLabel = UILabel()
        ownerLabel.translatesAutoresizingMaskIntoConstraints = false
        ownerLabel.font = .systemFont(ofSize: 14, weight: .regular)
        ownerLabel.textColor = .label

        let rentButton = UIButton(type: .system)
        rentButton.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.plain()
        configuration.title = "Rent"
        rentButton.configuration = configuration

        card.addSubview(imageView)
        card.addSubview(nameLabel)
        card.addSubview(rateLabel)
        card.addSubview(ratingLabel)
        card.addSubview(distanceIcon)
        card.addSubview(distanceLabel)
        card.addSubview(byLabel)
        card.addSubview(ownerLabel)
        card.addSubview(rentButton)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 140),

            imageView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            imageView.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            imageView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            imageView.widthAnchor.constraint(equalToConstant: 130),

            nameLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            nameLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),

            rateLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            rateLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),

            ratingLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            ratingLabel.topAnchor.constraint(equalTo: rateLabel.bottomAnchor, constant: 10),

            distanceIcon.leadingAnchor.constraint(equalTo: ratingLabel.trailingAnchor, constant: 25),
            distanceIcon.centerYAnchor.constraint(equalTo: ratingLabel.centerYAnchor),
            distanceIcon.widthAnchor.constraint(equalToConstant: 14),
            distanceIcon.heightAnchor.constraint(equalToConstant: 18),

            distanceLabel.leadingAnchor.constraint(equalTo: distanceIcon.trailingAnchor, constant: 5),
            distanceLabel.centerYAnchor.constraint(equalTo: distanceIcon.centerYAnchor),

            byLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            byLabel.topAnchor.constraint(equalTo: ratingLabel.bottomAnchor, constant: 14),

            ownerLabel.leadingAnchor.constraint(equalTo: byLabel.trailingAnchor, constant: 5),
            ownerLabel.centerYAnchor.constraint(equalTo: byLabel.centerYAnchor),
            ownerLabel.trailingAnchor.constraint(lessThanOrEqualTo: rentButton.leadingAnchor, constant: -16),

            rentButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            rentButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
            rentButton.widthAnchor.constraint(equalToConstant: 70),
            rentButton.heightAnchor.constraint(equalToConstant: 32)
        ])

        return (card, imageView, nameLabel, rateLabel, ratingLabel, distanceLabel, ownerLabel, rentButton)
    }

    private func configureLocationButtonAppearance() {
        let button = locationTapped
        button?.titleLabel?.numberOfLines = 1
        button?.titleLabel?.lineBreakMode = .byTruncatingTail
        button?.titleLabel?.adjustsFontSizeToFitWidth = false
        button?.contentHorizontalAlignment = .leading
        button?.setContentCompressionResistancePriority(.required, for: .horizontal)
        if button?.currentImage != nil {
            button?.semanticContentAttribute = .forceLeftToRight
        }
    }

    private func setupFeaturedItemTaps() {
        let imageTap1 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured1))
        item1Image.isUserInteractionEnabled = true
        item1Image.addGestureRecognizer(imageTap1)

        let imageTap2 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured2))
        item2Image.isUserInteractionEnabled = true
        item2Image.addGestureRecognizer(imageTap2)

        let imageTap3 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured3))
        item3Image.isUserInteractionEnabled = true
        item3Image.addGestureRecognizer(imageTap3)

        let imageTap4 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured4))
        item4Image.isUserInteractionEnabled = true
        item4Image.addGestureRecognizer(imageTap4)

        let cardTap1 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured1))
        cardTap1.cancelsTouchesInView = false
        cardTap1.delegate = self
        item1CardView.isUserInteractionEnabled = true
        item1CardView.addGestureRecognizer(cardTap1)

        let cardTap2 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured2))
        cardTap2.cancelsTouchesInView = false
        cardTap2.delegate = self
        item2CardView.isUserInteractionEnabled = true
        item2CardView.addGestureRecognizer(cardTap2)

        let cardTap3 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured3))
        cardTap3.cancelsTouchesInView = false
        cardTap3.delegate = self
        item3CardView.isUserInteractionEnabled = true
        item3CardView.addGestureRecognizer(cardTap3)

        let cardTap4 = UITapGestureRecognizer(target: self, action: #selector(didTapFeatured4))
        cardTap4.cancelsTouchesInView = false
        cardTap4.delegate = self
        item4CardView.isUserInteractionEnabled = true
        item4CardView.addGestureRecognizer(cardTap4)
    }

    @objc private func didTapFeatured1() { openFeatured(at: 0) }
    @objc private func didTapFeatured2() { openFeatured(at: 1) }
    @objc private func didTapFeatured3() { openFeatured(at: 2) }
    @objc private func didTapFeatured4() { openFeatured(at: 3) }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let view = gestureRecognizer.view else { return true }
        let location = gestureRecognizer.location(in: view)
        if let hitView = view.hitTest(location, with: nil) {
            if hitView is UIButton { return false }
            var ancestor = hitView.superview
            while let current = ancestor, current !== view {
                if current is UIButton { return false }
                ancestor = current.superview
            }
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var current: UIView? = touch.view
        while let view = current {
            if view is UIControl { return false }
            if view === gestureRecognizer.view { break }
            current = view.superview
        }
        return true
    }

    private func openFeatured(at index: Int) {
        guard index < featuredItems.count else { return }
        guard !shouldSuppressFeaturedSelection(for: index) else { return }
        let item = featuredItems[index]
        guard ensureItemVisible(item) else { return }

        let nibName = "ProductViewController"
        let productViewController: ProductViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
            Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            productViewController = ProductViewController(nibName: nibName, bundle: nil)
        } else {
            productViewController = ProductViewController()
        }
        productViewController.configure(with: item)
        productViewController.title = "Product Detail"
        productViewController.hidesBottomBarWhenPushed = true

        if let navigationController {
            navigationController.setNavigationBarHidden(false, animated: true)
            navigationController.pushViewController(productViewController, animated: true)
        } else {
            productViewController.modalPresentationStyle = .fullScreen
            present(productViewController, animated: true)
        }
    }

    private func openItem(_ item: Item) {
        guard ensureItemVisible(item) else { return }

        let nibName = "ProductViewController"
        let productViewController: ProductViewController
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
            Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
            productViewController = ProductViewController(nibName: nibName, bundle: nil)
        } else {
            productViewController = ProductViewController()
        }
        productViewController.configure(with: item)
        productViewController.title = "Product Detail"
        productViewController.hidesBottomBarWhenPushed = true

        if let navigationController {
            navigationController.setNavigationBarHidden(false, animated: true)
            navigationController.pushViewController(productViewController, animated: true)
        } else {
            productViewController.modalPresentationStyle = .fullScreen
            present(productViewController, animated: true)
        }
    }

    func openRequestView(for item: Item) {
        guard ensureItemVisible(item) else { return }
        Task { [weak self] in
            guard let self else { return }
            guard await self.ensureAuthenticated(orOpen: .signUp) else { return }

            let nibName = "RequestViewController"
            let requestViewController: RequestViewController
            if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
                Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
                requestViewController = RequestViewController(nibName: nibName, bundle: nil)
            } else {
                requestViewController = RequestViewController()
            }
            requestViewController.configure(with: item)
            requestViewController.title = "Request"
            requestViewController.hidesBottomBarWhenPushed = true

            if let navigationController = self.navigationController {
                navigationController.setNavigationBarHidden(false, animated: true)
                navigationController.pushViewController(requestViewController, animated: true)
            } else {
                let navigationController = UINavigationController(rootViewController: requestViewController)
                navigationController.modalPresentationStyle = .fullScreen
                self.present(navigationController, animated: true)
            }
        }
    }

    private func generateHorizontalFourUpLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { _, _ in
            let interItemSpacing: CGFloat = 10
            let contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(0.25),
                heightDimension: .fractionalHeight(1.0)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(
                top: 0,
                leading: interItemSpacing / 2,
                bottom: 0,
                trailing: interItemSpacing / 2
            )

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(100)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = contentInsets
            section.orthogonalScrollingBehavior = .groupPaging
            return section
        }
    }

    private func pushCategories(title: String) {
        guard let categoriesViewController = AppRootBuilder.makeCategoriesViewController() else {
            assertionFailure("Could not instantiate CategoriesViewController from AppStarting storyboard.")
            return
        }

        categoriesViewController.category = title
        categoriesViewController.title = title
        categoriesViewController.hidesBottomBarWhenPushed = true
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.pushViewController(categoriesViewController, animated: true)
    }

    private func categoryBackgroundAsset(for title: String) -> String? {
        switch title {
        case "Electronics": return "ElectronicsBG"
        case "Tools": return "ToolsBG"
        case "Events": return "EventsBG"
        case "Fitness": return "FitnessBG"
        case "Hobbies": return "HobbiesBG"
        case "Outdoor": return "OutdoorBG"
        default: return nil
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView === trendingCollectionView {
            return trendingItems.count
        }
        return categoriesList.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView === trendingCollectionView {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: TrendingItemCell.reuseID,
                for: indexPath
            ) as? TrendingItemCell else {
                assertionFailure("Could not dequeue TrendingItemCell")
                return UICollectionViewCell()
            }

            let item = trendingItems[indexPath.item]
            cell.configure(with: item, currencyFormatter: currencyFormatter)
            cell.onRentTapped = { [weak self] in
                self?.markTrendingRentTap(itemId: item.id)
                self?.openRequestView(for: item)
            }
            return cell
        }

        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CategoryCollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as? CategoryCollectionViewCell else {
            assertionFailure("Could not dequeue CategoryCollectionViewCell")
            return UICollectionViewCell()
        }

        let item = categoriesList[indexPath.item]
        cell.categoryLabel.text = item.title

        if let assetName = categoryBackgroundAsset(for: item.title) {
            cell.categoryBg.image = UIImage(named: assetName)
            cell.categoryBg.contentMode = .scaleAspectFill
            cell.categoryBg.clipsToBounds = true
        } else {
            cell.categoryBg.image = nil
        }

        let configuration = UIImage.SymbolConfiguration(pointSize: 28, weight: .regular, scale: .medium)
        cell.categoryImage.preferredSymbolConfiguration = configuration
        cell.categoryImage.image = UIImage(systemName: item.systemImageName)
        cell.categoryImage.tintColor = UIColor(white: 1.0, alpha: 0.92)

        cell.categoryLabel.textColor = .white
        cell.categoryLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        cell.categoryLabel.shadowColor = UIColor.black.withAlphaComponent(0.35)
        cell.categoryLabel.shadowOffset = CGSize(width: 0, height: 1)

        cell.contentView.backgroundColor = .clear
        cell.backgroundColor = .clear

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        true
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView === trendingCollectionView {
            let item = trendingItems[indexPath.item]
            guard !shouldSuppressTrendingSelection(for: item.id) else { return }
            guard ensureItemVisible(item) else { return }
            openItem(item)
            return
        }

        // Gate category browsing behind auth
        guard isUserLoggedIn else {
            Task { _ = await ensureAuthenticated(orOpen: .signUp) }
            return
        }

        let item = categoriesList[indexPath.item]
        pushCategories(title: item.title)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        if collectionView === trendingCollectionView {
            return CGSize(width: 280, height: collectionView.bounds.height)
        }
        return CGSize(width: 70, height: 70)
    }

    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String

        switch hour {
        case 0..<12:
            greeting = "Good morning"
        case 12..<16:
            greeting = "Good afternoon"
        default:
            greeting = "Good evening"
        }

        greetingTop.text = greeting
    }

    // MARK: - Auth-gated UI state

    /// Applies the logged-in / logged-out visual state to the home screen.
    func applyAuthState() {
        if isUserLoggedIn {
            hideLoggedOutOverlay()
            // Reveal content sections (they will be populated by loaders)
            collectionView.isHidden = false
            searchBar.isHidden = false
            locationTapped.isHidden = false
            Homepagelastline.isHidden = false
        } else {
            // Hide everything content-related
            collectionView.isHidden = true
            searchBar.isHidden = true
            locationTapped.isHidden = true
            listingUIView.isHidden = true
            trendingTitleLabel.isHidden = true
            trendingUiView.isHidden = true
            newArrivalsTitleLabel.isHidden = true
            featuredCardsStackView.isHidden = true
            Homepagelastline.isHidden = true
            removeHomeFeedEmptyBanner()
            showLoggedOutOverlay()
        }
    }

    /// Builds and shows a premium "Sign in to explore" overlay
    private func showLoggedOutOverlay() {
        guard loggedOutOverlayView == nil else { return }

        let accentColor = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)
        let lightTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)

        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = .clear

        // --- Animated Hero illustration ---
        let heroWrapper = UIView()
        heroWrapper.translatesAutoresizingMaskIntoConstraints = false

        let iconContainer = UIView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.backgroundColor = accentColor.withAlphaComponent(0.12)
        iconContainer.layer.cornerRadius = 44

        let heroIcon = UIImageView(image: UIImage(systemName: "cube.box.fill"))
        heroIcon.translatesAutoresizingMaskIntoConstraints = false
        heroIcon.tintColor = accentColor
        heroIcon.contentMode = .scaleAspectFit
        iconContainer.addSubview(heroIcon)
        heroWrapper.addSubview(iconContainer)

        // Orbiting decorative icons (small, faded, floating around the hero)
        let orbitIcons = [
            ("camera.fill", CGPoint(x: -50, y: -30)),
            ("tag.fill", CGPoint(x: 52, y: -24)),
            ("mappin.circle.fill", CGPoint(x: -44, y: 32)),
            ("star.fill", CGPoint(x: 48, y: 36))
        ]
        var orbitViews: [UIImageView] = []
        for (name, offset) in orbitIcons {
            let iv = UIImageView(image: UIImage(systemName: name))
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.tintColor = accentColor.withAlphaComponent(0.25)
            iv.contentMode = .scaleAspectFit
            heroWrapper.addSubview(iv)
            NSLayoutConstraint.activate([
                iv.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor, constant: offset.x),
                iv.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor, constant: offset.y),
                iv.widthAnchor.constraint(equalToConstant: 18),
                iv.heightAnchor.constraint(equalToConstant: 18)
            ])
            orbitViews.append(iv)
        }

        NSLayoutConstraint.activate([
            iconContainer.centerXAnchor.constraint(equalTo: heroWrapper.centerXAnchor),
            iconContainer.centerYAnchor.constraint(equalTo: heroWrapper.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 88),
            iconContainer.heightAnchor.constraint(equalToConstant: 88),
            heroIcon.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            heroIcon.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            heroIcon.widthAnchor.constraint(equalToConstant: 38),
            heroIcon.heightAnchor.constraint(equalToConstant: 38),
            heroWrapper.widthAnchor.constraint(equalToConstant: 160),
            heroWrapper.heightAnchor.constraint(equalToConstant: 120)
        ])

        // --- Text ---
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Discover local rentals"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Sign in to browse items near you, list your own gear, and start earning from things you already own."
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        // --- Buttons ---
        let signUpButton = UIButton(type: .system)
        signUpButton.translatesAutoresizingMaskIntoConstraints = false
        var signUpConfig = UIButton.Configuration.filled()
        signUpConfig.baseBackgroundColor = accentColor
        signUpConfig.baseForegroundColor = .white
        signUpConfig.cornerStyle = .large
        signUpConfig.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 32, bottom: 14, trailing: 32)
        var signUpAttrs = AttributeContainer()
        signUpAttrs.font = .systemFont(ofSize: 17, weight: .semibold)
        signUpConfig.attributedTitle = AttributedString("Create Account", attributes: signUpAttrs)
        signUpButton.configuration = signUpConfig
        signUpButton.addTarget(self, action: #selector(loggedOutSignUpTapped), for: .touchUpInside)

        // --- Sign In row ---
        let signInRow = UIStackView()
        signInRow.axis = .horizontal
        signInRow.spacing = 4
        signInRow.alignment = .center
        signInRow.translatesAutoresizingMaskIntoConstraints = false

        let alreadyLabel = UILabel()
        alreadyLabel.text = "Already have an account?"
        alreadyLabel.font = .systemFont(ofSize: 14, weight: .regular)
        alreadyLabel.textColor = .secondaryLabel
        alreadyLabel.setContentHuggingPriority(.required, for: .horizontal)

        let signInLink = UIButton(type: .system)
        signInLink.translatesAutoresizingMaskIntoConstraints = false
        var signInLinkConfig = UIButton.Configuration.plain()
        signInLinkConfig.baseForegroundColor = lightTeal
        signInLinkConfig.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
        var signInLinkAttrs = AttributeContainer()
        signInLinkAttrs.font = .systemFont(ofSize: 14, weight: .semibold)
        signInLinkConfig.attributedTitle = AttributedString("Sign In", attributes: signInLinkAttrs)
        signInLink.configuration = signInLinkConfig
        signInLink.addTarget(self, action: #selector(loggedOutSignInTapped), for: .touchUpInside)

        signInRow.addArrangedSubview(alreadyLabel)
        signInRow.addArrangedSubview(signInLink)

        // --- Feature pills ---
        let featurePills = buildFeaturePills()

        // Stack
        let stack = UIStackView(arrangedSubviews: [heroWrapper, titleLabel, subtitleLabel, featurePills, signUpButton, signInRow])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(24, after: subtitleLabel)
        stack.setCustomSpacing(24, after: featurePills)
        stack.setCustomSpacing(8, after: signUpButton)

        overlay.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -20),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -32),
            signUpButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
        ])

        // Insert after the greeting/header so it sits below the greeting
        if let insertIndex = contentStackView.arrangedSubviews.firstIndex(where: { $0 === locationTapped }) {
            contentStackView.insertArrangedSubview(overlay, at: insertIndex)
        } else {
            contentStackView.addArrangedSubview(overlay)
        }

        overlay.heightAnchor.constraint(greaterThanOrEqualToConstant: 420).isActive = true
        loggedOutOverlayView = overlay

        // --- Animations ---

        // Fade in overlay
        overlay.alpha = 0
        UIView.animate(withDuration: 0.4) { overlay.alpha = 1 }

        // Floating bob on hero container (gentle 6pt up-down)
        let bob = CABasicAnimation(keyPath: "transform.translation.y")
        bob.fromValue = -4
        bob.toValue = 4
        bob.duration = 2.4
        bob.autoreverses = true
        bob.repeatCount = .infinity
        bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        iconContainer.layer.add(bob, forKey: "floatingBob")

        // Subtle pulse on hero background
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.06
        pulse.duration = 3.0
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        iconContainer.layer.add(pulse, forKey: "pulse")

        // Orbit icons: staggered fade-in + individual float
        for (i, iv) in orbitViews.enumerated() {
            iv.alpha = 0
            UIView.animate(withDuration: 0.5, delay: 0.3 + Double(i) * 0.15, options: .curveEaseOut) {
                iv.alpha = 1
            }
            let orbitBob = CABasicAnimation(keyPath: "transform.translation.y")
            orbitBob.fromValue = i.isMultiple(of: 2) ? -3 : 3
            orbitBob.toValue = i.isMultiple(of: 2) ? 3 : -3
            orbitBob.duration = 2.0 + Double(i) * 0.4
            orbitBob.autoreverses = true
            orbitBob.repeatCount = .infinity
            orbitBob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            iv.layer.add(orbitBob, forKey: "orbitBob")
        }
    }

    private func hideLoggedOutOverlay() {
        guard let overlay = loggedOutOverlayView else { return }
        contentStackView.removeArrangedSubview(overlay)
        overlay.removeFromSuperview()
        loggedOutOverlayView = nil
    }

    private func buildFeaturePills() -> UIView {
        let pills = [
            ("magnifyingglass", "Browse"),
            ("shippingbox", "List & earn"),
            ("message", "Chat")
        ]
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 20
        stack.alignment = .center
        stack.distribution = .equalSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false

        let teal = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)
        for (icon, text) in pills {
            let pillStack = UIStackView()
            pillStack.axis = .horizontal
            pillStack.spacing = 5
            pillStack.alignment = .center

            let iv = UIImageView(image: UIImage(systemName: icon))
            iv.tintColor = teal
            iv.setContentHuggingPriority(.required, for: .horizontal)
            iv.setContentCompressionResistancePriority(.required, for: .horizontal)
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.widthAnchor.constraint(equalToConstant: 14).isActive = true
            iv.heightAnchor.constraint(equalToConstant: 14).isActive = true

            let lbl = UILabel()
            lbl.text = text
            lbl.font = .systemFont(ofSize: 13, weight: .medium)
            lbl.textColor = .secondaryLabel
            lbl.setContentCompressionResistancePriority(.required, for: .horizontal)

            pillStack.addArrangedSubview(iv)
            pillStack.addArrangedSubview(lbl)
            stack.addArrangedSubview(pillStack)
        }
        return stack
    }

    @objc private func loggedOutSignUpTapped() {
        let signUpVC = SignUpViewController()
        signUpVC.title = ""
        let nav = UINavigationController(rootViewController: signUpVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func loggedOutSignInTapped() {
        let signInVC = SignViewController()
        signInVC.routeContext = .default
        signInVC.title = ""
        let nav = UINavigationController(rootViewController: signInVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    // MARK: - Loading state for logged-in users

    private func showContentLoadingState() {
        guard loadingSpinner == nil else { return }
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        spinner.color = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)

        // Insert spinner into the content stack after the search bar
        if let insertIndex = contentStackView.arrangedSubviews.firstIndex(where: { $0 === collectionView }) {
            contentStackView.insertArrangedSubview(spinner, at: insertIndex + 1)
        } else {
            contentStackView.addArrangedSubview(spinner)
        }
        loadingSpinner = spinner
    }

    private func hideContentLoadingState() {
        guard let spinner = loadingSpinner else { return }
        contentStackView.removeArrangedSubview(spinner)
        spinner.removeFromSuperview()
        loadingSpinner = nil
    }
}

extension HomeViewController {
    func markFeaturedRentTap(index: Int) {
        lastFeaturedRentTap = (index: index, timestamp: Date().timeIntervalSinceReferenceDate)
    }

    func shouldSuppressFeaturedSelection(for index: Int) -> Bool {
        guard let last = lastFeaturedRentTap, last.index == index else { return false }
        return Date().timeIntervalSinceReferenceDate - last.timestamp < rentTapSuppressionWindow
    }

    func markTrendingRentTap(itemId: String) {
        lastTrendingRentTap = (itemId: itemId, timestamp: Date().timeIntervalSinceReferenceDate)
    }

    func shouldSuppressTrendingSelection(for itemId: String) -> Bool {
        guard let last = lastTrendingRentTap, last.itemId == itemId else { return false }
        return Date().timeIntervalSinceReferenceDate - last.timestamp < rentTapSuppressionWindow
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

extension HomeViewController {
    func refreshLocationButtonTitle() {
        if SavedAddressesStore.shared.getDefaultSelectedAddress() == nil {
            Task {
                do {
                    let location = try await AppLocationManager.shared.currentLocation()
                    let name = try await AppLocationManager.shared.placename(for: location)
                    SavedAddressesStore.shared.setDefaultSelectedAddress(name)
                    DistanceService.shared.setViewerCoordinate(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                    NotificationCenter.default.post(name: .locationDidChange, object: nil)
                    await MainActor.run {
                        self.updateLocationButtonDisplay(name)
                    }
                } catch {
                    await MainActor.run {
                        self.updateLocationButtonDisplay("Current Location")
                    }
                }
            }
            updateLocationButtonDisplay("Locating...")
            return
        }

        let storedAddress = SavedAddressesStore.shared.getDefaultSelectedAddress() ?? "Current Location"
        updateLocationButtonDisplay(storedAddress)
    }

    private func updateLocationButtonDisplay(_ address: String) {
        let displayText: String = {
            let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return "Current Location" }
            let components = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if let firstComponent = components.first(where: { !$0.isEmpty }) {
                return firstComponent
            }
            return trimmed
        }()

        locationTapped.setTitle(displayText, for: .normal)
        locationTapped.setTitleColor(UIColor(red: 112 / 255, green: 167 / 255, blue: 180 / 255, alpha: 1.0), for: .normal)
        locationTapped.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        configureLocationButtonAppearance()
    }

    func makeFullAddressString(from address: Address) -> String {
        let parts = [
            address.address_line1,
            address.address_line2,
            address.city,
            address.state,
            address.postal_code,
            address.country
        ]

        return parts
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    @objc func locationTappedAction(_ sender: UIButton) {
        assert(sender === locationTapped, "locationTappedAction fired from a different control than the location button.")

        let viewController = LocationSelectorViewController()
        viewController.modalPresentationStyle = .pageSheet

        viewController.onSelectedAddress = { [weak self] _ in
            CategoryItemCell.clearDistanceCache()
            self?.refreshLocationButtonTitle()
            Task { await self?.loadFeaturedItems(forceRefresh: true) }
            NotificationCenter.default.post(name: .locationDidChange, object: nil)
        }

        viewController.onEnterManualAddress = { [weak self] completion in
            guard let self else { return }
            let form = ManualAddressViewController()
            form.onSaved = { saved in
                let display = [saved.label, saved.city, saved.state].compactMap { $0 }.first ?? saved.city
                let fullString = self.makeFullAddressString(from: saved)
                SavedAddressesStore.shared.setDefaultSelectedAddress(fullString)
                if let latitude = saved.latitude, let longitude = saved.longitude, latitude != 0, longitude != 0 {
                    DistanceService.shared.setViewerCoordinate(latitude: latitude, longitude: longitude)
                } else {
                    DistanceService.shared.clearAllDistanceCaches()
                }
                CategoryItemCell.clearDistanceCache()
                self.refreshLocationButtonTitle()
                Task { await self.loadFeaturedItems(forceRefresh: true) }
                NotificationCenter.default.post(name: .locationDidChange, object: nil)
                completion(display)
            }

            if let navigationController = self.navigationController {
                navigationController.setNavigationBarHidden(false, animated: true)
                navigationController.pushViewController(form, animated: true)
            } else {
                let navigationController = UINavigationController(rootViewController: form)
                navigationController.modalPresentationStyle = .fullScreen
                self.present(navigationController, animated: true)
            }
        }

        viewController.onManageSavedAddresses = { [weak self] in
            guard let self else { return }
            let list = ManageAddressesViewController()
            list.onPicked = { [weak self] address in
                guard let self else { return }
                let fullString = self.makeFullAddressString(from: address)
                SavedAddressesStore.shared.setDefaultSelectedAddress(fullString)
                if let latitude = address.latitude, let longitude = address.longitude, latitude != 0, longitude != 0 {
                    DistanceService.shared.setViewerCoordinate(latitude: latitude, longitude: longitude)
                } else {
                    DistanceService.shared.clearAllDistanceCaches()
                }
                CategoryItemCell.clearDistanceCache()
                self.refreshLocationButtonTitle()
                Task { await self.loadFeaturedItems(forceRefresh: true) }
                NotificationCenter.default.post(name: .locationDidChange, object: nil)
            }

            if let navigationController = self.navigationController {
                navigationController.setNavigationBarHidden(false, animated: true)
                navigationController.pushViewController(list, animated: true)
            } else {
                let navigationController = UINavigationController(rootViewController: list)
                navigationController.modalPresentationStyle = .fullScreen
                self.present(navigationController, animated: true)
            }
        }

        if let sheet = viewController.presentationController as? UISheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 16
        }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        present(viewController, animated: true) {
            generator.impactOccurred()
        }
    }

    func presentSavedAddressesManager() {
        let listViewController = ManageAddressesViewController()
        if let navigationController {
            navigationController.setNavigationBarHidden(false, animated: true)
            navigationController.pushViewController(listViewController, animated: true)
        } else {
            let navigationController = UINavigationController(rootViewController: listViewController)
            navigationController.modalPresentationStyle = .fullScreen
            present(navigationController, animated: true)
        }
    }

    func presentAddAddressPrompt() {
        let form = ManualAddressViewController()
        if let navigationController {
            navigationController.setNavigationBarHidden(false, animated: true)
            navigationController.pushViewController(form, animated: true)
        } else {
            let navigationController = UINavigationController(rootViewController: form)
            navigationController.modalPresentationStyle = .fullScreen
            present(navigationController, animated: true)
        }
    }
}
