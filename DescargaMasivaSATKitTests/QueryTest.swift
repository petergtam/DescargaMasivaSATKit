//
//  QueryTest.swift
//  DescargaMasivaKit
//
//  Created by Pedro Ivan Salas Peña on 02/09/25.
//

import XCTest
@testable import DescargaMasivaSATKit

final class QueryTest: XCTestCase {
    var params: InvoiceParams = InvoiceParams()
    
    override func setUpWithError() throws {
        if let certUrl = Bundle(for: QueryTest.self).url(forResource: "certificate", withExtension: "cer"), let keyURL = Bundle(for: QueryTest.self).url(forResource: "privkey", withExtension: "key") {
            let certData = try Data(contentsOf: certUrl)
            let keyData = try Data(contentsOf: keyURL)
            try AuthenticationManager.shared.add(certData: certData, keyData: keyData)
        }
    }
    
    func testInit() throws {
        var params = InvoiceParams()
        params.receiptStatus = .vigente
        params.operation = .emitidas
        params.endPoint = .facturas
        params.queryType = .metadata
        let request = QueryEndpoint(params: params)
        XCTAssertNotNil(request)
    }
    
    func testRequest() async throws {
            params.queryType = .metadata
            params.receiptStatus = .vigente
            params.operation = .recibidas
            params.endPoint = .facturas
            let request = QueryEndpoint(params: params)
            let result = try await request.request()
            XCTAssert(result.count > 0)
    }

}
