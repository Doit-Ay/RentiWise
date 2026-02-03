import UIKit
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        // If you use a storyboard as Main Interface, you can leave this empty.
        // If you build UI in code, set up window here.
        
        // Configure tab bar appearance to show titles
        configureTabBarAppearance()
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
            .foregroundColor: UIColor(red: 0x70/255, green: 0xA7/255, blue: 0xB4/255, alpha: 1.0) // Brand teal color
        ]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
        
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
        // If this URL belongs to GoogleSignIn, consume it and return immediately.
        if GIDSignIn.sharedInstance.handle(url) {
            return
        }
        #endif

        // If you later add other URL-based flows, handle them here,
        // but do not call GIDSignIn again for the same URL.
    }
}
