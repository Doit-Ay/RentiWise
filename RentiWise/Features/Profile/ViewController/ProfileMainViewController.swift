//
//  ProfileMainViewController.swift
//  RentiWise
//
//  Created by admin99 on 13/11/25.
//

import UIKit
import Supabase

class ProfileMainViewController: UIViewController {

    @IBOutlet weak var userName: UILabel!
    @IBOutlet weak var userEmail: UILabel!
    @IBOutlet weak var userInfoEmail: UILabel!
    @IBOutlet weak var userNumber: UILabel!

    // Inject for tests if needed; default to real service
    private let profileService: ProfileServicing

    private enum Constants {
        static let appStartingStoryboard = "AppStarting"
        static let navigationBarID = "NavigationBar"
    }

    // Designated initializer for DI if you instantiate programmatically
    init(service: ProfileServicing = ProfileService()) {
        self.profileService = service
        super.init(nibName: "ProfileMainViewController", bundle: nil)
    }

    // XIB/storyboard initializer
    required init?(coder: NSCoder) {
        self.profileService = ProfileService()
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = ""

        // Replace default back button with a "Home" button that goes to the app's root (Home)
        navigationItem.hidesBackButton = true
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "house"),
            style: .plain,
            target: self,
            action: #selector(didTapHome)
        )

        loadUserInfo()
    }

    @objc private func didTapHome() {
        // Best-effort navigation back to Home if we’re within a nav stack
        if let nav = navigationController {
            nav.popToRootViewController(animated: true)
        } else if presentingViewController != nil {
            dismiss(animated: true)
        } else {
            // Fallback: reset root to Home
            resetRootToHome()
        }
    }

    private func loadUserInfo() {
        Task {
            do {
                let profile = try await profileService.fetchCurrentUserProfile()
                await MainActor.run {
                    self.userName.text = profile.fullName
                    self.userEmail.text = profile.email
                    self.userInfoEmail.text = profile.email
                    self.userNumber.text = profile.phone
                }
            } catch {
                await MainActor.run {
                    self.userName.text = ""
                    self.userEmail.text = ""
                    self.userInfoEmail.text = ""
                    self.userNumber.text = ""
                    let a = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                    a.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(a, animated: true)
                }
            }
        }
    }

    @IBAction func signOut(_ sender: UIButton) {
        Task {
            do {
                try await SupabaseManager.shared.client.auth.signOut()
                await MainActor.run {
                    // After logout, always reset root to Home
                    self.resetRootToHome()
                }
            } catch {
                await MainActor.run {
                    let a = UIAlertController(title: "Sign Out Failed", message: error.localizedDescription, preferredStyle: .alert)
                    a.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(a, animated: true)
                }
            }
        }
    }

    private func resetRootToHome() {
        let storyboard = UIStoryboard(name: Constants.appStartingStoryboard, bundle: nil)
        let rootVC = storyboard.instantiateViewController(withIdentifier: Constants.navigationBarID)

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            window.rootViewController = rootVC
            window.makeKeyAndVisible()
        } else {
            // Fallback if we can’t access window: present modally
            rootVC.modalPresentationStyle = .fullScreen
            present(rootVC, animated: true)
        }
    }
}
