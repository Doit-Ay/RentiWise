//
//  AgreementWaitingViewController.swift
//  RentiWise
//
//  Shown after borrower signs. Pulse animation + Supabase Realtime
//  subscription. Auto-navigates to BorrowerOTPViewController when
//  lender signs.
//

import UIKit
import Supabase

final class AgreementWaitingViewController: UIViewController {

    // MARK: - Inputs
    var agreementId: String = ""
    var lenderName: String = ""
    var requestId: String = ""

    // MARK: - Colors
    private let brandTeal = UIColor(red: 0x0A/255.0, green: 0x7B/255.0, blue: 0x6C/255.0, alpha: 1.0)
    private let bgColor = UIColor(red: 0xF8/255.0, green: 0xF8/255.0, blue: 0xF6/255.0, alpha: 1.0)
    private let captionColor = UIColor(red: 0x6B/255.0, green: 0x6B/255.0, blue: 0x6B/255.0, alpha: 1.0)

    // MARK: - UI
    private let pulseView = UIView()
    private let iconLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let reminderButton = UIButton(type: .system)
    private let cooldownLabel = UILabel()

    // MARK: - State
    private var realtimeChannel: RealtimeChannelV2?
    private var lastReminderSent: Date?
    private var cooldownTimer: Timer?
    private var pollTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Waiting for Signature"
        view.backgroundColor = bgColor
        navigationController?.navigationBar.tintColor = brandTeal
        navigationItem.hidesBackButton = true
        setupUI()
        startPulseAnimation()
        startPolling()
    }

    deinit {
        cooldownTimer?.invalidate()
        pollTimer?.invalidate()
        Task { [realtimeChannel] in
            await realtimeChannel?.unsubscribe()
        }
    }

    // MARK: - UI Setup
    private func setupUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])

        titleLabel.text = "Waiting for"
        titleLabel.font = .systemFont(ofSize: 18, weight: .medium)
        titleLabel.textColor = captionColor
        titleLabel.textAlignment = .center
        stack.addArrangedSubview(titleLabel)

        let nameLabel = UILabel()
        nameLabel.text = "\(lenderName) to sign"
        nameLabel.font = .systemFont(ofSize: 22, weight: .bold)
        nameLabel.textColor = UIColor(red: 0x1A/255.0, green: 0x1A/255.0, blue: 0x1A/255.0, alpha: 1.0)
        nameLabel.textAlignment = .center
        stack.addArrangedSubview(nameLabel)

        // Pulse circle + icon
        pulseView.backgroundColor = brandTeal.withAlphaComponent(0.15)
        pulseView.layer.cornerRadius = 50
        pulseView.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(pulseView)
        NSLayoutConstraint.activate([
            pulseView.widthAnchor.constraint(equalToConstant: 100),
            pulseView.heightAnchor.constraint(equalToConstant: 100),
        ])

        iconLabel.text = "📄"
        iconLabel.font = .systemFont(ofSize: 40)
        iconLabel.textAlignment = .center
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        pulseView.addSubview(iconLabel)
        NSLayoutConstraint.activate([
            iconLabel.centerXAnchor.constraint(equalTo: pulseView.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: pulseView.centerYAnchor),
        ])

        subtitleLabel.text = "Your agreement has been sent.\nWe'll notify you as soon as\n\(lenderName) signs."
        subtitleLabel.font = .systemFont(ofSize: 15)
        subtitleLabel.textColor = captionColor
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        stack.addArrangedSubview(subtitleLabel)

        // Spacer
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stack.addArrangedSubview(spacer)

        // Reminder button
        reminderButton.setTitle("Send Reminder", for: .normal)
        reminderButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        reminderButton.setTitleColor(brandTeal, for: .normal)
        reminderButton.layer.borderWidth = 1.5
        reminderButton.layer.borderColor = brandTeal.cgColor
        reminderButton.layer.cornerRadius = 12
        reminderButton.translatesAutoresizingMaskIntoConstraints = false
        reminderButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        reminderButton.widthAnchor.constraint(equalToConstant: 200).isActive = true
        reminderButton.addTarget(self, action: #selector(sendReminder), for: .touchUpInside)
        stack.addArrangedSubview(reminderButton)

        cooldownLabel.text = ""
        cooldownLabel.font = .systemFont(ofSize: 13)
        cooldownLabel.textColor = captionColor
        cooldownLabel.textAlignment = .center
        stack.addArrangedSubview(cooldownLabel)
    }

    // MARK: - Pulse Animation
    private func startPulseAnimation() {
        UIView.animate(withDuration: 1.2, delay: 0, options: [.repeat, .autoreverse, .curveEaseInOut]) {
            self.pulseView.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
        }
    }

    // MARK: - Polling (fallback for realtime)
    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.checkLenderSigned() }
        }
    }

    private func checkLenderSigned() async {
        do {
            struct ARow: Decodable { let lender_agreed_at: String? }
            let resp = try await SupabaseManager.shared.client
                .from("rental_agreements")
                .select("lender_agreed_at")
                .eq("id", value: agreementId)
                .single()
                .execute()

            let row = try JSONDecoder().decode(ARow.self, from: resp.data)
            if row.lender_agreed_at != nil {
                await MainActor.run { navigateToOTP() }
            }
        } catch { /* retry on next poll */ }
    }

    private func navigateToOTP() {
        pollTimer?.invalidate()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let otpVC = BorrowerOTPViewController()
        otpVC.requestId = requestId
        otpVC.lenderName = lenderName
        navigationController?.pushViewController(otpVC, animated: true)
    }

    // MARK: - Reminder
    @objc private func sendReminder() {
        if let last = lastReminderSent, Date().timeIntervalSince(last) < 600 {
            return // 10 min cooldown
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        lastReminderSent = Date()
        reminderButton.isEnabled = false
        startReminderCooldown()
        // In production: trigger push notification via Edge Function
    }

    private func startReminderCooldown() {
        var remaining = 600
        cooldownLabel.text = "Available after 10 minutes"
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] timer in
            remaining -= 60
            if remaining <= 0 {
                timer.invalidate()
                self?.reminderButton.isEnabled = true
                self?.cooldownLabel.text = ""
            } else {
                self?.cooldownLabel.text = "Available in \(remaining / 60) min"
            }
        }
    }
}
