import XCTest
@testable import DescargaMasivaSATKit

final class Authentication: XCTestCase {
    
    func testAddCerta() throws {
        XCTAssertThrowsError(try AuthenticationManager.shared.getCertUtils())
    }
    
    func testAddCertData() throws {
        if let certUrl = Bundle(for: Authentication.self).url(forResource: "certificate", withExtension: ".cer"), let keyUrl = Bundle(for: Authentication.self).url(forResource: "privkey", withExtension: ".key") {
            let certData = try Data(contentsOf: certUrl)
            let keyData = try Data(contentsOf: keyUrl)
            try AuthenticationManager.shared.add(certData: certData, keyData: keyData)
        }
    }
    
    func testAddCertUtils() throws {
        if let certUrl = Bundle(for: Authentication.self).url(forResource: "certificate", withExtension: ".cer"), let keyUrl = Bundle(for: Authentication.self).url(forResource: "privkey", withExtension: ".key") {
            let certData = try Data(contentsOf: certUrl)
            let keyData = try Data(contentsOf: keyUrl)
            let certUtils = try CertUtils(certData: certData, keyData: keyData)
            AuthenticationManager.shared.add(certUtils: certUtils)
        }
    }
    
    func testGetCFDIToken() async throws {
        let token = try await AuthenticationManager.shared.getToken()
        let tokens = AuthenticationManager.shared.getTokens()
        XCTAssert(tokens.count > 0)
        XCTAssertEqual(token, tokens["CFDI"])
    }
    
    func testGetCFDIMultipleToken() async throws {
        let firstToken = try await AuthenticationManager.shared.getToken()
        let secondToken = try await AuthenticationManager.shared.getToken()
        XCTAssertEqual(firstToken, secondToken)
        let tokens = AuthenticationManager.shared.getTokens()
        XCTAssertGreaterThan(tokens.count, 0)
        XCTAssertLessThanOrEqual(tokens.count, 2)
        XCTAssertEqual(firstToken, tokens["CFDI"])
        XCTAssertEqual(secondToken, tokens["CFDI"])
    }
    
    func testGetRetenToken() async throws {
        let token = try await AuthenticationManager.shared.getToken(isRetention: true)
        let tokens = AuthenticationManager.shared.getTokens()
        XCTAssert(tokens.count > 0)
        XCTAssertEqual(token, tokens["Retencion"])
    }
    
    func testGetRetenMultipleToken() async throws {
        let firstToken = try await AuthenticationManager.shared.getToken(isRetention: true)
        let secondToken = try await AuthenticationManager.shared.getToken(isRetention: true)
        XCTAssertEqual(firstToken, secondToken)
        let tokens = AuthenticationManager.shared.getTokens()
        XCTAssertGreaterThan(tokens.count, 0)
        XCTAssertLessThanOrEqual(tokens.count, 2)
        XCTAssertEqual(firstToken, tokens["Retencion"])
        XCTAssertEqual(secondToken, tokens["Retencion"])
    }
    
    func testRefreshCFDIToken() async throws {
        let firstToken = try await AuthenticationManager.shared.getToken()
        sleep(300)
        let secondToken = try await AuthenticationManager.shared.getToken()
        XCTAssertNotEqual(firstToken, secondToken)
    }
    
    func testRefreshRetentionToken() async throws {
        let firstToken = try await AuthenticationManager.shared.getToken(isRetention: true)
        sleep(300)
        let secondToken = try await AuthenticationManager.shared.getToken(isRetention: true)
        XCTAssertNotEqual(firstToken, secondToken)
    }

}
