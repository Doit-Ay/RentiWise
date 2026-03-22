import XCTest
@testable import RentiWise

final class AddressModelTests: XCTestCase {

    // MARK: - Address Decoding

    func testAddressDecodingAllFields() throws {
        let json = """
        {
            "id": "addr-1",
            "user_id": "user-1",
            "label": "Home",
            "full_name": "John Doe",
            "phone": "+911234567890",
            "address_line1": "123 Main St",
            "address_line2": "Apt 4",
            "city": "Chennai",
            "state": "Tamil Nadu",
            "postal_code": "600001",
            "country": "India",
            "is_default": true,
            "created_at": "2025-12-01T00:00:00Z",
            "latitude": 13.08,
            "longitude": 80.27
        }
        """.data(using: .utf8)!

        let addr = try JSONDecoder().decode(Address.self, from: json)
        XCTAssertEqual(addr.id, "addr-1")
        XCTAssertEqual(addr.user_id, "user-1")
        XCTAssertEqual(addr.label, "Home")
        XCTAssertEqual(addr.city, "Chennai")
        XCTAssertEqual(addr.state, "Tamil Nadu")
        XCTAssertEqual(addr.postal_code, "600001")
        XCTAssertTrue(addr.is_default)
        XCTAssertEqual(addr.latitude, 13.08)
        XCTAssertEqual(addr.longitude, 80.27)
    }

    func testAddressDecodingNilOptionals() throws {
        let json = """
        {
            "id": "addr-2",
            "user_id": "user-2",
            "label": null,
            "full_name": null,
            "phone": null,
            "address_line1": "456 Oak Ave",
            "address_line2": null,
            "city": "Mumbai",
            "state": "Maharashtra",
            "postal_code": "400001",
            "country": "India",
            "is_default": false,
            "created_at": null,
            "latitude": null,
            "longitude": null
        }
        """.data(using: .utf8)!

        let addr = try JSONDecoder().decode(Address.self, from: json)
        XCTAssertNil(addr.label)
        XCTAssertNil(addr.full_name)
        XCTAssertNil(addr.phone)
        XCTAssertNil(addr.address_line2)
        XCTAssertFalse(addr.is_default)
        XCTAssertNil(addr.latitude)
        XCTAssertNil(addr.longitude)
    }

    func testAddressEquality() throws {
        let json = """
        {
            "id": "addr-eq",
            "user_id": "u",
            "address_line1": "1",
            "city": "C",
            "state": "S",
            "postal_code": "P",
            "country": "Co",
            "is_default": false
        }
        """.data(using: .utf8)!

        let a1 = try JSONDecoder().decode(Address.self, from: json)
        let a2 = try JSONDecoder().decode(Address.self, from: json)
        XCTAssertEqual(a1, a2)
    }

    // MARK: - AddressInput Encoding

    func testAddressInputEncoding() throws {
        let input = AddressInput(
            user_id: "user-1",
            label: "Office",
            full_name: "Jane",
            phone: "999",
            address_line1: "789 Business Rd",
            address_line2: nil,
            city: "Delhi",
            state: "Delhi",
            postal_code: "110001",
            country: "India",
            is_default: true,
            latitude: 28.61,
            longitude: 77.20
        )

        let data = try JSONEncoder().encode(input)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(dict?["user_id"] as? String, "user-1")
        XCTAssertEqual(dict?["label"] as? String, "Office")
        XCTAssertEqual(dict?["city"] as? String, "Delhi")
        XCTAssertEqual(dict?["is_default"] as? Bool, true)
    }

    // MARK: - AddressPatch Encoding

    func testAddressPatchEncoding() throws {
        let patch = AddressPatch(
            label: "Updated Home",
            full_name: "Updated Name",
            phone: "111",
            address_line1: "New Address",
            address_line2: "Suite B",
            city: "Bangalore",
            state: "Karnataka",
            postal_code: "560001",
            country: "India",
            is_default: false,
            latitude: nil,
            longitude: nil
        )

        let data = try JSONEncoder().encode(patch)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(dict?["label"] as? String, "Updated Home")
        XCTAssertEqual(dict?["city"] as? String, "Bangalore")
    }
}
