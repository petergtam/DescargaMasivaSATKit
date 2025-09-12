//
//  VerificationTest.swift
//  DescargaMasivaKitTests
//
//  Created by Pedro Ivan Salas Peña on 03/09/25.
//

import XCTest
@testable import DescargaMasivaSATKit

func XCTAssertThrowsErrorAsync<T, R>(
    _ expression: @autoclosure () async throws -> T,
    _ errorThrown: @autoclosure () -> R,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) async where R: Equatable, R: Error  {
    do {
        let _ = try await expression()
        XCTFail(message(), file: file, line: line)
    } catch {
        XCTAssertEqual(error as? R, errorThrown())
    }
}

class StubVerificationSharedSession: SharedSession {
    enum Statuses: String {
        case accepted
        case invalidCert
        case completed
        case rejected
        case expired
    }

    let xmlResponses: [Statuses: String] = [
        .accepted:#"<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><VerificaSolicitudDescargaResponse xmlns="http://DescargaMasivaTerceros.sat.gob.mx"><VerificaSolicitudDescargaResult CodEstatus="5000" EstadoSolicitud="1" CodigoEstadoSolicitud="5000" NumeroCFDIs="0" Mensaje="Solicitud Aceptada"/></VerificaSolicitudDescargaResponse></s:Body></s:Envelope>"#,
        .invalidCert: #"<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><VerificaSolicitudDescargaResponse xmlns="http://DescargaMasivaTerceros.sat.gob.mx"><VerificaSolicitudDescargaResult CodEstatus="305" EstadoSolicitud="0" NumeroCFDIs="0" Mensaje="Certificado Inválido"/></VerificaSolicitudDescargaResponse></s:Body></s:Envelope>"#,
        .completed: #"<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><VerificaSolicitudDescargaResponse xmlns="http://DescargaMasivaTerceros.sat.gob.mx"><VerificaSolicitudDescargaResult CodEstatus="5000" EstadoSolicitud="3" CodigoEstadoSolicitud="5010" NumeroCFDIs="1" Mensaje="Solicitud Aceptada"><IdsPaquetes>E7092BEB-1EAC-4C32-B4FE-DDA5FE95A712_01</IdsPaquetes></VerificaSolicitudDescargaResult></VerificaSolicitudDescargaResponse></s:Body></s:Envelope>"#,
        .rejected: #"<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><VerificaSolicitudDescargaResponse xmlns="http://DescargaMasivaTerceros.sat.gob.mx"><VerificaSolicitudDescargaResult CodEstatus="5000" EstadoSolicitud="5" CodigoEstadoSolicitud="5004" NumeroCFDIs="0" Mensaje="Solicitud Aceptada"/></VerificaSolicitudDescargaResponse></s:Body></s:Envelope>"#,
        .expired: #"<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><VerificaSolicitudDescargaResponse xmlns="http://DescargaMasivaTerceros.sat.gob.mx"><VerificaSolicitudDescargaResult CodEstatus="5000" EstadoSolicitud="6" CodigoEstadoSolicitud="5000" NumeroCFDIs="0" Mensaje="Solicitud Aceptada"/></VerificaSolicitudDescargaResponse></s:Body></s:Envelope>"#
        
    ]
    
    var response: Statuses = .accepted
    var statusCode = 200
    func data(for: URLRequest) async throws -> (Data, URLResponse) {
        let xml = xmlResponses[response]!
        let data = xml.data(using: .utf8)!
        let urlResponse = HTTPURLResponse(url: URL(string:"https://cfdidescargamasivasolicitud.clouda.sat.gob.mx/VerificaSolicitudDescargaService.svc")!, statusCode: statusCode, httpVersion: "1.1",  headerFields: ["Content-Encoding": "gzip","Content-Length": "357", "Content-Type": "text/xml; charset=utf-8", "Date": "Thu, 11 Sep 2025 05:29:59 GMT", "Server": "Microsoft-IIS/10.0", "Strict-Transport-Security": "max-age=31536000; includeSubDomains", "Vary": "Accept-Encoding", "x-content-type-options": "nosniff", "x-frame-options": "SAMEORIGIN", "x-xss-protection": "1"])!
        return (data, urlResponse as URLResponse)
    }
}

