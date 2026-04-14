//
//  SignUpModels.swift
//  RentiWise
//
//  Created by admin99 on 30/10/25.
//

import Foundation

struct SignUpUserProfile {
    let fullName: String
    let phone: String
}

struct SignUpCredentials {
    let email: String
    let password: String
}

struct SignUpDBUserRow: Encodable {
    let id: String
    let email: String
    let full_name: String
    let phone: String
}

enum AuthValidationError: LocalizedError {
    case missingFields
    case invalidEmail
    case weakPassword
    case invalidPhone
    case invalidFullName

    var errorDescription: String? {
        switch self {
        case .missingFields: return "Please fill all required fields."
        case .invalidEmail: return "Please enter a valid email address."
        case .weakPassword: return "Password must be at least 6 characters with an uppercase letter, lowercase letter, and a digit."
        case .invalidPhone: return "Please enter a valid 10-digit Indian phone number."
        case .invalidFullName: return "Name must contain only letters and spaces (2–50 characters)."
        }
    }
}

struct AuthValidationService {

    // MARK: - Email (RFC-style regex)
    func isValidEmail(_ email: String) -> Bool {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: email)
    }

    // MARK: - Password (min 6, 1 upper, 1 lower, 1 digit)
    func isValidPassword(_ password: String) -> Bool {
        guard password.count >= 6 else { return false }
        let hasUpper = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLower = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasDigit = password.rangeOfCharacter(from: .decimalDigits) != nil
        return hasUpper && hasLower && hasDigit
    }

    // MARK: - Phone (10 digits after stripping prefix/spaces)
    func isValidPhone(_ phone: String) -> Bool {
        let digits = sanitizePhone(phone)
        return digits.count == 10 && digits.allSatisfy({ $0.isNumber })
    }

    /// Strips +91, spaces, dashes — returns pure 10 digits
    func sanitizePhone(_ phone: String) -> String {
        var raw = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip country code prefix
        if raw.hasPrefix("+91") { raw = String(raw.dropFirst(3)) }
        else if raw.hasPrefix("91") && raw.count > 10 { raw = String(raw.dropFirst(2)) }
        else if raw.hasPrefix("0") && raw.count == 11 { raw = String(raw.dropFirst(1)) }
        // Strip remaining non-digits
        return raw.filter { $0.isNumber }
    }

    /// Returns the E.164 formatted phone ("+91" + 10 digits)
    func e164Phone(_ phone: String) -> String {
        "+91" + sanitizePhone(phone)
    }

    // MARK: - Full Name (letters + spaces, 2–50 chars)
    func isValidFullName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, trimmed.count <= 50 else { return false }
        // Allow letters (including unicode letters like accented chars) and spaces only
        let allowed = CharacterSet.letters.union(.whitespaces)
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    // MARK: - Postal Code (6-digit Indian PIN)
    func isValidPostalCode(_ code: String) -> Bool {
        let digits = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return digits.count == 6 && digits.allSatisfy({ $0.isNumber })
    }

    // MARK: - UPI ID (username@bank format)
    func isValidUPIId(_ upi: String) -> Bool {
        let pattern = "^[a-zA-Z0-9._-]+@[a-zA-Z][a-zA-Z0-9]*$"
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: upi)
    }
}
