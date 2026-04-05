import UIKit
import Supabase
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    // Reference so we never double-present the overlay
    private weak var noInternetVC: NoInternetViewController?
    private var networkObserver: NSObjectProtocol?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        configureTabBarAppearance()
        startNetworkMonitoring()

        // Show animated splash overlay after a brief delay so the root VC is loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.showAnimatedSplash()
        }
    }

    // MARK: - Animated Splash

    private func showAnimatedSplash() {
        guard let window = self.window ?? {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                return scene.windows.first
            }
            return nil
        }() else { return }

        let splash = AnimatedSplashViewController()
        splash.view.frame = window.bounds
        splash.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        splash.onComplete = { [weak splash] in
            splash?.view.removeFromSuperview()
            splash?.removeFromParent()
        }

        // Add as child of root VC so it sits on top of everything
        if let root = window.rootViewController {
            root.addChild(splash)
            root.view.addSubview(splash.view)
            splash.didMove(toParent: root)
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        Task {
            await PendingItemRemovalSync.shared.syncIfNeeded()
        }
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        NetworkMonitor.shared.startMonitoring()

        // If we're already offline when the app launches, show immediately after
        // a short delay (so the root VC has time to load).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if !NetworkMonitor.shared.isConnected {
                self?.showNoInternetOverlay()
            }
        }

        networkObserver = NotificationCenter.default.addObserver(
            forName: NetworkMonitor.connectivityChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let connected = (notification.userInfo?["isConnected"] as? Bool) ?? true
            if !connected {
                self.showNoInternetOverlay()
            }
            // Dismissal is handled inside NoInternetViewController itself when it
            // receives the "back online" notification — no action needed here.
        }
    }

    private func showNoInternetOverlay() {
        // Prevent duplicate overlays
        guard noInternetVC == nil else { return }

        let overlay = NoInternetViewController()
        overlay.modalPresentationStyle = .overFullScreen
        overlay.modalTransitionStyle   = .crossDissolve

        // Find the topmost presented view controller to present over
        guard let root = window?.rootViewController else { return }
        var presenter: UIViewController = root
        while let next = presenter.presentedViewController,
              !(next is NoInternetViewController) {
            presenter = next
        }

        // If presenter is already showing NoInternetVC, skip
        guard !(presenter is NoInternetViewController) else { return }

        presenter.present(overlay, animated: true)
        noInternetVC = overlay
    }

    
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        
        // Configure normal state (unselected)
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
        
        // Configure selected state
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor(red: 0x70/255.0, green: 0xA7/255.0, blue: 0xB4/255.0, alpha: 1.0) // Brand teal
        ]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes

        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray
        
        // Ensure title is positioned below icon
        appearance.stackedLayoutAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 0)
        appearance.stackedLayoutAppearance.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 0)
        
        // Apply appearance
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // Handle exactly one URL, once.
        guard let url = URLContexts.first?.url else { return }

#if canImport(GoogleSignIn)
        if GIDSignIn.sharedInstance.handle(url) {
            return
        }
#endif

        // Handle deep links for item sharing (rentiwise://item/{id})
        handleDeepLink(url)
    }
    
    // MARK: - Deep Link Handling

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "rentiwise" else { return }

        // Parse: rentiwise://item/{id}
        if url.host == "item",
           let itemId = url.pathComponents.dropFirst().first {
            openItem(itemId: itemId)
        }
    }

    private func openItem(itemId: String) {
        // Use self.window — it is bound to THIS scene by UIKit, not connectedScenes.first
        // which could return a background scene on multi-scene iPads.
        guard let window = self.window,
              let tabBar = window.rootViewController as? UITabBarController else {
            return
        }
        
        // Switch to Explore tab (index 0)
        tabBar.selectedIndex = 0
        
        // Get navigation controller
        guard let nav = tabBar.selectedViewController as? UINavigationController else {
            return
        }
        
        // Fetch item and push ProductViewController
        Task {
            if let item = await fetchItem(id: itemId) {
                if CommunitySafetyService.shared.isBlocked(item.owner_id) {
                    await MainActor.run {
                        let alert = UIAlertController(
                            title: "User Blocked",
                            message: "You blocked the owner of this item. Unblock them in Privacy & Security to view this listing again.",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        nav.topViewController?.present(alert, animated: true)
                    }
                    return
                }

                await MainActor.run {
                    let vc = ProductViewController(nibName: "ProductViewController", bundle: nil)
                    vc.configure(with: item)
                    vc.hidesBottomBarWhenPushed = true
                    nav.pushViewController(vc, animated: true)
                }
            } else {
                // Item not found — show a user-visible alert
                await MainActor.run {
                    let alert = UIAlertController(
                        title: "Item Not Found",
                        message: "The item you're looking for is no longer available.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    nav.topViewController?.present(alert, animated: true)
                }
            }
        }
    }
    
    private func fetchItem(id: String) async -> Item? {
        do {
            let response = try await SupabaseManager.shared.client
                .from("items")
                .select()
                .eq("id", value: id)
                .limit(1)
                .execute()

            let rows = try JSONDecoder().decode([Item].self, from: response.data)
            return rows.first
        } catch {
            debugLog("❌ Deep link: Failed to fetch item: \(error)")
        }
        return nil
    }
}
