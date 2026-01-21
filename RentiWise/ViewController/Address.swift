import Foundation

struct Address: Codable, Identifiable, Equatable {
    let id: String
    let user_id: String
    var label: String?
    var full_name: String?
    var phone: String?
    var address_line1: String
    var address_line2: String?
    var city: String
    var state: String
    var postal_code: String
    var country: String
    var is_default: Bool
    let created_at: String?
}

struct AddressInput: Encodable {
    let user_id: String
    let label: String?
    let full_name: String?
    let phone: String?
    let address_line1: String
    let address_line2: String?
    let city: String
    let state: String
    let postal_code: String
    let country: String
    let is_default: Bool
}

struct AddressPatch: Encodable {
    let label: String?
    let full_name: String?
    let phone: String?
    let address_line1: String
    let address_line2: String?
    let city: String
    let state: String
    let postal_code: String
    let country: String
    let is_default: Bool
}
