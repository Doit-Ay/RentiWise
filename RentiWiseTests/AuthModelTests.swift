import XCTest
@testable import RentiWise

final class AuthModelTests: XCTestCase {

    // MARK: - SignInCredentials

    func testSignInCredentialsInitialization() {
        let creds = SignInCredentials(email: "test@example.com", password: "password123")
        XCTAssertEqual(creds.email, "test@example.com")
        XCTAssertEqual(creds.password, "password123")
    }

    func testSignInCredentialsEmptyValues() {
        let creds = SignInCredentials(email: "", password: "")
        XCTAssertTrue(creds.email.isEmpty)
        XCTAssertTrue(creds.password.isEmpty)
    }

    // MARK: - SignUpCredentials

    func testSignUpCredentialsInitialization() {
        let creds = SignUpCredentials(email: "new@user.com", password: "secure123")
        XCTAssertEqual(creds.email, "new@user.com")
        XCTAssertEqual(creds.password, "secure123")
    }

    // MARK: - SignUpUserProfile

    func testSignUpUserProfileInitialization() {
        let profile = SignUpUserProfile(fullName: "John Doe", phone: "+911234567890")
        XCTAssertEqual(profile.fullName, "John Doe")
        XCTAssertEqual(profile.phone, "+911234567890")
    }

    // MARK: - MinimalUserInsert Encoding

    func testMinimalUserInsertEncoding() throws {
        let insert = MinimalUserInsert(id: "user-uuid", email: "test@test.com")
        let data = try JSONEncoder().encode(insert)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(dict?["id"] as? String, "user-uuid")
        XCTAssertEqual(dict?["email"] as? String, "test@test.com")
    }

    // MARK: - SignUpDBUserRow Encoding

    func testSignUpDBUserRowEncoding() throws {
        let row = SignUpDBUserRow(id: "u1", email: "e@e.com", full_name: "Full Name", phone: "123")
        let data = try JSONEncoder().encode(row)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(dict?["id"] as? String, "u1")
        XCTAssertEqual(dict?["full_name"] as? String, "Full Name")
        XCTAssertEqual(dict?["phone"] as? String, "123")
    }
}
