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
    
    // Additional Outlets for titles
    @IBOutlet weak var curEndTitleLabel: UILabel!
    @IBOutlet weak var newDateTitleLabel: UILabel!
    @IBOutlet weak var additionalDaysTitleLabel: UILabel!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureData()   // Parse times + build originalEndDate first
        setupUI()         // Then configure picker with correct originalEndDate
        datePickerChanged() // Calculate initial values
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Set corner radius for button
        sendRequestButton.layer.cornerRadius = 12
        sendRequestButton.layer.masksToBounds = true
        
        // Configure date picker
        let isHourly = request?.rental_unit == "hour"
        
        if isHourly {
            // Hourly: show only time picker (no date column)
            newEndDatePicker.datePickerMode = .time
            newEndDatePicker.minuteInterval = 1
        } else {
            // Daily: show date and time so borrower can choose end date + end time
            newEndDatePicker.datePickerMode = .dateAndTime
        }
        
        let minDate = originalEndDate ?? Date()
        newEndDatePicker.minimumDate = minDate
        
        if isHourly {
            if let maxDate = Calendar.current.date(byAdding: .day, value: 7, to: minDate) {
                newEndDatePicker.maximumDate = maxDate
            }
            // Default picker to 1 hour after original end
            newEndDatePicker.date = Calendar.current.date(byAdding: .hour, value: 1, to: minDate) ?? minDate
        } else {
            // Cap at 90 days from original end date to prevent excessive extensions
            if let maxDate = Calendar.current.date(byAdding: .day, value: 90, to: minDate) {
                newEndDatePicker.maximumDate = maxDate
            }
            // Default picker to 1 day after original end
            newEndDatePicker.date = Calendar.current.date(byAdding: .day, value: 1, to: minDate) ?? minDate
        }
        newEndDatePicker.addTarget(self, action: #selector(datePickerChanged), for: .valueChanged)
    }
    
    private func configureData() {
        guard let req = request else { return }
        let isHourly = req.rental_unit == "hour"
        
        // Build accurate originalEndDate by combining end_date + return_time from DB.
        // DB stores return_time as "HH:mm:ss+05:30" (timetz).
        // We use BookingPresentationFormatter.parseTime to handle all formats,
        // then combine with end_date to get the full Date.
        if let returnTimeParsed = BookingPresentationFormatter.parseTime(req.return_time),
           let endDateParsed = BookingPresentationFormatter.sqlDateFormatter.date(from: req.end_date) {
            self.originalEndDate = BookingPresentationFormatter.combine(date: endDateParsed, time: returnTimeParsed)
        } else if let endDateParsed = BookingPresentationFormatter.sqlDateFormatter.date(from: req.end_date) {
            // Fallback: no return_time, use midnight of end_date
            self.originalEndDate = endDateParsed
        }
        
        if isHourly {
            curEndTitleLabel?.text = "CURRENT RETURN TIME AND DATE"
            newDateTitleLabel?.text = "NEW RETURN TIME"
            additionalDaysTitleLabel?.text = "Additional Time"
        } else {
            curEndTitleLabel?.text = "CURRENT RETURN DATE"
            newDateTitleLabel?.text = "NEW RETURN DATE AND TIME"
            additionalDaysTitleLabel?.text = "Additional Time"
        }
        
        // Set item name
        itemNameLabel.text = req.items?.title ?? "Item"
        
        // Set current end date display
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short  // Always show time so borrower sees actual return time
        
        if let endDate = originalEndDate {
            currentEndDateLabel.text = dateFormatter.string(from: endDate)
        } else {
            currentEndDateLabel.text = "N/A"
        }
        
        // Set price per unit
        if let pricePerDay = req.items?.price_per_day {
            if isHourly {
                let hourlyRate = pricePerDay / 8.0
                pricePerDayLabel.text = "₹\(Int(round(hourlyRate)))/hour"
            } else {
                pricePerDayLabel.text = "₹\(Int(pricePerDay))/day"
            }
        } else {
            pricePerDayLabel.text = "N/A"
        }
    }
    
    // MARK: - Actions
    
    @objc private func datePickerChanged() {
        guard let originalEnd = originalEndDate,
              let pricePerDay = request?.items?.price_per_day else {
            return
        }
        
        let isHourly = request?.rental_unit == "hour"
        
        if isHourly {
            // For hourly mode the picker is .time so it only changes H:M.
            // We combine the original end's date portion with the picker's time,
            // and if it is <= originalEnd we assume the next day.
            let calendar = Calendar.current
            var candidate = BookingPresentationFormatter.combine(date: originalEnd, time: newEndDatePicker.date)
            if candidate <= originalEnd {
                candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
            }
            newEndDate = candidate
            
            let durationInSeconds = candidate.timeIntervalSince(originalEnd)
            let totalMins = Int(round(max(0, durationInSeconds / 60)))
            let displayHours = totalMins / 60
            let displayMins = totalMins % 60
            let additionalHours = Int(ceil(max(0, durationInSeconds / 3600.0)))
            self.additionalDays = additionalHours
            
            let hourlyRate = pricePerDay / 8.0
            additionalCost = Double(additionalHours) * hourlyRate
            
            if displayHours == 0 {
                additionalDaysLabel.text = "\(displayMins) min\(displayMins == 1 ? "" : "s")"
            } else if displayMins == 0 {
                additionalDaysLabel.text = "\(displayHours) hour\(displayHours == 1 ? "" : "s")"
            } else {
                additionalDaysLabel.text = "\(displayHours) hr \(displayMins) min"
            }
        } else {
            newEndDate = newEndDatePicker.date
            
            // For daily mode: compute full duration difference
            let durationInSeconds = newEndDatePicker.date.timeIntervalSince(originalEnd)
            let totalHours = durationInSeconds / 3600.0
            
            if totalHours < 24 {
                // Less than a day: show hours
                let hours = Int(ceil(max(0, totalHours)))
                self.additionalDays = hours > 0 ? 1 : 0 // At minimum 1 day charge if any extension
                additionalCost = Double(max(1, hours)) * (pricePerDay / 24.0) * Double(hours)
                // Simplify: charge per-day rate for any partial day
                additionalCost = pricePerDay // At least 1 day
                additionalDaysLabel.text = "\(hours) hour\(hours == 1 ? "" : "s")"
                self.additionalDays = hours > 0 ? 1 : 0
            } else {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: originalEnd), to: calendar.startOfDay(for: newEndDatePicker.date))
                var days = max(0, components.day ?? 0)
                
                // If the time portion is later, it's still the same day count
                // If days == 0 but there's a time difference, count as 1 day
                if days == 0 && durationInSeconds > 0 {
                    days = 1
                }
                
                additionalDays = days
                additionalCost = Double(additionalDays) * pricePerDay
                additionalDaysLabel.text = "\(additionalDays) day\(additionalDays == 1 ? "" : "s")"
            }
        }
        
        // Update labels
        additionalFeeLabel.text = "₹\(Int(round(additionalCost)))"
        totalExtensionLabel.text = "₹\(Int(round(additionalCost)))"
        
        // Disable button if no additional units
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
        // Format new end date (date only) and return time separately.
        // extension_requests.new_end_date is type `date` → "yyyy-MM-dd"
        // extension_requests.new_return_time is type `timetz` → "HH:mm:ss+05:30"
        let newEndDateString = BookingPresentationFormatter.sqlDateString(for: newEndDate)
        let newReturnTimeString = BookingPresentationFormatter.sqlTimeString(for: newEndDate)
        
        do {
            // Create extension request struct
            struct ExtensionRequest: Encodable {
                let request_id: String
                let original_end_date: String
                let new_end_date: String
                let new_return_time: String
                let additional_days: Int
                let additional_cost: Double
                let status: String
                let created_at: String
            }
            
            let extensionData = ExtensionRequest(
                request_id: request.id,
                original_end_date: request.end_date,
                new_end_date: newEndDateString,
                new_return_time: newReturnTimeString,
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
