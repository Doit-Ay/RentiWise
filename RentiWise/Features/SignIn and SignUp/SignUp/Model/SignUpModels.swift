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

    var errorDescription: String? {
        switch self {
        case .missingFields: return "Please fill all required fields."
        case .invalidEmail: return "Please enter a valid email address."
        case .weakPassword: return "Password should be at least 6 characters."
        }
    }
}

struct AuthValidationService {
    func isValidEmail(_ email: String) -> Bool {
        email.contains("@") && email.contains(".")
    }

    func isValidPassword(_ password: String) -> Bool {
        password.count >= 6
    }
}
