import UIKit
import Supabase

enum AuthDestination {
    case signIn(routeContext: SignViewController.RoutingContext)
    case signUp
}

@MainActor
extension UIViewController {
    func openAuthScreen(_ destination: AuthDestination, animated: Bool = true) {
        let viewController: UIViewController

        switch destination {
        case let .signIn(routeContext):
            let signInVC = SignViewController()
            signInVC.routeContext = routeContext
            signInVC.title = ""
            signInVC.hidesBottomBarWhenPushed = true
            viewController = signInVC

        case .signUp:
            let signUpVC = SignUpViewController()
            signUpVC.title = ""
            signUpVC.hidesBottomBarWhenPushed = true
            viewController = signUpVC
        }

        if let nav = navigationController {
            nav.setNavigationBarHidden(false, animated: animated)
            nav.pushViewController(viewController, animated: animated)
        } else {
            let nav = UINavigationController(rootViewController: viewController)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: animated)
        }
    }

    func ensureAuthenticated(orOpen destination: AuthDestination = .signUp) async -> Bool {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            _ = session.user
            return true
        } catch {
            openAuthScreen(destination)
            return false
        }
    }
}
