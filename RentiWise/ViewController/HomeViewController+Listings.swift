//
//  HomeViewController+Listings.swift
//  RentiWise
//
//  Extracted from HomeViewController.swift — Listing section management (empty vs manage card).
//

import UIKit
import Supabase

// MARK: - Listing section (empty vs manage)
extension HomeViewController {

    enum ListingSectionState {
        case empty
        case manage
    }

    func checkAndUpdateListingSection(forceRefresh: Bool = false) async {
        let isPro = await IAPManager.shared.isProUser()

        // On cold start, use PreloadManager's cached result
        if !forceRefresh, let hasListings = PreloadManager.shared.userHasListings {
            await MainActor.run {
                self.isListingDataLoaded = true
                self.showListingSection(hasListings ? .manage : .empty, itemCount: 0, isPro: isPro)
            }
            return
        }

        // Network check (subsequent refreshes or cache miss)
        guard let userId = await SupabaseManager.shared.currentUserId() else {
            await MainActor.run {
                self.isListingDataLoaded = true
                self.showListingSection(.empty, itemCount: 0, isPro: isPro)
            }
            return
        }

        do {
            let response = try await SupabaseManager.shared.client
                .from("items")
                .select("id", head: true, count: .exact)
                .eq("owner_id", value: userId)
                .execute()

            let count = response.count ?? 0
            let hasAny = count > 0
            await MainActor.run {
                self.isListingDataLoaded = true
                self.showListingSection(hasAny ? .manage : .empty, itemCount: count, isPro: isPro)
            }
        } catch {
            await MainActor.run {
                self.isListingDataLoaded = true
                self.showListingSection(.empty, itemCount: 0, isPro: isPro)
            }
        }
    }

    func showListingSection(_ state: ListingSectionState, itemCount: Int = 0, isPro: Bool = false) {
        switch state {
        case .empty:
            manageContainerView?.removeFromSuperview()
            manageContainerView = nil
            emptyListingBannerView?.removeFromSuperview()
            emptyListingBannerView = nil
            listingUIView?.isHidden = false

            emptyListingBannerView = buildEmptyListingBannerUI()
            if let banner = emptyListingBannerView, let host = listingUIView {
                host.addSubview(banner)
                banner.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    banner.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                    banner.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                    banner.topAnchor.constraint(equalTo: host.topAnchor),
                    banner.bottomAnchor.constraint(equalTo: host.bottomAnchor)
                ])
            }

            adjustListingViewHeightIfFixed(target: 182)
            refreshEmptyListingBannerLayoutIfNeeded()
            applyListingEmptyStateVisibility()

        case .manage:
            emptyListingBannerView?.removeFromSuperview()
            emptyListingBannerView = nil
            listingUIView?.isHidden = false