final class VerificationTest: XCTestCase {
    
    let sharedSession = StubVerificationSharedSession()
    
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
    
    func testInvalidCertRequest() async throws {
        sharedSession.response = .invalidCert
        let verification = VerificationEndpoint(queryId: "e3e2636f-c008-405b-a36c-205baabd9297")
        let result = try await verification.request(sharedSession)
        if let data = result.data(using: .utf8) {
            let obj = try JSONDecoder().decode(VerificationResponse.self, from: data)
            XCTAssertNotNil(obj.result)
            XCTAssertEqual(obj.result.CodEstatus, 305)
            XCTAssertEqual(obj.result.Mensaje, "Certificado Inválido")
        }
    }
    
    func testPublicRequest() async throws {
        let verification = VerificationEndpoint(queryId: "e3e2636f-c008-405b-a36c-205baabd9297")
        let result = try await verification.request()
        if let data = result.data(using: .utf8) {
            let obj = try JSONDecoder().decode(VerificationResponse.self, from: data)
            XCTAssertNotNil(obj.result)
            XCTAssertEqual(obj.result.CodEstatus, 305)
            XCTAssertEqual(obj.result.Mensaje, "Certificado Inválido")
        }
    }
    
    func testAcceptedRequest() async throws {
        let verification = VerificationEndpoint(queryId: "e3e2636f-c008-405b-a36c-205baabd9297")
        let result = try await verification.request(sharedSession)
        if let data = result.data(using: .utf8) {
            let obj = try JSONDecoder().decode(VerificationResponse.self, from: data)
            XCTAssertNotNil(obj.result)
            XCTAssertEqual(obj.result.CodEstatus, 5000)
            XCTAssertEqual(obj.result.EstadoSolicitud, 1)
        }
    }
    
    func testCompletedRequest() async throws {
        sharedSession.response = .completed
        let verification = VerificationEndpoint(queryId: "03a57f63-de31-484c-b1ac-db9dc4e1c065")
        let result = try await verification.request(sharedSession)
        if let data = result.data(using: .utf8) {
            let obj = try JSONDecoder().decode(VerificationResponse.self, from: data)
            print(result)
            XCTAssertEqual(obj.contents?.count, obj.result.NumeroCFDIs)
            XCTAssertEqual(obj.result.CodEstatus,5000)
            XCTAssertEqual(obj.result.EstadoSolicitud, 3)
        }
    }
    
    func testRejectedRequest() async throws {
        sharedSession.response = .rejected
        let verification = VerificationEndpoint(queryId: "e3e2636f-c008-405b-a36c-205baabd9297")
        let result = try await verification.request(sharedSession)
        if let data = result.data(using: .utf8) {
            let obj = try JSONDecoder().decode(VerificationResponse.self, from: data)
            XCTAssertEqual(obj.result.CodEstatus,5000)
            XCTAssertEqual(obj.result.EstadoSolicitud, 5)
        }
    }
    
    func testExpiredRequest() async throws {
        sharedSession.response = .expired
        let verification = VerificationEndpoint(queryId: "e3e2636f-c008-405b-a36c-205baabd9297")
        let result = try await verification.request(sharedSession)
        if let data = result.data(using: .utf8) {
            let obj = try JSONDecoder().decode(VerificationResponse.self, from: data)
            XCTAssertEqual(obj.result.CodEstatus,5000)
            XCTAssertEqual(obj.result.EstadoSolicitud, 6)
        }
    }
    
    func test404Request() async {
        sharedSession.statusCode = 404
        let verification = VerificationEndpoint(queryId: "e3e2636f-c008-405b-a36c-205baabd9297")
        await XCTAssertThrowsErrorAsync(try await verification.request(sharedSession), VerificationEndpointResultError.httpError(statusCode: 404))
    }

}
