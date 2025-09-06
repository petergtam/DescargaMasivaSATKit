//
//  DownloadTest.swift
//  DescargaMasivaKitTests
//
//  Created by Pedro Ivan Salas Peña on 04/09/25.
//

import XCTest
@testable import DescargaMasivaSATKit

final class DownloadTest: XCTestCase {

    override func setUpWithError() throws {
        if let certUrl = Bundle(for: DownloadTest.self).url(forResource: "certificate", withExtension: "cer"), let keyURL = Bundle(for: DownloadTest.self).url(forResource: "privkey", withExtension: "key") {
            let certData = try Data(contentsOf: certUrl)
            let keyData = try Data(contentsOf: keyURL)
            try AuthenticationManager.shared.add(certData: certData, keyData: keyData)
        }
    }
    
    func testInit() {
        let download = DownloadEndpoint(packageId: "e3e2636f-c008-405b-a36c-205baabd9297")
        XCTAssertNotNil(download)
    }
    
    func testRequest() async throws {
        let download = DownloadEndpoint(packageId: "e3e2636f-c008-405b-a36c-205baabd9297")
        let (result,contents) = try await download.request()
        XCTAssert(result.count > 0)
        if let contents {
            XCTAssert(contents.count > 0)
        }
    }

}