            if manageContainerView != nil {
                manageContainerView?.removeFromSuperview()
            }
            manageContainerView = buildManageCardUI(itemCount: itemCount, isPro: isPro)
            if let container = manageContainerView, let host = listingUIView {
                host.addSubview(container)
                container.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    container.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                    container.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                    container.topAnchor.constraint(equalTo: host.topAnchor),
                    container.bottomAnchor.constraint(equalTo: host.bottomAnchor)
                ])
            }

            let targetHeight: CGFloat = 144
            adjustListingViewHeightIfFixed(target: targetHeight)
            applyListingEmptyStateVisibility()
        }
    }

    func applyListingEmptyStateVisibility() {
        let hasManageCard = (manageContainerView != nil)
        let hasEmptyBanner = (emptyListingBannerView != nil)

        if shouldPreferHomeFeedEmptyBanner {
            listingUIView?.isHidden = !hasManageCard
            return
        }

        if hasManageCard || hasEmptyBanner {
            listingUIView?.isHidden = false
        }
    }

    func buildEmptyListingBannerUI() -> UIView {
        let accentColor = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)

        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .clear
        card.layer.cornerRadius = 16

        card.applyGlassEffect(
            cornerRadius: 16,
            style: .systemThickMaterial,
            addsVibrancy: false,
            showsShadow: true,
            borderAlpha: 0.0,
            tintColorOverride: .white,
            tintAlpha: 0.14
        )

        let badge = UILabel()
        badge.text = "  No listings yet  "
        badge.font = .systemFont(ofSize: 11, weight: .semibold)
        badge.textColor = accentColor
        badge.backgroundColor = accentColor.withAlphaComponent(0.12)
        badge.layer.cornerRadius = 9
        badge.layer.masksToBounds = true
        badge.textAlignment = .center
        badge.translatesAutoresizingMaskIntoConstraints = false

        let iconContainer = UIView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.backgroundColor = accentColor.withAlphaComponent(0.12)
        iconContainer.layer.cornerRadius = 20

        let icon = UIImageView(image: UIImage(systemName: "shippingbox"))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.contentMode = .scaleAspectFit
        icon.tintColor = accentColor
        iconContainer.addSubview(icon)

        let title = UILabel()
        title.text = "List your first item"
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .label
        title.numberOfLines = 0

        let subtitle = UILabel()
        subtitle.text = "Create a complete listing with photos, pricing, and pickup details to start receiving rental requests."
        subtitle.font = .systemFont(ofSize: 13, weight: .regular)
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 0

        let ctaButton = UIButton(type: .system)
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        var config = UIButton.Configuration.filled()
        config.title = "Add Item"
        config.baseBackgroundColor = accentColor
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16)
        var titleAttributes = AttributeContainer()
        titleAttributes.font = .systemFont(ofSize: 14, weight: .semibold)
        config.attributedTitle = AttributedString("Add Item", attributes: titleAttributes)
        ctaButton.configuration = config
        ctaButton.setContentHuggingPriority(.required, for: .vertical)
        ctaButton.setContentCompressionResistancePriority(.required, for: .vertical)
        ctaButton.addTarget(self, action: #selector(additemHomeTapped(_:)), for: .touchUpInside)

        let textStack = UIStackView(arrangedSubviews: [badge, title, subtitle, ctaButton])
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 6
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.setCustomSpacing(12, after: subtitle)

        card.addSubview(iconContainer)
        card.addSubview(textStack)

        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconContainer.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),

            icon.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),

            textStack.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            textStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            textStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

            badge.heightAnchor.constraint(equalToConstant: 18),
            ctaButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])

        return card
    }

    func buildHomeFeedEmptyBannerUI(isLoggedOut: Bool) -> UIView {
        let accentColor = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)

        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .clear
        card.layer.cornerRadius = 16

        card.applyGlassEffect(
            cornerRadius: 16,
            style: .systemThickMaterial,
            addsVibrancy: false,
            showsShadow: true,
            borderAlpha: 0.0,
            tintColorOverride: .white,
            tintAlpha: 0.14
        )

        let badge = UILabel()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.text = isLoggedOut ? "  Explore nearby  " : "  Local feed  "
        badge.font = .systemFont(ofSize: 11, weight: .semibold)
        badge.textColor = accentColor
        badge.backgroundColor = accentColor.withAlphaComponent(0.12)
        badge.layer.cornerRadius = 9
        badge.layer.masksToBounds = true
        badge.textAlignment = .center

        let iconContainer = UIView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.backgroundColor = accentColor.withAlphaComponent(0.12)
        iconContainer.layer.cornerRadius = 20

        let icon = UIImageView(image: UIImage(systemName: "mappin.circle.fill"))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.contentMode = .scaleAspectFit
        icon.tintColor = accentColor
        iconContainer.addSubview(icon)

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = isLoggedOut ? "Unlock rentals around you" : "Nothing is live around you yet"
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .label
        title.numberOfLines = 0

        let subtitle = UILabel()
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.text = isLoggedOut
            ? "Create an account to explore local rentals and be first to list in your area."
            : "When listings go live near your saved location, they will appear here. You can also add the first item in your area."
        subtitle.font = .systemFont(ofSize: 13, weight: .regular)
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 0

        let ctaButton = UIButton(type: .system)
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        var config = UIButton.Configuration.filled()
        let buttonTitle = isLoggedOut ? "Get Started" : "Add Item"
        config.title = buttonTitle
        config.baseBackgroundColor = accentColor
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16)
        var titleAttributes = AttributeContainer()
        titleAttributes.font = .systemFont(ofSize: 14, weight: .semibold)
        config.attributedTitle = AttributedString(buttonTitle, attributes: titleAttributes)
        ctaButton.configuration = config
        ctaButton.setContentHuggingPriority(.required, for: .vertical)
        ctaButton.setContentCompressionResistancePriority(.required, for: .vertical)
        ctaButton.addTarget(self, action: #selector(additemHomeTapped(_:)), for: .touchUpInside)

        let textStack = UIStackView(arrangedSubviews: [badge, title, subtitle])
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 6
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let headerStack = UIStackView(arrangedSubviews: [iconContainer, textStack])
        headerStack.axis = .horizontal
        headerStack.alignment = .top
        headerStack.spacing = 12
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = UIStackView(arrangedSubviews: [headerStack, ctaButton])
        contentStack.axis = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(contentStack)

        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),

            icon.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),

            contentStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            contentStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

            badge.heightAnchor.constraint(equalToConstant: 18),
            ctaButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])

        return card
    }

    func refreshEmptyListingBannerLayoutIfNeeded() {
        guard let banner = emptyListingBannerView, let host = listingUIView else { return }

        host.layoutIfNeeded()
        banner.layoutIfNeeded()

        let fallbackWidth = max(view.bounds.width - 32, 0)
        let availableWidth = host.bounds.width > 0 ? host.bounds.width : fallbackWidth
        guard availableWidth > 0 else { return }

        let measuredHeight = banner.systemLayoutSizeFitting(
            CGSize(width: availableWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        adjustListingViewHeightIfFixed(target: max(182, ceil(measuredHeight)))
    }

    func adjustListingViewHeightIfFixed(target: CGFloat) {
        guard let host = listingUIView else { return }

        if let heightConstraint = host.constraints.first(where: { $0.firstAttribute == .height && $0.relation == .equal }) {
            if abs(heightConstraint.constant - target) > 0.5 {
                heightConstraint.constant = target
                host.setNeedsLayout()
                host.layoutIfNeeded()
            }
            return
        }

        if let superview = host.superview {
            if let heightConstraint = superview.constraints.first(where: {
                ($0.firstItem as? UIView) === host && $0.firstAttribute == .height && $0.relation == .equal
            }) {
                if abs(heightConstraint.constant - target) > 0.5 {
                    heightConstraint.constant = target
                    superview.setNeedsLayout()
                    superview.layoutIfNeeded()
                }
            }
        }
    }

    func buildManageCardUI(itemCount: Int, isPro: Bool = false) -> UIView {
        let card = UIView()
        card.backgroundColor = .clear
        card.layer.cornerRadius = 16

        card.applyGlassEffect(
            cornerRadius: 16,
            style: .systemThickMaterial,
            addsVibrancy: false,
            showsShadow: true,
            borderAlpha: 0.0,
            tintColorOverride: .white,
            tintAlpha: 0.14
        )
        card.layer.borderWidth = 0
        card.layer.borderColor = nil

        let title = UILabel()
        title.text = "Manage Listings"
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .label

        let actionsRow = UIStackView()
        actionsRow.axis = .horizontal
        actionsRow.alignment = .center
        actionsRow.distribution = .equalSpacing
        actionsRow.spacing = 28

        func roundAction(symbol: String, title: String, selector: Selector, isEnabled: Bool = true) -> UIView {
            let wrapper = UIStackView()
            wrapper.axis = .vertical
            wrapper.alignment = .center
            wrapper.spacing = 8

            let circleSide: CGFloat = 56
            let circle = UIView()
            circle.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                circle.widthAnchor.constraint(equalToConstant: circleSide),
                circle.heightAnchor.constraint(equalToConstant: circleSide)
            ])
            circle.layer.cornerRadius = circleSide / 2
            circle.applyGlassEffect(
                cornerRadius: circleSide / 2,
                style: .systemUltraThinMaterial,
                addsVibrancy: false,
                showsShadow: true,
                borderAlpha: 0.0,
                tintColorOverride: .white,
                tintAlpha: 0.20
            )
            circle.layer.borderWidth = 0
            circle.layer.borderColor = nil

            let icon = UIImageView(image: UIImage(systemName: symbol))
            icon.tintColor = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)
            icon.contentMode = .scaleAspectFit
            icon.translatesAutoresizingMaskIntoConstraints = false
            circle.addSubview(icon)
            NSLayoutConstraint.activate([
                icon.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 24),
                icon.heightAnchor.constraint(equalToConstant: 24)
            ])

            let caption = UILabel()
            caption.text = title
            caption.font = .systemFont(ofSize: 13, weight: .semibold)
            caption.textColor = .label

            if isEnabled {
                let tap = UITapGestureRecognizer(target: self, action: selector)
                circle.isUserInteractionEnabled = true
                circle.addGestureRecognizer(tap)
                circle.accessibilityTraits = .button
            } else {
                circle.isUserInteractionEnabled = false
                wrapper.alpha = 0.4
                caption.textColor = .secondaryLabel
                icon.tintColor = .secondaryLabel
            }
            circle.accessibilityLabel = title

            wrapper.addArrangedSubview(circle)
            wrapper.addArrangedSubview(caption)
            return wrapper
        }

        let add = roundAction(symbol: "plus", title: "Add Item", selector: #selector(manageListItemTapped))
        let req = roundAction(symbol: "tray.and.arrow.down", title: "Requests", selector: #selector(manageRequestsTapped))
        let man = roundAction(symbol: "rectangle.stack", title: "Manage", selector: #selector(manageManageTapped))

        actionsRow.addArrangedSubview(UIView())
        actionsRow.addArrangedSubview(add)
        actionsRow.addArrangedSubview(req)
        actionsRow.addArrangedSubview(man)
        actionsRow.addArrangedSubview(UIView())

        let v = UIStackView(arrangedSubviews: [title, actionsRow])
        v.axis = .vertical
        v.alignment = .fill
        v.spacing = 16
        v.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(v)
        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            v.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            v.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            v.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        return card
    }

    // MARK: - Manage actions
    @objc func manageListItemTapped() { additemHomeTapped(UIButton(type: .system)) }
    @objc func manageRequestsTapped() { requestsButtonTapped(UIButton(type: .system)) }
    @objc func manageManageTapped() {
        guard let dashboard = AppRootBuilder.makeDashboardListingViewController() else {
            assertionFailure("Could not instantiate DashboardViewController from AppStarting storyboard.")
            return
        }
        dashboard.title = "My Listings"
        dashboard.initialSegment = 0
        dashboard.hidesBottomBarWhenPushed = true

        if let nav = self.navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(dashboard, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: dashboard)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }

    // MARK: - Thin teal rim helper
    func addTealRim(to view: UIView, color: UIColor, cornerRadius: CGFloat, thickness: CGFloat, opacity: Float) {
        view.layer.sublayers?
            .filter { $0.name?.hasPrefix("rimLayer_") == true || $0.name == "rimLayer_container" }
            .forEach { $0.removeFromSuperlayer() }

        let bounds = view.bounds.integral
        guard bounds.width > 0, bounds.height > 0 else { return }

        func makeGradientLayer(name: String, frame: CGRect, start: CGPoint, end: CGPoint) -> CAGradientLayer {
            let g = CAGradientLayer()
            g.name = name
            g.frame = frame
            g.colors = [
                color.withAlphaComponent(CGFloat(opacity)).cgColor,
                color.withAlphaComponent(0).cgColor
            ]
            g.startPoint = start
            g.endPoint = end
            return g
        }

        let top = makeGradientLayer(name: "rimLayer_top",
                                    frame: CGRect(x: 0, y: 0, width: bounds.width, height: thickness),
                                    start: CGPoint(x: 0.5, y: 0.0),
                                    end: CGPoint(x: 0.5, y: 1.0))
        let bottom = makeGradientLayer(name: "rimLayer_bottom",
                                       frame: CGRect(x: 0, y: bounds.height - thickness, width: bounds.width, height: thickness),
                                       start: CGPoint(x: 0.5, y: 1.0),
                                       end: CGPoint(x: 0.5, y: 0.0))
        let left = makeGradientLayer(name: "rimLayer_left",
                                     frame: CGRect(x: 0, y: 0, width: thickness, height: bounds.height),
                                     start: CGPoint(x: 0.0, y: 0.5),
                                     end: CGPoint(x: 1.0, y: 0.5))
        let right = makeGradientLayer(name: "rimLayer_right",
                                      frame: CGRect(x: bounds.width - thickness, y: 0, width: thickness, height: bounds.height),
                                      start: CGPoint(x: 1.0, y: 0.5),
                                      end: CGPoint(x: 0.0, y: 0.5))

        let mask = CAShapeLayer()
        mask.path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
        mask.fillColor = UIColor.white.cgColor

        let container = CALayer()
        container.name = "rimLayer_container"
        container.frame = bounds
        container.masksToBounds = true
        container.cornerRadius = cornerRadius
        container.addSublayer(top)
        container.addSublayer(bottom)
        container.addSublayer(left)
        container.addSublayer(right)
        container.mask = mask

        view.layer.addSublayer(container)
    }
}
