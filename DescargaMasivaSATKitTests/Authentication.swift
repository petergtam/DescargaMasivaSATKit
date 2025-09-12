import XCTest
@testable import DescargaMasivaSATKit

struct StubAuthenticationSharedSession: SharedSession {
    
    enum Statuses: String {
        case cfdi
        case reten
        case cfdiRefresh
        case retenRefresh
    }

    let xmlResponses: [Statuses: String] = [
        .cfdi: #"<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" xmlns:u="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"><s:Header><o:Security s:mustUnderstand="1" xmlns:o="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><u:Timestamp u:Id="_0"><u:Created>2025-09-12T03:55:32.573Z</u:Created><u:Expires>2025-09-12T04:00:32.573Z</u:Expires></u:Timestamp></o:Security></s:Header><s:Body><AutenticaResponse xmlns="http://DescargaMasivaTerceros.gob.mx"><AutenticaResult>eyJhbGciOiJodHRwOi8vd3d3LnczLm9yZy8yMDAxLzA0L3htbGRzaWctbW9yZSNobWFjLXNoYTI1NiIsInR5cCI6IkpXVCJ9.eyJuYmYiOjE3NTc2NDkzMzIsImV4cCI6MTc1NzY0OTkzMiwiaWF0IjoxNzU3NjQ5MzMyLCJpc3MiOiJMb2FkU29saWNpdHVkRGVjYXJnYU1hc2l2YVRlcmNlcm9zIiwiYWN0b3J0IjoiMzMzMDMwMzAzMTMwMzAzMDMwMzAzMDM1MzAzMDMwMzAzMzMyMzkzOSJ9.G1PfX5Tgy1Ie1GPFswNKCFkPz9VNh31AEmr_qzzXzC4%26wrap_subject%3d3330303031303030303030353030303033323939</AutenticaResult></AutenticaResponse></s:Body></s:Envelope>"#,
        .cfdiRefresh: #"<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" xmlns:u="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"><s:Header><o:Security s:mustUnderstand="1" xmlns:o="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><u:Timestamp u:Id="_0"><u:Created>2025-09-12T04:00:32.861Z</u:Created><u:Expires>2025-09-12T04:05:32.861Z</u:Expires></u:Timestamp></o:Security></s:Header><s:Body><AutenticaResponse xmlns="http://DescargaMasivaTerceros.gob.mx"><AutenticaResult>eyJhbGciOiJodHRwOi8vd3d3LnczLm9yZy8yMDAxLzA0L3htbGRzaWctbW9yZSNobWFjLXNoYTI1NiIsInR5cCI6IkpXVCJ9.eyJuYmYiOjE3NTc2NDk2MzIsImV4cCI6MTc1NzY1MDIzMiwiaWF0IjoxNzU3NjQ5NjMyLCJpc3MiOiJMb2FkU29saWNpdHVkRGVjYXJnYU1hc2l2YVRlcmNlcm9zIiwiYWN0b3J0IjoiMzMzMDMwMzAzMTMwMzAzMDMwMzAzMDM1MzAzMDMwMzAzMzMyMzkzOSJ9.N94FFMZAoNXNg1kKLC-aClsNUzP68NpPQfXJWi3E4Gs%26wrap_subject%3d3330303031303030303030353030303033323939</AutenticaResult></AutenticaResponse></s:Body></s:Envelope>"#,
        .reten: #"<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" xmlns:u="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"><s:Header><o:Security s:mustUnderstand="1" xmlns:o="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><u:Timestamp u:Id="_0"><u:Created>2025-09-12T05:26:33.285Z</u:Created><u:Expires>2025-09-12T05:31:33.285Z</u:Expires></u:Timestamp></o:Security></s:Header><s:Body><AutenticaResponse xmlns="http://DescargaMasivaTerceros.gob.mx"><AutenticaResult>eyJhbGciOiJodHRwOi8vd3d3LnczLm9yZy8yMDAxLzA0L3htbGRzaWctbW9yZSNobWFjLXNoYTI1NiIsInR5cCI6IkpXVCJ9.eyJuYmYiOjE3NTc2NTQ3OTMsImV4cCI6MTc1NzY1NTM5MywiaWF0IjoxNzU3NjU0NzkzLCJpc3MiOiJMb2FkU2VydmljaW9EZWNhcmdhTWFzaXZhVGVyY2Vyb3NSZXQiLCJhY3RvcnQiOiIzMzMwMzAzMDMxMzAzMDMwMzAzMDMwMzUzMDMwMzAzMDMzMzIzOTM5In0.mezXGqesyzTSYcBlMmVnPfoRfygtB1zj7d80zJMUXqc%26wrap_subject%3d3330303031303030303030353030303033323939</AutenticaResult></AutenticaResponse></s:Body></s:Envelope>"#,
        .retenRefresh: #"<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" xmlns:u="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"><s:Header><o:Security s:mustUnderstand="1" xmlns:o="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"><u:Timestamp u:Id="_0"><u:Created>2025-09-12T05:31:43.677Z</u:Created><u:Expires>2025-09-12T05:36:43.677Z</u:Expires></u:Timestamp></o:Security></s:Header><s:Body><AutenticaResponse xmlns="http://DescargaMasivaTerceros.gob.mx"><AutenticaResult>eyJhbGciOiJodHRwOi8vd3d3LnczLm9yZy8yMDAxLzA0L3htbGRzaWctbW9yZSNobWFjLXNoYTI1NiIsInR5cCI6IkpXVCJ9.eyJuYmYiOjE3NTc2NTUxMDMsImV4cCI6MTc1NzY1NTcwMywiaWF0IjoxNzU3NjU1MTAzLCJpc3MiOiJMb2FkU2VydmljaW9EZWNhcmdhTWFzaXZhVGVyY2Vyb3NSZXQiLCJhY3RvcnQiOiIzMzMwMzAzMDMxMzAzMDMwMzAzMDMwMzUzMDMwMzAzMDMzMzIzOTM5In0.wTorH3fJ5s1_EsOXWIZv8QKb3ZfHfZScrKRDnFOTIwc%26wrap_subject%3d3330303031303030303030353030303033323939</AutenticaResult></AutenticaResponse></s:Body></s:Envelope>"#
        
    ]
    
