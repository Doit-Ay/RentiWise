import XCTest
@testable import RentiWise

final class AuthValidationTests: XCTestCase {

    let service = AuthValidationService()

    // MARK: - Email Validation

    func testValidEmailStandard() {
        XCTAssertTrue(service.isValidEmail("user@example.com"))
    }

    func testValidEmailSubdomain() {
        XCTAssertTrue(service.isValidEmail("user@mail.example.com"))
    }

    func testInvalidEmailNoAt() {
        XCTAssertFalse(service.isValidEmail("userexample.com"))
    }

    func testInvalidEmailNoDot() {
        XCTAssertFalse(service.isValidEmail("user@examplecom"))
    }

    func testInvalidEmailEmpty() {
        XCTAssertFalse(service.isValidEmail(""))
    }

    func testInvalidEmailOnlyAt() {
        // "@ " has @ but no dot
        XCTAssertFalse(service.isValidEmail("@"))
    }

    func testInvalidEmailOnlyDot() {
        // "." has dot but no @
        XCTAssertFalse(service.isValidEmail("."))
    }

    // MARK: - Password Validation

    func testValidPasswordMinLength() {
        XCTAssertTrue(service.isValidPassword("123456"))
    }

    func testValidPasswordLong() {
        XCTAssertTrue(service.isValidPassword("aVeryLongSecurePassword!@#"))
    }

    func testInvalidPasswordTooShort() {
        XCTAssertFalse(service.isValidPassword("12345"))
    }

    func testInvalidPasswordEmpty() {
        XCTAssertFalse(service.isValidPassword(""))
    }

    func testInvalidPasswordSingleChar() {
        XCTAssertFalse(service.isValidPassword("a"))
    }

    // MARK: - AuthValidationError descriptions

    func testMissingFieldsErrorDescription() {
        let error = AuthValidationError.missingFields
        XCTAssertEqual(error.errorDescription, "Please fill all required fields.")
    }

    func testInvalidEmailErrorDescription() {
        let error = AuthValidationError.invalidEmail
        XCTAssertEqual(error.errorDescription, "Please enter a valid email address.")
    }

    func testWeakPasswordErrorDescription() {
        let error = AuthValidationError.weakPassword
        XCTAssertEqual(error.errorDescription, "Password should be at least 6 characters.")
    }
}
