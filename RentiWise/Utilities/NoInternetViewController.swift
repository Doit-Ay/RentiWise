// NoInternetViewController.swift
// RentiWise
//
// Full-screen overlay shown when the device has no network connectivity.
// Presented modally by SceneDelegate; auto-dismissed when connectivity resumes.

import UIKit
import Network

final class NoInternetViewController: UIViewController {

    // MARK: - Callback (set by presenter)
    /// Called when the user taps "Try Again" or network auto-recovers.
    var onConnected: (() -> Void)?

    // MARK: - Views
    private let blurView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemUltraThinMaterial)
        return UIVisualEffectView(effect: blur)
    }()

    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemBackground
        v.layer.cornerRadius = 28
        v.layer.shadowColor  = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.18
        v.layer.shadowRadius  = 24
        v.layer.shadowOffset  = CGSize(width: 0, height: 8)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let wifiIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode   = .scaleAspectFit
        iv.tintColor     = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)
        iv.image = UIImage(systemName: "wifi.slash")
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text            = "No Internet Connection"
        l.font            = .systemFont(ofSize: 22, weight: .bold)
        l.textAlignment   = .center
        l.numberOfLines   = 1
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.7
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text          = "Please check your Wi-Fi or mobile data\nand try again."
        l.font          = .systemFont(ofSize: 15, weight: .regular)
        l.textColor     = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let retryButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Try Again", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        b.backgroundColor  = UIColor(red: 0x5D/255.0, green: 0xA9/255.0, blue: 0xB6/255.0, alpha: 1.0)
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 14
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let statusDot: UIView = {
        let v = UIView()
        v.backgroundColor    = .systemRed
        v.layer.cornerRadius  = 5
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let statusLabel: UILabel = {
        let l = UILabel()
        l.text      = "Offline"
        l.font      = .systemFont(ofSize: 13, weight: .medium)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - State
    private var networkObserver: NSObjectProtocol?
    private var pulseTimer: Timer?
    private var pollTimer: Timer?   // fallback for Simulator: NWPathMonitor doesn't always fire

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startPulseAnimation()
        observeNetworkRecovery()
        startPollingFallback()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pulseTimer?.invalidate()
        pulseTimer = nil
        pollTimer?.invalidate()
        pollTimer = nil
        if let obs = networkObserver {
            NotificationCenter.default.removeObserver(obs)
            networkObserver = nil
        }
    }

    // MARK: - Polling fallback (fixes iOS Simulator NWPathMonitor misses)

    private func startPollingFallback() {
        // Poll every 2s. On a real device NWPathMonitor fires first and dismisses
        // the overlay before the timer can; on the Simulator this catches the change.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkConnectivityViaNetwork()
        }
    }

    private func checkConnectivityViaNetwork() {
        // Lightweight HEAD request to Apple's captive portal endpoint (no data transferred).
        guard let url = URL(string: "https://captive.apple.com/hotspot-detect.html") else { return }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 5)
        request.httpMethod = "HEAD"

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            guard let self else { return }
            let isReachable = error == nil && (response as? HTTPURLResponse) != nil
            if isReachable && !self.isDismissing {
                DispatchQueue.main.async {
                    // Update the shared monitor's state so the rest of the app knows
                    self.handleNetworkRestored()
                }
            }
        }.resume()
    }

    private var isDismissing = false

    // MARK: - UI

    private func setupUI() {
        view.backgroundColor = .clear

        // Blur fills entire screen
        blurView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blurView)
        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: view.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Card sits in the center
        view.addSubview(cardView)
        [wifiIconView, titleLabel, subtitleLabel, retryButton, statusDot, statusLabel].forEach {
            cardView.addSubview($0)
        }

        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            wifiIconView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 36),
            wifiIconView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            wifiIconView.widthAnchor.constraint(equalToConstant: 72),
            wifiIconView.heightAnchor.constraint(equalToConstant: 72),

            titleLabel.topAnchor.constraint(equalTo: wifiIconView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            subtitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),

            retryButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 28),
            retryButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            retryButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            retryButton.heightAnchor.constraint(equalToConstant: 50),

            statusDot.topAnchor.constraint(equalTo: retryButton.bottomAnchor, constant: 20),
            statusDot.centerXAnchor.constraint(equalTo: cardView.centerXAnchor, constant: -30),
            statusDot.widthAnchor.constraint(equalToConstant: 10),
            statusDot.heightAnchor.constraint(equalToConstant: 10),
            statusDot.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -28),

            statusLabel.centerYAnchor.constraint(equalTo: statusDot.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 6)
        ])
    }

    // MARK: - Pulse animation on wifi icon

    private func startPulseAnimation() {
        UIView.animate(withDuration: 1.0, delay: 0,
                       options: [.autoreverse, .repeat, .allowUserInteraction],
                       animations: {
            self.wifiIconView.alpha = 0.35
        })
    }

    // MARK: - Network recovery observer

    private func observeNetworkRecovery() {
        networkObserver = NotificationCenter.default.addObserver(
            forName: NetworkMonitor.connectivityChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let connected = (notification.userInfo?["isConnected"] as? Bool) ?? false
            if connected {
                self.handleNetworkRestored()
            }
        }
    }

    private func handleNetworkRestored() {
        guard !isDismissing else { return }
        isDismissing = true

        // Stop the poll timer immediately so it doesn't re-trigger
        pollTimer?.invalidate()
        pollTimer = nil

        // Animate status dot to green, then auto-dismiss
        UIView.animate(withDuration: 0.3) {
            self.statusDot.backgroundColor = .systemGreen
            self.statusLabel.text = "Back online!"
            self.statusLabel.textColor = .systemGreen
        }
        // Short delay so user sees the "Back online!" feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.dismiss(animated: true) {
                self?.onConnected?()
            }
        }
    }

    // MARK: - Retry

    @objc private func retryTapped() {
        // Animate button press
        UIView.animate(withDuration: 0.1, animations: {
            self.retryButton.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            self.retryButton.alpha = 0.8
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.retryButton.transform = .identity
                self.retryButton.alpha = 1.0
            }
        }

        if NetworkMonitor.shared.isConnected {
            handleNetworkRestored()
        } else {
            // Shake the icon to signal still offline
            shakeIcon()
        }
    }

    private func shakeIcon() {
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.duration  = 0.4
        anim.values    = [-10, 10, -8, 8, -4, 4, 0]
        wifiIconView.layer.add(anim, forKey: "shake")
    }
}
