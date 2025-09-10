//
//  VerificationTest.swift
//  DescargaMasivaKitTests
//
//  Created by Pedro Ivan Salas Peña on 03/09/25.
//

import XCTest
@testable import DescargaMasivaSATKit

final class VerificationTest: XCTestCase {
    
    override func setUpWithError() throws {
        if let certUrl = Bundle(for: VerificationTest.self).url(forResource: "certificate", withExtension: "cer"), let keyURL = Bundle(for: VerificationTest.self).url(forResource: "privkey", withExtension: "key") {
            let certData = try Data(contentsOf: certUrl)
            let keyData = try Data(contentsOf: keyURL)
            try AuthenticationManager.shared.add(certData: certData, keyData: keyData)
        }
    }

    func testCertDataInit() throws {
        let verification = VerificationEndpoint(queryId: "e3e2636f-c008-405b-a36c-205baabd9297")
        XCTAssertNotNil(verification)
    }
    
    func testRequest() async throws {
        let verification = VerificationEndpoint(queryId: "e3e2636f-c008-405b-a36c-205baabd9297")
        let (result, contents) = try await verification.request()
        XCTAssert(result.count > 0)
        if let contents {
            XCTAssert(contents.count > 0)
        }
    }

}
