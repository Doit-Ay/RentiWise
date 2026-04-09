//
//  HomeViewController+Appearance.swift
//  RentiWise
//
//  Extracted from HomeViewController.swift — Image rotation, glass effects, and header styling.
//

import UIKit
import Supabase

// MARK: - Home header image rotation + slide animation
extension HomeViewController {

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

    func slideInFromRight(newImage: UIImage?, in imageView: UIImageView, duration: TimeInterval) {
        imageView.layoutIfNeeded()
        let baseFrame = imageView.bounds

        let outgoing = UIImageView(image: imageView.image)
        outgoing.frame = baseFrame
        outgoing.contentMode = .scaleAspectFit
        outgoing.clipsToBounds = true

        let incoming = UIImageView(image: newImage)
        incoming.frame = baseFrame
        incoming.contentMode = .scaleAspectFit
        incoming.clipsToBounds = true
        incoming.transform = CGAffineTransform(translationX: baseFrame.width, y: 0)

        imageView.addSubview(outgoing)
        imageView.addSubview(incoming)

        let previousImage = imageView.image
        imageView.image = nil

        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseInOut], animations: {
            outgoing.transform = CGAffineTransform(translationX: -baseFrame.width, y: 0)
            incoming.transform = .identity
        }, completion: { _ in
            imageView.image = newImage
            outgoing.removeFromSuperview()
            incoming.removeFromSuperview()

            if imageView.image == nil {
                imageView.image = previousImage
            }
        })
    }

    // MARK: - Glass effects

    func applyGlassToFeaturedCardsIfNeeded() {
        let cards: [UIView?] = [item1CardView, item2CardView, item3CardView, item4CardView]
        for card in cards {
            guard let v = card else { continue }
            v.applyGlassEffect(
                cornerRadius: 16,
                style: .systemThickMaterial,
                addsVibrancy: false,
                showsShadow: true,
                borderAlpha: 0.30,
                tintColorOverride: .white,
                tintAlpha: 0.14
            )
        }

        [item1Image, item2Image, item3Image, item4Image].forEach {
            $0?.clipsToBounds = true
            $0?.layer.cornerRadius = 12
        }
    }

    func applyGlassToRentButtonsIfNeeded() {
        let buttons: [UIButton?] = [rentButton1, rentButton2, rentButton3, rentButton4]
        for b in buttons {
            guard let v = b else { continue }

            let tintColorOverride: UIColor = .white
            let titleColor: UIColor = .label

            v.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            v.setTitleColor(titleColor, for: .normal)
            var btnConfig = UIButton.Configuration.plain()
            btnConfig.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
            v.configuration = btnConfig

            v.applyGlassEffect(
                cornerRadius: 16,
                style: .systemThickMaterial,
                addsVibrancy: false,
                showsShadow: true,
                borderAlpha: 0.30,
                tintColorOverride: tintColorOverride,
                tintAlpha: 0.20
            )
        }
    }

    func applyGlassToHeaderRoundButtons() {
        let containerSide: CGFloat = 44

        let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)

        func ensureContainer(for button: UIButton, existing: inout UIView?) {
            if let container = existing {
                container.backgroundColor = brandTeal
                container.layer.cornerRadius = containerSide / 2
                container.layer.masksToBounds = false
                container.layer.shadowOpacity = 0.12
                container.layer.shadowRadius = 5
                container.layer.shadowOffset = CGSize(width: 0, height: 3)
                return
            }

            let wrapper = UIView()
            wrapper.translatesAutoresizingMaskIntoConstraints = false

            if let superview = button.superview {
                superview.addSubview(wrapper)
                NSLayoutConstraint.activate([
                    wrapper.widthAnchor.constraint(equalToConstant: containerSide),
                    wrapper.heightAnchor.constraint(equalToConstant: containerSide),
                    wrapper.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                    wrapper.centerYAnchor.constraint(equalTo: button.centerYAnchor)
                ])
            } else {
                view.addSubview(wrapper)
                NSLayoutConstraint.activate([
                    wrapper.widthAnchor.constraint(equalToConstant: containerSide),
                    wrapper.heightAnchor.constraint(equalToConstant: containerSide),
                    wrapper.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                    wrapper.centerYAnchor.constraint(equalTo: button.centerYAnchor)
                ])
            }

            wrapper.backgroundColor = brandTeal
            wrapper.layer.cornerRadius = containerSide / 2
            wrapper.layer.masksToBounds = false
            wrapper.layer.shadowOpacity = 0.12
            wrapper.layer.shadowRadius = 5
            wrapper.layer.shadowOffset = CGSize(width: 0, height: 3)

            button.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(button)
            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor)
            ])

            button.backgroundColor = .clear
            var btnConfig = UIButton.Configuration.plain()
            btnConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            button.configuration = btnConfig

            existing = wrapper
        }

        if let bell = notificationBell {
            ensureContainer(for: bell, existing: &notificationContainer)
        }
        if let add = additemHome {
            ensureContainer(for: add, existing: &addItemContainer)
        }
    }
}

// MARK: - Bottom tagline helper + Notification Badge
extension HomeViewController {
    func setBottomTagline() {
        guard let label = Homepagelastline else { return }

        let brandTeal = UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0)
        let baseColor = label.textColor ?? .label
        let baseFont = label.font ?? UIFont.systemFont(ofSize: 14)

        let text = "You  Rentiwise"
        let attr = NSMutableAttributedString(string: text, attributes: [
            .foregroundColor: baseColor,
            .font: baseFont
        ])

