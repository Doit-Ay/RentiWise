import UIKit

enum AppRootBuilder {
    private static let storyboardName = "AppStarting"

    private enum StoryboardID {
        static let categories = "Categories"
        static let dashboardListing = "DashboardListing"
        static let profile = "ProfileViewController"
    }

    static func makeRootTabBarController(selectedIndex: Int = 0) -> UITabBarController {
        let tabBarController = UITabBarController()

        let homeNavigationController = UINavigationController(rootViewController: HomeViewController())
        homeNavigationController.tabBarItem = UITabBarItem(
            title: "Explore",
            image: UIImage(systemName: "magnifyingglass"),
            selectedImage: UIImage(systemName: "magnifyingglass")
        )

        let profileNavigationController = UINavigationController(rootViewController: makeProfileViewController())
        profileNavigationController.tabBarItem = UITabBarItem(
            title: "Profile",
            image: UIImage(systemName: "person.crop.circle"),
            selectedImage: UIImage(systemName: "person.crop.circle.fill")
        )

        tabBarController.viewControllers = [homeNavigationController, profileNavigationController]
        tabBarController.selectedIndex = max(0, min(selectedIndex, (tabBarController.viewControllers?.count ?? 1) - 1))
        return tabBarController
    }

    static func makeCategoriesViewController() -> CategoriesViewController? {
        let storyboard = UIStoryboard(name: storyboardName, bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: StoryboardID.categories) as? CategoriesViewController
    }

    static func makeDashboardListingViewController() -> DashboardViewController? {
        let storyboard = UIStoryboard(name: storyboardName, bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: StoryboardID.dashboardListing) as? DashboardViewController
    }

    static func makeProfileViewController() -> ProfileViewController {
        let storyboard = UIStoryboard(name: storyboardName, bundle: nil)
        if let profileViewController = storyboard.instantiateViewController(withIdentifier: StoryboardID.profile) as? ProfileViewController {
            return profileViewController
        }
        return ProfileViewController()
    }
}
