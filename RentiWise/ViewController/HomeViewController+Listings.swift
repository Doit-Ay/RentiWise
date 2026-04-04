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

    func checkAndUpdateListingSection() async {
        let isPro = await IAPManager.shared.isProUser()
        
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
            listingUIView?.isHidden = false
            additemHome?.isHidden = false
            startearninglabel?.isHidden = false
            startearningdownlabel?.isHidden = false

            adjustListingViewHeightIfFixed(target: 110)

        case .manage:
            listingUIView?.isHidden = false
            additemHome?.isHidden = true
            startearninglabel?.isHidden = true
            startearningdownlabel?.isHidden = true

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

            let targetHeight: CGFloat = isPro ? 144 : 190
            adjustListingViewHeightIfFixed(target: targetHeight)
        }
        
        // Animate section visible after data is loaded (only on first load)
        if isListingDataLoaded, listingUIView?.alpha == 0 {
            UIView.animate(withDuration: 0.3) {
                self.listingUIView?.alpha = 1
            }
        }
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

        let add = roundAction(symbol: "plus", title: "Add Item", selector: #selector(manageListItemTapped), isEnabled: isPro || itemCount < 3)
        let req = roundAction(symbol: "tray.and.arrow.down", title: "Requests", selector: #selector(manageRequestsTapped))
        let man = roundAction(symbol: "rectangle.stack", title: "Manage", selector: #selector(manageManageTapped))

        actionsRow.addArrangedSubview(UIView())
        actionsRow.addArrangedSubview(add)
        actionsRow.addArrangedSubview(req)
        actionsRow.addArrangedSubview(man)
        actionsRow.addArrangedSubview(UIView())

        let proStack = UIStackView()
        proStack.axis = .horizontal
        proStack.spacing = 8
        proStack.alignment = .center
        
        let leftListings = max(0, 3 - itemCount)
        let limitLabel = UILabel()
        limitLabel.text = "\(leftListings)/3 listings left for free plan"
        limitLabel.font = .systemFont(ofSize: 13, weight: .medium)
        limitLabel.textColor = .secondaryLabel
        limitLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        limitLabel.adjustsFontSizeToFitWidth = true
        limitLabel.minimumScaleFactor = 0.8
        
        let buyProBtn = UIButton(type: .system)
        buyProBtn.setTitle("Lender Pro", for: .normal)
        
        let crownConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        let crownImage = UIImage(systemName: "crown.fill", withConfiguration: crownConfig)?.withTintColor(.systemYellow, renderingMode: .alwaysOriginal)
        buyProBtn.setImage(crownImage, for: .normal)
        
        buyProBtn.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        buyProBtn.setTitleColor(.white, for: .normal)
        
        // Brand teal background for a button look
        let brandTeal = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)
        buyProBtn.backgroundColor = brandTeal
        buyProBtn.layer.cornerRadius = 16
        
        // Proper spacing horizontally
        buyProBtn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        buyProBtn.titleEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: -6)
        buyProBtn.imageEdgeInsets = UIEdgeInsets(top: 0, left: -2, bottom: 0, right: 2)
        
        buyProBtn.translatesAutoresizingMaskIntoConstraints = false
        // Ensure button does NOT get compressed vertically or horizontally
        buyProBtn.setContentCompressionResistancePriority(.required, for: .horizontal)
        buyProBtn.setContentHuggingPriority(.required, for: .horizontal)
        buyProBtn.heightAnchor.constraint(equalToConstant: 32).isActive = true
        
        buyProBtn.addTarget(self, action: #selector(buyLenderProTapped), for: .touchUpInside)        
        proStack.addArrangedSubview(limitLabel)
        proStack.addArrangedSubview(UIView()) // spacer
        proStack.addArrangedSubview(buyProBtn)

        let v = UIStackView(arrangedSubviews: [title, actionsRow])
        if !isPro {
            v.addArrangedSubview(proStack)
        }
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
    @objc func manageListItemTapped() { additemHomeTapped(additemHome ?? UIButton(type: .system)) }
    @objc func manageRequestsTapped() { requestsButtonTapped(additemHome ?? UIButton(type: .system)) }
    @objc func buyLenderProTapped() {
        let upgradeVC = UpgradeProViewController()
        upgradeVC.hidesBottomBarWhenPushed = true
        if let nav = navigationController {
            nav.pushViewController(upgradeVC, animated: true)
        } else {
            present(upgradeVC, animated: true)
        }
    }
    @objc func manageManageTapped() {
        let sb = UIStoryboard(name: "AppStarting", bundle: nil)
        guard let dashboard = sb.instantiateViewController(withIdentifier: "DashboardListing") as? DashboardViewController else {
            assertionFailure("Storyboard ID 'DashboardListing' is not a DashboardViewController.")
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
