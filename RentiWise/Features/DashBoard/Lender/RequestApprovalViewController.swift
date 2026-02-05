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
        
        // Style buttons
        acceptButton.layer.cornerRadius = 14
        acceptButton.layer.masksToBounds = true
        
        rejectButton.layer.cornerRadius = 14
        rejectButton.layer.masksToBounds = true
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
            
            print("[RequestApproval] Fetching from \(tableName) with ID: \(requestId)")
            
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
                    let status: String
                    let created_at: String
                }
                
                let request = try JSONDecoder().decode(ReturnRequestData.self, from: data)
                print("[RequestApproval] Return request loaded: \(request.id)")
                
                await MainActor.run {
                    self.returnNotesLabel?.text = request.notes?.isEmpty == false ? request.notes : "No notes provided"
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
                print("[RequestApproval] Extension request loaded: \(request.id)")
                
                await MainActor.run {
                    self.originalEndDateLabel?.text = "Original End: \(request.original_end_date)"
                    self.newEndDateLabel?.text = "New End: \(request.new_end_date)"
                    self.additionalDaysLabel?.text = "\(request.additional_days) additional days - ₹\(String(format: "%.0f", request.additional_cost))"
                    self.updateUI()
                }
            }
            
            // Now fetch booking details
            await fetchBookingDetails()
            
        } catch {
            print("[RequestApproval] Error fetching request: \(error)")
            if let decodingError = error as? DecodingError {
                print("[RequestApproval] Decoding error: \(decodingError)")
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
            }
            
            print("[RequestApproval] Fetching booking with ID: \(bookingId)")
            
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
            }
        } catch {
            print("[RequestApproval] Error fetching booking: \(error)")
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
                let name: String
            }
            
            let response = try await SupabaseManager.shared.client
                .from("items")
                .select("id, name")
                .eq("id", value: itemId)
                .single()
                .execute()
            
            let item = try JSONDecoder().decode(ItemData.self, from: response.data)
            
            await MainActor.run {
                self.itemNameLabel?.text = item.name
            }
        } catch {
            print("[RequestApproval] Error fetching item: \(error)")
            await MainActor.run {
                self.itemNameLabel?.text = "Item: \(itemId)"
            }
        }
    }
    
    private func fetchBorrowerName(borrowerId: String) async {
        do {
            struct ProfileData: Decodable {
                let id: String
                let name: String?
                let email: String?
            }
            
            let response = try await SupabaseManager.shared.client
                .from("profiles")
                .select("id, name, email")
                .eq("id", value: borrowerId)
                .single()
                .execute()
            
            let profile = try JSONDecoder().decode(ProfileData.self, from: response.data)
            
            await MainActor.run {
                let displayName = profile.name ?? profile.email ?? "Unknown"
                self.borrowerNameLabel?.text = displayName
            }
        } catch {
            print("[RequestApproval] Error fetching borrower: \(error)")
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
    }

    
    // MARK: - Actions
    
    @IBAction func acceptButtonTapped(_ sender: UIButton) {
        showConfirmation(title: "Accept Request?", message: "Are you sure you want to accept this request?") {
            Task {
                await self.updateRequestStatus(to: "accepted")
            }
        }
    }
    
    @IBAction func rejectButtonTapped(_ sender: UIButton) {
        showConfirmation(title: "Reject Request?", message: "Are you sure you want to reject this request?") {
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
            
            await MainActor.run {
                let message = status == "accepted" ? "Request has been accepted" : "Request has been rejected"
                showAlert(title: "Success", message: message) {
                    self.navigationController?.popViewController(animated: true)
                }
            }
        } catch {
            print("[RequestApproval] Error updating status: \(error)")
            await MainActor.run {
                showAlert(title: "Error", message: "Failed to update request status")
            }
        }
    }
    
    // MARK: - Helpers
    
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
