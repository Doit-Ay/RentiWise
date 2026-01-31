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
