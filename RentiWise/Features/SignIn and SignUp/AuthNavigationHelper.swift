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
            let nibName = "SignViewController"
            let signInVC: SignViewController
            if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
                Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
                signInVC = SignViewController(nibName: nibName, bundle: nil)
            } else {
                signInVC = SignViewController(service: SignInService())
            }
            signInVC.routeContext = routeContext
            signInVC.title = ""
            signInVC.hidesBottomBarWhenPushed = true
            viewController = signInVC

        case .signUp:
            let nibName = "SignUpViewController"
            let signUpVC: SignUpViewController
            if Bundle.main.path(forResource: nibName, ofType: "nib") != nil ||
                Bundle.main.path(forResource: nibName, ofType: "xib") != nil {
                signUpVC = SignUpViewController(nibName: nibName, bundle: nil)
            } else {
                signUpVC = SignUpViewController(service: SignUpService())
            }
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
