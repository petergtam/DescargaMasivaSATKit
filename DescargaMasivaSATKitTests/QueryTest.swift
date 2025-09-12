//
//  QueryTest.swift
//  DescargaMasivaKit
//
//  Created by Pedro Ivan Salas Peña on 02/09/25.
//

import XCTest
@testable import DescargaMasivaSATKit

class StubQuerySharedSession: SharedSession {
    enum Statuses: String {
        case malformedXML
        case accepted
        case invalidCert
        case invoiceNotFound
        case notControlled
        case exhausted
    }

    let xmlResponses: [Statuses: String] = [
        .malformedXML: #"<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><SolicitaDescargaEmitidosResponse xmlns="http://DescargaMasivaTerceros.sat.gob.mx"><SolicitaDescargaEmitidosResult CodEstatus="301" Mensaje="XML Mal Formado:La solicitud de descarga no es válida. La fecha inicial es mayor o igual a la fecha final."/></SolicitaDescargaEmitidosResponse></s:Body></s:Envelope>"#,
        .accepted:#"<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><SolicitaDescargaRecibidosResponse xmlns="http://DescargaMasivaTerceros.sat.gob.mx"><SolicitaDescargaRecibidosResult IdSolicitud="8b15cb57-85a4-4ef3-8797-805de260c6bb" RfcSolicitante="XAXX010101000" CodEstatus="5000" Mensaje="Solicitud Aceptada"/></SolicitaDescargaRecibidosResponse></s:Body></s:Envelope>"#,
        .invalidCert: #"<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><SolicitaDescargaRecibidosResponse xmlns="http://DescargaMasivaTerceros.sat.gob.mx"><SolicitaDescargaRecibidosResult CodEstatus="305" Mensaje="Certificado Inválido"/></SolicitaDescargaRecibidosResponse></s:Body></s:Envelope>"#,
        .invoiceNotFound: #"<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><SolicitaDescargaFolioResponse xmlns="http://DescargaMasivaTerceros.sat.gob.mx"><SolicitaDescargaFolioResult IdSolicitud="15296bd9-29b1-4f5c-8f26-92d8dbbad926" RfcSolicitante="XAXX010101000" CodEstatus="5004" Mensaje="No se encontro la informacion"/></SolicitaDescargaFolioResponse></s:Body></s:Envelope>"#,
        .notControlled: #"<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><SolicitaDescargaFolioResponse xmlns="http://DescargaMasivaTerceros.sat.gob.mx"><SolicitaDescargaFolioResult IdSolicitud="f29e8844-9752-4380-962d-1ac71b5e2119" CodEstatus="404" Mensaje="Error no controlado."/></SolicitaDescargaFolioResponse></s:Body></s:Envelope>"#,
        .exhausted: #"<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><SolicitaDescargaFolioResponse xmlns="http://DescargaMasivaTerceros.sat.gob.mx"><SolicitaDescargaFolioResult IdSolicitud="238aba5a-cd61-43f5-9562-b5c92be9a51d" RfcSolicitante="XAXX010101000" CodEstatus="5002" Mensaje="Se han agotado las solicitudes de por vida"/></SolicitaDescargaFolioResponse></s:Body></s:Envelope>"#
    ]
    
    var response: Statuses = .accepted
    var statusCode = 200
    func data(for: URLRequest) async throws -> (Data, URLResponse) {
        let xml = xmlResponses[response]!
        let data = xml.data(using: .utf8)!
        let urlResponse = HTTPURLResponse(url: URL(string:"https://cfdidescargamasivasolicitud.clouda.sat.gob.mx/SolicitaDescargaService.svc")!, statusCode: statusCode, httpVersion: "1.1",  headerFields: ["Content-Encoding": "gzip","Content-Length": "357", "Content-Type": "text/xml; charset=utf-8", "Date": "Thu, 11 Sep 2025 05:29:59 GMT", "Server": "Microsoft-IIS/10.0", "Strict-Transport-Security": "max-age=31536000; includeSubDomains", "Vary": "Accept-Encoding", "x-content-type-options": "nosniff", "x-frame-options": "SAMEORIGIN", "x-xss-protection": "1"])!
        return (data, urlResponse as URLResponse)
    }
}

final class QueryTest: XCTestCase {
    var params: InvoiceParams = InvoiceParams()
    let sharedSession = StubQuerySharedSession()
    
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
    
    func testMalformedRequest() async throws {
        sharedSession.response = .malformedXML
        params.operation = .recibidas
        params.queryType = .metadata
        params.receiptStatus = .vigente
        params.endPoint = .facturas
        let request = QueryEndpoint(params: params)
        let result = try await request.request(sharedSession)
        if let data = result.data(using: .utf8) {
            let obj = try JSONDecoder().decode(QueryResponse.self, from: data)
            XCTAssertNotNil(obj.result)
            XCTAssertEqual(obj.result.CodEstatus, 301)
            XCTAssert(obj.result.Mensaje.starts(with: "XML Mal Formado:"))
        }
    }
    