        let heartAttachment = NSTextAttachment()
        let pointSize = baseFont.pointSize
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        if let heartImage = UIImage(systemName: "heart.fill", withConfiguration: config)?
            .withRenderingMode(.alwaysTemplate) {

            let tinted = heartImage.withTintColor(brandTeal, renderingMode: .alwaysOriginal)
            heartAttachment.image = tinted

            let lineHeight = baseFont.lineHeight
            let imageHeight = lineHeight * 0.9
            let imageWidth = tinted.size.width * (imageHeight / tinted.size.height)

            heartAttachment.bounds = CGRect(
                x: 0,
                y: (baseFont.descender).rounded(),
                width: imageWidth,
                height: imageHeight
            )
        }

        let heartString = NSAttributedString(attachment: heartAttachment)

        if let rangeOfYou = (attr.string as NSString).range(of: "You ").toRange() {
            let insertIndex = rangeOfYou.upperBound
            attr.replaceCharacters(in: NSRange(location: insertIndex, length: 0), with: heartString)
        } else {
            attr.insert(heartString, at: 4)
        }

        label.attributedText = attr
    }
    
    // MARK: - Notification Badge
    
    func updateNotificationBadge() async {
        do {
            let session = try? await SupabaseManager.shared.client.auth.session
            guard let userId = session?.user.id.uuidString else {
                await MainActor.run {
                    self.unreadNotificationCount = 0
                    self.updateBadgeVisibility()
                }
                return
            }
            
            let extensionCount = try await fetchUnreadExtensionCount(for: userId)
            let returnCount = try await fetchUnreadReturnCount(for: userId)
            let generalCount = try await fetchUnreadGeneralNotificationCount(for: userId)
            let totalCount = extensionCount + returnCount + generalCount
            
            await MainActor.run {
                self.unreadNotificationCount = totalCount
                self.updateBadgeVisibility()
            }
        } catch {
            debugLog("[Home] Error fetching unread notification count: \(error)")
            await MainActor.run {
                self.unreadNotificationCount = 0
                self.updateBadgeVisibility()
            }
        }
    }
    
    func fetchUnreadExtensionCount(for ownerId: String) async throws -> Int {
        let response = try await SupabaseManager.shared.client
            .from("extension_requests")
            .select("id, requests!inner(id)", head: true, count: .exact)
            .eq("requests.owner_id", value: ownerId)
            .eq("status", value: "pending")
            .or("is_read.is.null,is_read.eq.false")
            .execute()

        return response.count ?? 0
    }
    
    func fetchUnreadReturnCount(for ownerId: String) async throws -> Int {
        let response = try await SupabaseManager.shared.client
            .from("return_requests")
            .select("id, requests!inner(id)", head: true, count: .exact)
            .eq("requests.owner_id", value: ownerId)
            .eq("status", value: "pending")
            .or("is_read.is.null,is_read.eq.false")
            .execute()

        return response.count ?? 0
    }

    func fetchUnreadGeneralNotificationCount(for userId: String) async throws -> Int {
        let response = try await SupabaseManager.shared.client
            .from("notifications")
            .select("id", head: true, count: .exact)
            .eq("user_id", value: userId)
            .or("is_read.is.null,is_read.eq.false")
            .execute()

        return response.count ?? 0
    }
    
    func updateBadgeVisibility() {
        guard let bell = notificationBell else { return }
        
        if unreadNotificationCount > 0 {
            if notificationBadge == nil {
                createNotificationBadge(on: bell)
            }
            notificationBadge?.isHidden = false
            
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut], animations: {
                self.notificationBadge?.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }) { _ in
                UIView.animate(withDuration: 0.1) {
                    self.notificationBadge?.transform = .identity
                }
            }
        } else {
            UIView.animate(withDuration: 0.2) {
                self.notificationBadge?.alpha = 0
            } completion: { _ in
                self.notificationBadge?.isHidden = true
                self.notificationBadge?.alpha = 1
            }
        }
    }
    
    func createNotificationBadge(on button: UIButton) {
        notificationBadge?.removeFromSuperview()
        
        let badge = UIView()
        badge.backgroundColor = UIColor(red: 0.36, green: 0.66, blue: 0.71, alpha: 1.0)
        badge.layer.cornerRadius = 6
        badge.clipsToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        
        badge.layer.shadowColor = UIColor.black.cgColor
        badge.layer.shadowOpacity = 0.3
        badge.layer.shadowRadius = 2
        badge.layer.shadowOffset = CGSize(width: 0, height: 1)
        badge.layer.masksToBounds = false
        
        if let superview = button.superview {
            superview.addSubview(badge)
            
            NSLayoutConstraint.activate([
                badge.topAnchor.constraint(equalTo: button.topAnchor, constant: 0),
                badge.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: 0),
                badge.widthAnchor.constraint(equalToConstant: 12),
                badge.heightAnchor.constraint(equalToConstant: 12)
            ])
        }
        
        notificationBadge = badge
    }
}

// MARK: - Featured Rent button actions
extension HomeViewController {

    @IBAction func rentButton1Tapped(_ sender: UIButton) {
        guard featuredItems.indices.contains(0) else { return }
        markFeaturedRentTap(index: 0)
        openRequestView(for: featuredItems[0])
    }

    @IBAction func rentButton2Tapped(_ sender: UIButton) {
        guard featuredItems.indices.contains(1) else { return }
        markFeaturedRentTap(index: 1)
        openRequestView(for: featuredItems[1])
    }

    @IBAction func rentButton3Tapped(_ sender: UIButton) {
        guard featuredItems.indices.contains(2) else { return }
        markFeaturedRentTap(index: 2)
        openRequestView(for: featuredItems[2])
    }

    @IBAction func rentButton4Tapped(_ sender: UIButton) {
        guard featuredItems.indices.contains(3) else { return }
        markFeaturedRentTap(index: 3)
        openRequestView(for: featuredItems[3])
    }
}
