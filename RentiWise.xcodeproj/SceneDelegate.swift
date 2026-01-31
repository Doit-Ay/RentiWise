// SceneDelegate.swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }

    Task {
        do {
            // Let Supabase process the OAuth callback and persist the session
            try await SupabaseManager.shared.client.auth.session(from: url)

            // Optional sanity check
            let session = try await SupabaseManager.shared.client.auth.session
            print("[Auth Redirect] Signed in user:", session.user.id.uuidString)

            // Route to Profile tab (assumes index 1 is Profile)
            await MainActor.run {
                guard let windowScene = scene as? UIWindowScene,
                      let window = windowScene.windows.first,
                      let tab = window.rootViewController as? UITabBarController,
                      (tab.viewControllers?.count ?? 0) > 1 else { return }

                tab.selectedIndex = 1

                if let nav = tab.viewControllers?[1] as? UINavigationController {
                    let profileVC = ProfileViewController()
                    profileVC.hidesBottomBarWhenPushed = false
                    nav.setViewControllers([profileVC], animated: false)
                }

                if let presented = tab.presentedViewController {
                    presented.dismiss(animated: true)
                }
            }
        } catch {
            print("[Auth Redirect] Failed to create session from URL:", error)
        }
    }
}