    var response: Statuses = .cfdi
    var statusCode = 200
    var now: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime,.withFractionalSeconds]
        if response == .cfdi {
            return formatter.date(from: "2025-09-12T05:00:32.573Z")!
        }
        return formatter.date(from: "2025-09-12T06:31:33.285Z")!
    }
    func data(for: URLRequest) async throws -> (Data, URLResponse) {
        print("Using stub")
        let xml = xmlResponses[response]!
        let data = xml.data(using: .utf8)!
        let urlResponse = HTTPURLResponse(url: URL(string:"https://cfdidescargamasivasolicitud.clouda.sat.gob.mx/Autenticacion/Autenticacion.svc")!, statusCode: statusCode, httpVersion: "1.1",  headerFields: ["Content-Encoding": "gzip", "Content-Length": "801", "Content-Type": "text/xml; charset=utf-8", "Date": "Thu, 11 Sep 2025 05:29:59 GMT", "Server": "Microsoft-IIS/10.0", "Strict-Transport-Security": "max-age=31536000; includeSubDomains", "Vary": "Accept-Encoding", "x-content-type-options": "nosniff", "x-frame-options": "SAMEORIGIN", "x-xss-protection": "1"])!
        return (data, urlResponse as URLResponse)
    }
    
}

final class Authentication: XCTestCase {
    
    var sharedSession = StubAuthenticationSharedSession()
    
    override func setUp() async throws {
        AuthenticationManager.shared.reset()
    }
    