    func testAcceptedRequest() async throws {
        sharedSession.response = .accepted
        params.operation = .emitidas
        params.queryType = .metadata
        params.receiptStatus = .vigente
        params.endPoint = .facturas
        let request = QueryEndpoint(params: params)
        let result = try await request.request(sharedSession)
        if let data = result.data(using: .utf8) {
            let obj = try JSONDecoder().decode(QueryResponse.self, from: data)
            XCTAssertNotNil(obj.result)
            XCTAssertNotEqual(obj.result.IdSolicitud, "")
            XCTAssertNotEqual(obj.result.RfcSolicitante, "")
            XCTAssertEqual(obj.result.CodEstatus, 5000)
            XCTAssertEqual(obj.result.Mensaje, "Solicitud Aceptada")
        }
    }
    
    func testInvalidCertRequest() async throws {
        sharedSession.response = .invalidCert
        params.operation = .emitidas
        params.queryType = .metadata
        params.receiptStatus = .vigente
        params.endPoint = .facturas
        let request = QueryEndpoint(params: params)
        let result = try await request.request(sharedSession)
        if let data = result.data(using: .utf8) {
            let obj = try JSONDecoder().decode(QueryResponse.self, from: data)
            XCTAssertNotNil(obj.result)
            XCTAssertEqual(obj.result.CodEstatus, 305)
            XCTAssertEqual(obj.result.Mensaje, "Certificado Inválido")
        }
    }
    
    func testPublicRequest() async throws {
        params.operation = .emitidas
        params.queryType = .metadata
        params.receiptStatus = .vigente
        params.endPoint = .facturas
        let request = QueryEndpoint(params: params)
        let result = try await request.request()
        if let data = result.data(using: .utf8) {
            let obj = try JSONDecoder().decode(QueryResponse.self, from: data)
            XCTAssertNotNil(obj.result)
            XCTAssertEqual(obj.result.CodEstatus, 305)
            XCTAssertEqual(obj.result.Mensaje, "Certificado Inválido")
        }
    }
    
    func testInvoiceNotFoundRequest() async throws {
        sharedSession.response = .invoiceNotFound
        params.operation = .recibidas
        params.queryType = .metadata
        params.invoiceId = "CD042CF1-2362-4A53-A9FB-5292EFD4B4FB"
        let request = QueryEndpoint(params: params)
        let result = try await request.request(sharedSession)
        if let data = result.data(using: .utf8) {
            let obj = try JSONDecoder().decode(QueryResponse.self, from: data)
            XCTAssertNotNil(obj.result)
            print(result)
            XCTAssertNotEqual(obj.result.IdSolicitud, "")
            XCTAssertNotEqual(obj.result.RfcSolicitante, "")
            XCTAssertEqual(obj.result.CodEstatus, 5004)
            XCTAssertEqual(obj.result.Mensaje, "No se encontro la informacion")
        }
    }
    
    func testNotControlledRequest() async throws {
        sharedSession.response = .notControlled
        params.operation = .emitidas
        params.queryType = .metadata
        params.receiptStatus = .vigente
        params.endPoint = .facturas
        let request = QueryEndpoint(params: params)
        let result = try await request.request(sharedSession)
        if let data = result.data(using: .utf8) {
            let obj = try JSONDecoder().decode(QueryResponse.self, from: data)
            XCTAssertNotNil(obj.result)
            XCTAssertNotEqual(obj.result.IdSolicitud, "")
            XCTAssertEqual(obj.result.CodEstatus, 404)
            XCTAssertEqual(obj.result.Mensaje, "Error no controlado.")
        }
    }
    
    func testExhaustedRequest() async throws {
        sharedSession.response = .exhausted
        params.operation = .emitidas
        params.queryType = .metadata
        params.receiptStatus = .vigente
        params.endPoint = .facturas
        let request = QueryEndpoint(params: params)
        let result = try await request.request(sharedSession)
        if let data = result.data(using: .utf8) {
            let obj = try JSONDecoder().decode(QueryResponse.self, from: data)
            XCTAssertNotNil(obj.result)
            XCTAssertNotEqual(obj.result.IdSolicitud, "")
            XCTAssertEqual(obj.result.CodEstatus, 5002)
            XCTAssertEqual(obj.result.Mensaje, "Se han agotado las solicitudes de por vida")
        }
    }
    
    func test404Request() async {
        sharedSession.statusCode = 404
        params.operation = .emitidas
        params.queryType = .metadata
        params.receiptStatus = .vigente
        params.endPoint = .facturas
        let request = QueryEndpoint(params: params)
        await XCTAssertThrowsErrorAsync(try await request.request(sharedSession), QueryEndpointResultError.httpError(statusCode: 404))
    }

}
