import XCTest
@testable import RentiWise

final class ProfileModelTests: XCTestCase {

    // MARK: - UserProfile

    func testUserProfileInitialization() {
        let profile = UserProfile(id: "u1", fullName: "John Doe", email: "john@example.com", phone: "+911234567890", upiId: "john@upi")
        XCTAssertEqual(profile.id, "u1")
        XCTAssertEqual(profile.fullName, "John Doe")
        XCTAssertEqual(profile.email, "john@example.com")
        XCTAssertEqual(profile.phone, "+911234567890")
    }

    func testUserProfileEmptyFields() {
        let profile = UserProfile(id: "u2", fullName: "", email: "", phone: "", upiId: "")
        XCTAssertTrue(profile.fullName.isEmpty)
        XCTAssertTrue(profile.email.isEmpty)
        XCTAssertTrue(profile.phone.isEmpty)
    }

    // MARK: - DBUserRow Decoding

    func testDBUserRowDecodingAllFields() throws {
        let json = """
        {
            "id": "db-1",
            "email": "user@test.com",
            "full_name": "Test User",
            "phone": "123456",
            "profile_photo_url": "https://photo.com/img.jpg",
            "upi_id": "user@upi"
        }
        """.data(using: .utf8)!

        let row = try JSONDecoder().decode(DBUserRow.self, from: json)
        XCTAssertEqual(row.id, "db-1")
        XCTAssertEqual(row.email, "user@test.com")
        XCTAssertEqual(row.full_name, "Test User")
        XCTAssertEqual(row.phone, "123456")
        XCTAssertEqual(row.profile_photo_url, "https://photo.com/img.jpg")
    }

    func testDBUserRowDecodingNilOptionals() throws {
        let json = """
        {
            "id": "db-2",
            "email": null,
            "full_name": null,
            "phone": null,
            "profile_photo_url": null,
            "upi_id": null
        }
        """.data(using: .utf8)!

        let row = try JSONDecoder().decode(DBUserRow.self, from: json)
        XCTAssertEqual(row.id, "db-2")
        XCTAssertNil(row.email)
        XCTAssertNil(row.full_name)
        XCTAssertNil(row.phone)
        XCTAssertNil(row.profile_photo_url)
    }
}
