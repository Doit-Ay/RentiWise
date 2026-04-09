//
//  RequestApprovalViewController.swift
//  RentiWise
//
//  Created by admin67 on 2026-02-05.
//

import UIKit
import Supabase

enum RequestType {
    case returnRequest
    case extensionRequest
}

class RequestApprovalViewController: UIViewController {
    
    // MARK: - Properties
    
    private var requestType: RequestType = .returnRequest
    private var requestId: String = ""
    private var bookingId: String = ""
    private var requestData: [String: Any] = [:]
    private var currentSubRequestStatus: String = "pending"
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var typeLabel: UILabel!
    
    // Booking info outlets
    @IBOutlet weak var itemNameLabel: UILabel!
    @IBOutlet weak var borrowerNameLabel: UILabel!
    @IBOutlet weak var rentalPeriodLabel: UILabel!
    
    // Request details outlets
    @IBOutlet weak var requestDetailsStack: UIStackView!
    
    // Return-specific
    @IBOutlet weak var returnDetailsView: UIView!
    @IBOutlet weak var returnMediaCollection: UICollectionView!
    @IBOutlet weak var returnNotesLabel: UILabel!
    
    // Extension-specific
    @IBOutlet weak var extensionDetailsView: UIView!
    @IBOutlet weak var originalEndDateLabel: UILabel!
    @IBOutlet weak var newEndDateLabel: UILabel!
    @IBOutlet weak var additionalDaysLabel: UILabel!
    @IBOutlet weak var additionalCostLabel: UILabel!
    
    // Action buttons
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var rejectButton: UIButton!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        loadRequestData()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "Review Request"
        
        let tealColor = UIColor(red: 93/255.0, green: 169/255.0, blue: 182/255.0, alpha: 1.0)
        
        // Style buttons
        acceptButton.layer.cornerRadius = 24
        acceptButton.layer.masksToBounds = true
        acceptButton.backgroundColor = tealColor
        acceptButton.setTitleColor(.white, for: .normal)
        acceptButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        
        rejectButton.layer.cornerRadius = 24
        rejectButton.layer.masksToBounds = true
        rejectButton.backgroundColor = tealColor
        rejectButton.setTitleColor(.white, for: .normal)
        rejectButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        
        acceptButton.translatesAutoresizingMaskIntoConstraints = false
        rejectButton.translatesAutoresizingMaskIntoConstraints = false
        
        acceptButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        acceptButton.widthAnchor.constraint(equalToConstant: 361).isActive = true
        
        rejectButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        rejectButton.widthAnchor.constraint(equalToConstant: 361).isActive = true
    }
    
    // MARK: - Configuration
    
    func configure(requestType: RequestType, requestId: String, bookingId: String) {
        self.requestType = requestType
        self.requestId = requestId
        self.bookingId = bookingId
    }
    
    // MARK: - Data Loading
    
    private func loadRequestData() {
        Task {
            await fetchRequestDetails()
        }
    }
    
    private func fetchRequestDetails() async {
        do {
            let tableName = requestType == .returnRequest ? "return_requests" : "extension_requests"
            
            debugLog("[RequestApproval] Fetching from \(tableName) with ID: \(requestId)")
            
            // Fetch just the request data
            let response = try await SupabaseManager.shared.client
                .from(tableName)
                .select("*")
                .eq("id", value: requestId)
                .single()
                .execute()
            
            let data = response.data
            
            if requestType == .returnRequest {
                struct ReturnRequestData: Decodable {
                    let id: String
                    let request_id: String
                    let notes: String?
                    let proof_media: [String]?
                    let status: String
                    let created_at: String
                }
                
                let request = try JSONDecoder().decode(ReturnRequestData.self, from: data)
                debugLog("[RequestApproval] Return request loaded: \(request.id)")
                
                await MainActor.run {
                    self.currentSubRequestStatus = request.status.lowercased()
                    self.returnNotesLabel?.text = request.notes?.isEmpty == false ? request.notes : "No notes provided"
                    
                    if let proofMedia = request.proof_media, let firstImage = proofMedia.first {
                        self.setupProofImageView(with: firstImage)
                    }
                    
                    self.updateUI()
                }
            } else {
                struct ExtensionRequestData: Decodable {
                    let id: String
                    let request_id: String
                    let original_end_date: String
                    let new_end_date: String
                    let additional_days: Int
                    let additional_cost: Double
                    let status: String
                    let created_at: String
                }
                
                let request = try JSONDecoder().decode(ExtensionRequestData.self, from: data)
                debugLog("[RequestApproval] Extension request loaded: \(request.id)")
                
                await MainActor.run {
                    self.currentSubRequestStatus = request.status.lowercased()
                    self.originalEndDateLabel?.text = "Original End: \(request.original_end_date)"
                    self.newEndDateLabel?.text = "New End: \(request.new_end_date)"
                    // The unit label will be corrected in fetchBookingDetails once rental_unit is loaded
                    self.additionalDaysLabel?.text = "\(request.additional_days) additional day\(request.additional_days == 1 ? "" : "s") - ₹\(String(format: "%.0f", request.additional_cost))"
                    self.updateUI()
                }
            }
            
            // Now fetch booking details
            await fetchBookingDetails()
            
        } catch {
            debugLog("[RequestApproval] Error fetching request: \(error)")
            if let decodingError = error as? DecodingError {
                debugLog("[RequestApproval] Decoding error: \(decodingError)")
            }
            await MainActor.run {
                showAlert(title: "Error", message: "Failed to load request details: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchBookingDetails() async {
        do {
            struct BookingData: Decodable {
                let id: String
                let borrower_id: String
                let item_id: String
                let start_date: String
                let end_date: String
                let rental_unit: String?
            }
            
            debugLog("[RequestApproval] Fetching booking with ID: \(bookingId)")
            
            let response = try await SupabaseManager.shared.client
                .from("requests")
                .select("*")
                .eq("id", value: bookingId)
                .single()
                .execute()
            
            let booking = try JSONDecoder().decode(BookingData.self, from: response.data)
            
            // Fetch item name
            await fetchItemName(itemId: booking.item_id)
            
            // Fetch borrower name
            await fetchBorrowerName(borrowerId: booking.borrower_id)
            
            await MainActor.run {
                self.rentalPeriodLabel?.text = "\(booking.start_date) to \(booking.end_date)"
                if booking.rental_unit == "hour" {
                    if let text = self.additionalDaysLabel?.text {
                        self.additionalDaysLabel?.text = text.replacingOccurrences(of: "days", with: "hours")
                    }
                }
            }
        } catch {
            debugLog("[RequestApproval] Error fetching booking: \(error)")
            await MainActor.run {
                self.itemNameLabel?.text = "Booking ID: \(self.bookingId)"
                self.borrowerNameLabel?.text = "Loading..."
                self.rentalPeriodLabel?.text = "..."
            }
        }
    }
    
    private func fetchItemName(itemId: String) async {
        do {
            struct ItemData: Decodable {
                let id: String
                let title: String
            }
            
            let response = try await SupabaseManager.shared.client
                .from("items")
                .select("id, title")
                .eq("id", value: itemId)
                .single()
                .execute()
            
            let item = try JSONDecoder().decode(ItemData.self, from: response.data)
            
            await MainActor.run {
                self.itemNameLabel?.text = item.title
            }
        } catch {
            debugLog("[RequestApproval] Error fetching item: \(error)")
            await MainActor.run {
                self.itemNameLabel?.text = "Item: \(itemId)"
            }
        }
    }
    
    private func fetchBorrowerName(borrowerId: String) async {
        do {
            struct ProfileData: Decodable {
                let id: String
                let full_name: String?
            }
            
            let response = try await SupabaseManager.shared.client
                .from("user_profiles")
                .select("id, full_name")
                .eq("id", value: borrowerId)
                .single()
                .execute()
            
            let profile = try JSONDecoder().decode(ProfileData.self, from: response.data)
            
            await MainActor.run {
                let displayName = profile.full_name ?? "Unknown"
                self.borrowerNameLabel?.text = displayName
            }
        } catch {
            debugLog("[RequestApproval] Error fetching borrower: \(error)")
            await MainActor.run {
                self.borrowerNameLabel?.text = "Borrower: \(borrowerId)"
            }
        }
    }
    
    private func updateUI() {
        // Update type label
        typeLabel?.text = requestType == .returnRequest ? "RETURN REQUEST" : "EXTENSION REQUEST"
        
        // Show/hide relevant sections
        if requestType == .returnRequest {
            returnDetailsView?.isHidden = false
            extensionDetailsView?.isHidden = true
        } else {
            returnDetailsView?.isHidden = true
            extensionDetailsView?.isHidden = false
        }

        updateActionButtons()
    }

    private func updateActionButtons() {
        guard let acceptButton, let rejectButton else { return }

        acceptButton.isHidden = false
        acceptButton.isEnabled = true
        acceptButton.alpha = 1
        rejectButton.isHidden = false
        rejectButton.isEnabled = true
        rejectButton.alpha = 1

        if requestType == .extensionRequest {
            acceptButton.setTitle("Accept", for: .normal)
            rejectButton.setTitle("Reject", for: .normal)
            return
        }

        switch currentSubRequestStatus {
        case "accepted":
            acceptButton.setTitle("Show Return Code", for: .normal)
            rejectButton.isHidden = true
            rejectButton.isEnabled = false
        case "completed":
            acceptButton.setTitle("Return Verified", for: .normal)
            acceptButton.isEnabled = false
            acceptButton.alpha = 0.6
            rejectButton.isHidden = true
            rejectButton.isEnabled = false
        case "rejected":
            acceptButton.setTitle("Accept Return", for: .normal)
            rejectButton.setTitle("Rejected", for: .normal)
            rejectButton.isEnabled = false
            rejectButton.alpha = 0.6
        default:
            acceptButton.setTitle("Accept Return", for: .normal)
            rejectButton.setTitle("Reject", for: .normal)
        }
    }
    
    private func setupProofImageView(with path: String) {
        // Ensure we don't add multiple image views if this is called multiple times
        let existingTag = 999
        if returnDetailsView.viewWithTag(existingTag) != nil { return }
        
        // Create title label for the proof image
        let proofTitleLabel = UILabel()
        proofTitleLabel.text = "RETURN PROOF"
        proofTitleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        proofTitleLabel.textColor = .secondaryLabel
        proofTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView()
        imageView.tag = existingTag
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .tertiarySystemGroupedBackground
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        returnDetailsView.addSubview(proofTitleLabel)
        returnDetailsView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            proofTitleLabel.topAnchor.constraint(equalTo: returnNotesLabel.bottomAnchor, constant: 16),
            proofTitleLabel.leadingAnchor.constraint(equalTo: returnDetailsView.leadingAnchor, constant: 20),
            proofTitleLabel.trailingAnchor.constraint(equalTo: returnDetailsView.trailingAnchor, constant: -20),
            
            imageView.topAnchor.constraint(equalTo: proofTitleLabel.bottomAnchor, constant: 8),
            imageView.leadingAnchor.constraint(equalTo: returnDetailsView.leadingAnchor, constant: 20),
            imageView.trailingAnchor.constraint(equalTo: returnDetailsView.trailingAnchor, constant: -20),
            imageView.heightAnchor.constraint(equalToConstant: 200),
            imageView.bottomAnchor.constraint(equalTo: returnDetailsView.bottomAnchor, constant: -16)
        ])
        
        // Dynamically adjust height constraint of the stack wrapper to fit the new content
        if let heightConstraint = returnDetailsView.constraints.first(where: { $0.firstAttribute == .height }) {
            returnDetailsView.removeConstraint(heightConstraint)
        }
        
        if let url = StorageURLBuilder.publicFileURL(for: path) {
            UIImageView.rw_loadImage(from: url) { image in
                if let img = image {
                    imageView.image = img
                } else {
                    imageView.image = UIImage(systemName: "photo")
                    imageView.tintColor = .tertiaryLabel
                }
            }
        }
    }

    
    // MARK: - Actions
    
    @IBAction func acceptButtonTapped(_ sender: UIButton) {
        if requestType == .returnRequest {
            if currentSubRequestStatus == "completed" {
                showAlert(title: "Return Completed", message: "This return has already been verified and completed.")
                return
            }

            let borrowerName = borrowerNameLabel?.text ?? "borrower"
            let title = currentSubRequestStatus == "accepted" ? "Show Return Code?" : "Accept Return?"
            let msg = currentSubRequestStatus == "accepted"
                ? "Open the return code screen for \(borrowerName) so they can complete the handoff."
                : "Approve this return for \(borrowerName) and generate a return code for the handoff."

            showConfirmation(title: title, message: msg) { [weak self] in
                self?.openReturnCodeScreen()
            }
            return
        }

        let borrowerName = borrowerNameLabel?.text ?? "borrower"
        let title: String
        let msg: String
        
        title = "Accept Extension?"
        msg = "Are you sure you want to accept this extension by - \(borrowerName)?"
        
        showConfirmation(title: title, message: msg) {
            Task {
                await self.updateRequestStatus(to: "accepted")
            }
        }
    }
    
    @IBAction func rejectButtonTapped(_ sender: UIButton) {
        let borrowerName = borrowerNameLabel?.text ?? "borrower"
        let title: String
        let msg: String
        
        if requestType == .extensionRequest {
            title = "Reject Extension?"
            msg = "Are you sure you want to reject this extension by - \(borrowerName)?"
        } else {
            title = "Reject Return?"
            msg = "Are you sure you want to reject this return by - \(borrowerName)?"
        }
        
        showConfirmation(title: title, message: msg) {
            Task {
                await self.updateRequestStatus(to: "rejected")
            }
        }
    }
    
    // MARK: - API Calls
    
    private func updateRequestStatus(to status: String) async {
        do {
            let tableName = requestType == .returnRequest ? "return_requests" : "extension_requests"
            
            let _ = try await SupabaseManager.shared.client
                .from(tableName)
                .update(["status": status])
                .eq("id", value: requestId)
                .execute()
            
            // If accepting an extension request, update the main booking end_date and return_time
            if requestType == .extensionRequest && status == "accepted" {
                struct ExtensionRequestData: Decodable {
                    let new_end_date: String       // "yyyy-MM-dd" (date column)
                    let new_return_time: String?    // "HH:mm:ss+05:30" (timetz column)
                    let additional_cost: Double
                }
                
                // Fetch extension details needed for the update
                let extResponse = try await SupabaseManager.shared.client
                    .from("extension_requests")
                    .select("new_end_date, new_return_time, additional_cost")
                    .eq("id", value: requestId)
                    .single()
                    .execute()
                    
                let extData = try JSONDecoder().decode(ExtensionRequestData.self, from: extResponse.data)
                
                // Update end_date and return_time on the main request
                struct MainRequestUpdate: Encodable {
                    let end_date: String
                    let return_time: String?
                }
                let updateData = MainRequestUpdate(
                    end_date: extData.new_end_date,
                    return_time: extData.new_return_time
                )
                
                let _ = try await SupabaseManager.shared.client
                    .from("requests")
                    .update(updateData)
                    .eq("id", value: bookingId)
                    .execute()
                    
                // Also update the total_amount & rental_fee in the payments table
                struct PaymentData: Decodable {
                    let rental_fee: Double?
                    let total_amount: Double?
                }
                
                if let paymentResponse = try? await SupabaseManager.shared.client
                    .from("payments")
                    .select("rental_fee, total_amount")
                    .eq("request_id", value: bookingId)
                    .single()
                    .execute() {
                    
                    if let paymentData = try? JSONDecoder().decode(PaymentData.self, from: paymentResponse.data) {
                        let currentRental = paymentData.rental_fee ?? 0.0
                        let currentTotal = paymentData.total_amount ?? 0.0
                        
                        let newRental = currentRental + extData.additional_cost
                        let newTotal = currentTotal + extData.additional_cost
                        
                        struct PaymentUpdate: Encodable {
                            let rental_fee: Double
                            let total_amount: Double
                        }
                        
                        let _ = try? await SupabaseManager.shared.client
                            .from("payments")
                            .update(PaymentUpdate(rental_fee: newRental, total_amount: newTotal))
                            .eq("request_id", value: bookingId)
                            .execute()
                    }
                }
                
                debugLog("[RequestApproval] Main request \(bookingId) extended to \(extData.new_end_date) returnTime=\(extData.new_return_time ?? "nil"), added \(extData.additional_cost) to payment.")
            }
            
            await MainActor.run {
                self.currentSubRequestStatus = status.lowercased()
                self.updateActionButtons()
                let message = status == "accepted" ? "Request has been accepted" : "Request has been rejected"

                // Notify all observers (LenderView, BookingApprovalVC) so they refresh
                NotificationCenter.default.post(name: Notification.Name("requestsShouldRefresh"), object: nil)

                self.showAlert(title: "Success", message: message) {
                    self.navigationController?.popViewController(animated: true)
                }
            }
        } catch {
            debugLog("[RequestApproval] Error updating status: \(error)")
            await MainActor.run {
                self.showAlert(title: "Error", message: "Failed to update request status")
            }
        }
    }

    private func openReturnCodeScreen() {
        let otpVC = LenderReturnOTPViewController()
        otpVC.requestId = bookingId
        otpVC.borrowerName = borrowerNameLabel?.text ?? "Borrower"
        otpVC.onCodeGenerated = { [weak self] in
            guard let self else { return }
            self.currentSubRequestStatus = "accepted"
            NotificationCenter.default.post(name: Notification.Name("requestsShouldRefresh"), object: nil)
        }
        navigationController?.pushViewController(otpVC, animated: true)
    }
    
    // MARK: - Helpers

    private func syncItemAvailabilityIfPossible(itemId: String, ownerId: String, isActive: Bool) async throws {
        guard let currentUserId = await SupabaseManager.shared.currentUserId(),
              currentUserId == ownerId else {
            return
        }

        do {
            _ = try await SupabaseManager.shared.client
                .from("items")
                .update(["is_active": isActive])
                .eq("id", value: itemId)
                .eq("owner_id", value: ownerId)
                .execute()
        } catch {
            if isItemsAvailabilityPermissionError(error) {
                debugLog("[RequestApproval] Skipping item availability sync due to items RLS: \(error)")
                return
            }
            throw error
        }
    }

    private func isItemsAvailabilityPermissionError(_ error: Error) -> Bool {
        let message = (error as NSError).localizedDescription.lowercased()
        return message.contains("row-level security") && message.contains("items")
    }
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
    
    private func showConfirmation(title: String, message: String, onConfirm: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Confirm", style: .default) { _ in
            onConfirm()
        })
        present(alert, animated: true)
    }
}
