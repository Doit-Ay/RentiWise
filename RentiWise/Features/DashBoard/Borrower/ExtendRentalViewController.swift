//
//  ExtendRentalViewController.swift
//  RentiWise
//
//  Created by admin67 on 2026-02-05.
//

import UIKit
import Supabase

class ExtendRentalViewController: UIViewController {
    
    // MARK: - Properties
    
    var request: RequestWithItem?
    var originalEndDate: Date?
    /// Called on the caller when a request is successfully submitted (before dismiss).
    var onRequestSubmitted: (() -> Void)?
    private var newEndDate: Date?
    private var additionalDays: Int = 0
    private var additionalCost: Double = 0.0
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var itemNameLabel: UILabel!
    @IBOutlet weak var currentEndDateLabel: UILabel!
    @IBOutlet weak var newEndDatePicker: UIDatePicker!
    @IBOutlet weak var additionalDaysLabel: UILabel!
    @IBOutlet weak var pricePerDayLabel: UILabel!
    @IBOutlet weak var additionalFeeLabel: UILabel!
    @IBOutlet weak var totalExtensionLabel: UILabel!
    @IBOutlet weak var sendRequestButton: UIButton!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        configureData()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Set corner radius for button
        sendRequestButton.layer.cornerRadius = 12
        sendRequestButton.layer.masksToBounds = true
        
        // Configure date picker
        newEndDatePicker.datePickerMode = .date
        let minDate = originalEndDate ?? Date()
        newEndDatePicker.minimumDate = minDate
        // Cap at 90 days from original end date to prevent excessive extensions
        if let maxDate = Calendar.current.date(byAdding: .day, value: 90, to: minDate) {
            newEndDatePicker.maximumDate = maxDate
        }
        newEndDatePicker.addTarget(self, action: #selector(datePickerChanged), for: .valueChanged)
    }
    
    private func configureData() {
        guard let req = request else { return }
        
        // Set item name
        itemNameLabel.text = req.items?.title ?? "Item"
        
        // Set current end date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        if let endDate = originalEndDate {
            currentEndDateLabel.text = dateFormatter.string(from: endDate)
            // Set picker's date to be one day after current end date
            newEndDatePicker.date = Calendar.current.date(byAdding: .day, value: 1, to: endDate) ?? endDate
        } else {
            currentEndDateLabel.text = "N/A"
        }
        
        // Set price per day
        if let pricePerDay = req.items?.price_per_day {
            pricePerDayLabel.text = "₹\(Int(pricePerDay))/day"
        } else {
            pricePerDayLabel.text = "N/A"
        }
        
        // Calculate initial values
        datePickerChanged()
    }
    
    // MARK: - Actions
    
    @objc private func datePickerChanged() {
        guard let originalEnd = originalEndDate,
              let pricePerDay = request?.items?.price_per_day else {
            return
        }
        
        newEndDate = newEndDatePicker.date
        
        // Calculate additional days
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: originalEnd, to: newEndDatePicker.date)
        additionalDays = max(0, components.day ?? 0)
        
        // Calculate additional cost
        additionalCost = Double(additionalDays) * pricePerDay
        
        // Update labels
        additionalDaysLabel.text = "\(additionalDays) day\(additionalDays == 1 ? "" : "s")"
        additionalFeeLabel.text = "₹\(Int(additionalCost))"
        totalExtensionLabel.text = "₹\(Int(additionalCost))"
        
        // Disable button if no additional days
        sendRequestButton.isEnabled = additionalDays > 0
        sendRequestButton.alpha = additionalDays > 0 ? 1.0 : 0.5
    }
    
    @IBAction func sendRequestButtonTapped(_ sender: UIButton) {
        guard additionalDays > 0,
              let req = request,
              let newEnd = newEndDate else {
            showAlert(title: "Error", message: "Please select a valid extension date")
            return
        }
        
        // Disable button to prevent double-tap
        sendRequestButton.isEnabled = false
        
        Task {
            await submitExtensionRequest(for: req, newEndDate: newEnd)
        }
    }
    
    @IBAction func cancelButtonTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }
    
    // MARK: - API Calls
    
    private func submitExtensionRequest(for request: RequestWithItem, newEndDate: Date) async {
        // Format new end date for database
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = .current
        let newEndDateString = dateFormatter.string(from: newEndDate)
        
        do {
            // Create extension request struct
            struct ExtensionRequest: Encodable {
                let request_id: String
                let original_end_date: String
                let new_end_date: String
                let additional_days: Int
                let additional_cost: Double
                let status: String
                let created_at: String
            }
            
            let extensionData = ExtensionRequest(
                request_id: request.id,
                original_end_date: request.end_date,
                new_end_date: newEndDateString,
                additional_days: additionalDays,
                additional_cost: additionalCost,
                status: "pending",
                created_at: ISO8601DateFormatter().string(from: Date())
            )
            
            // Insert into database
            // NOTE: This requires an "extension_requests" table in Supabase
            let _ = try await SupabaseManager.shared.client
                .from("extension_requests")
                .insert(extensionData)
                .execute()
            
            await MainActor.run {
                self.sendRequestButton.isEnabled = true
                self.onRequestSubmitted?()   // notify BookingApprovalVC instantly

                // Track analytics & notify lender
                AnalyticsService.shared.trackSubRequestSubmitted(requestId: request.id, type: "extension")
                NotificationService.shared.notifyNewSubRequest(
                    requestId: request.id,
                    itemTitle: request.items?.title ?? "Item",
                    type: "extension"
                )

                self.showAlert(title: "Success", message: "Extension request sent to owner") {
                    self.dismiss(animated: true)
                }
            }
        } catch {
            debugLog("[ExtendRental] Error submitting extension request: \(error)")
            await MainActor.run {
                self.sendRequestButton.isEnabled = true
                self.showAlert(title: "Error", message: "Failed to send extension request. Please try again.")
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
}