    func loadCertificates() throws {
        if let certUrl = Bundle(for: Authentication.self).url(forResource: "certificate", withExtension: ".cer"), let keyUrl = Bundle(for: Authentication.self).url(forResource: "privkey", withExtension: ".key") {
            let certData = try Data(contentsOf: certUrl)
            let keyData = try Data(contentsOf: keyUrl)
            try AuthenticationManager.shared.add(certData: certData, keyData: keyData)
        }
    }
    
    func testAddCerta() throws {
        XCTAssertThrowsError(try AuthenticationManager.shared.getCertUtils())
    }
    
    func testAddCertData() throws {
        if let certUrl = Bundle(for: Authentication.self).url(forResource: "certificate", withExtension: ".cer"), let keyUrl = Bundle(for: Authentication.self).url(forResource: "privkey", withExtension: ".key") {
            let certData = try Data(contentsOf: certUrl)
            let keyData = try Data(contentsOf: keyUrl)
            XCTAssertNoThrow(try AuthenticationManager.shared.add(certData: certData, keyData: keyData))
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
        sharedSession.response = .cfdi
        try loadCertificates()
        let token = try await AuthenticationManager.shared.getToken(sharedSession)
        let tokens = AuthenticationManager.shared.getTokens()
        XCTAssert(tokens.count > 0)
        XCTAssertEqual(token, tokens["CFDI"])
    }
    
    func testGetCFDIMultipleToken() async throws {
        sharedSession.response = .cfdi
        try loadCertificates()
        let firstToken = try await AuthenticationManager.shared.getToken(sharedSession)
        let secondToken = try await AuthenticationManager.shared.getToken(sharedSession)
        XCTAssertEqual(firstToken, secondToken)
        let tokens = AuthenticationManager.shared.getTokens()
        XCTAssertGreaterThan(tokens.count, 0)
        XCTAssertLessThanOrEqual(tokens.count, 2)
        XCTAssertEqual(firstToken, tokens["CFDI"])
        XCTAssertEqual(secondToken, tokens["CFDI"])
    }
    
    func testGetRetenToken() async throws {
        sharedSession.response = .reten
        try loadCertificates()
        let token = try await AuthenticationManager.shared.getToken(sharedSession,isRetention: true)
        let tokens = AuthenticationManager.shared.getTokens()
        XCTAssert(tokens.count > 0)
        XCTAssertEqual(token, tokens["Retencion"])
    }
    
    func testGetRetenMultipleToken() async throws {
        sharedSession.response = .reten
        try loadCertificates()
        let firstToken = try await AuthenticationManager.shared.getToken(sharedSession,isRetention: true)
        let secondToken = try await AuthenticationManager.shared.getToken(sharedSession,isRetention: true)
        XCTAssertEqual(firstToken, secondToken)
        let tokens = AuthenticationManager.shared.getTokens()
        XCTAssertGreaterThan(tokens.count, 0)
        XCTAssertLessThanOrEqual(tokens.count, 2)
        XCTAssertEqual(firstToken, tokens["Retencion"])
        XCTAssertEqual(secondToken, tokens["Retencion"])
    }
    
    func testRefreshCFDIToken() async throws {
        sharedSession.response = .cfdi
        try loadCertificates()
        let firstToken = try await AuthenticationManager.shared.getToken(sharedSession)
        sharedSession.response = .cfdiRefresh
        let secondToken = try await AuthenticationManager.shared.getToken(sharedSession, sharedSession.now)
        XCTAssertNotEqual(firstToken, secondToken)
    }
    
    func testRefreshRetentionToken() async throws {
        sharedSession.response = .reten
        try loadCertificates()
        let firstToken = try await AuthenticationManager.shared.getToken(sharedSession,isRetention: true)
        sharedSession.response = .retenRefresh
        let secondToken = try await AuthenticationManager.shared.getToken(sharedSession, sharedSession.now, isRetention: true)
        XCTAssertNotEqual(firstToken, secondToken)
    }

}
