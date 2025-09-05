//
//  Utils.swift
//  DescargaMasivaKit
//
//  Created by Pedro Ivan Salas Peña on 02/09/25.
//

import XCTest
@testable import DescargaMasivaSATKit

final class CertUtilsTest: XCTestCase {
    
    var certUtils: CertUtils?
    
    override func setUpWithError() throws {
        if let certUrl = Bundle(for: CertUtilsTest.self).url(forResource: "certificate", withExtension: ".cer"), let keyUrl = Bundle(for: CertUtilsTest.self).url(forResource: "privkey", withExtension: ".key") {
            let certData = try Data(contentsOf: certUrl)
            let keyData = try Data(contentsOf: keyUrl)
            certUtils = try CertUtils(certData: certData, keyData: keyData)
        }
    }
    
    func testCertError() throws {
        if let certUrl = Bundle(for: CertUtilsTest.self).url(forResource: "certificate", withExtension: ".pem"), let keyUrl = Bundle(for: CertUtilsTest.self).url(forResource: "privkey", withExtension: ".key") {
            let certData = try Data(contentsOf: certUrl)
            let keyData = try Data(contentsOf: keyUrl)
            XCTAssertThrowsError(try CertUtils(certData: certData, keyData: keyData))
        }
    }
    
    func testKeyError() throws {
        if let certUrl = Bundle(for: CertUtilsTest.self).url(forResource: "certificate", withExtension: ".cer"), let keyUrl = Bundle(for: CertUtilsTest.self).url(forResource: "privkey", withExtension: ".pem") {
            let certData = try Data(contentsOf: certUrl)
            let keyData = try Data(contentsOf: keyUrl)
            XCTAssertThrowsError(try CertUtils(certData: certData, keyData: keyData))
        }
    }

    func testInit() throws {
        if let certUrl = Bundle(for: CertUtilsTest.self).url(forResource: "certificate", withExtension: ".cer"), let keyUrl = Bundle(for: CertUtilsTest.self).url(forResource: "privkey", withExtension: ".key") {
            let certData = try Data(contentsOf: certUrl)
            let keyData = try Data(contentsOf: keyUrl)
            let certutils = try CertUtils(certData: certData, keyData: keyData)
            XCTAssertNotNil(certutils)
        }
    }
    
    func testGetIssuerName() throws {
        if let certUtils {
            let issuerName = try certUtils.getIssuerName()
            XCTAssertEqual(issuerName, "CN=AC UAT, O=SERVICIO DE ADMINISTRACION TRIBUTARIA, OU=SAT-IES Authority, E=oscar.martinez@sat.gob.mx, STREET=3ra cerrada de caliz, PostalCode=06370, C=MX, S=CIUDAD DE MEXICO, L=COYOACAN, OID.2.5.4.45=2.5.4.45, OID.1.2.840.113549.1.9.2=responsable: ACDMA-SAT")
        }
    }
    
    func testGetSerialNumber() throws {
        if let certUtils {
            let serialNumber = try certUtils.getSerialNumber()
            XCTAssertEqual(serialNumber, "3330303031303030303030353030303033323939")
        }
    }
    
    func testGetRFC() throws {
        if let certUtils {
            let rfc = try certUtils.getRFC()
            XCTAssertEqual(rfc, "WERX631016S30")
        }
    }
    
    func testGetCert() {
        if let certUtils {
            let certData = certUtils.getCert()
            XCTAssertEqual(certData,"MIIFwjCCA6qgAwIBAgIUMzAwMDEwMDAwMDA1MDAwMDMyOTkwDQYJKoZIhvcNAQELBQAwggErMQ8wDQYDVQQDDAZBQyBVQVQxLjAsBgNVBAoMJVNFUlZJQ0lPIERFIEFETUlOSVNUUkFDSU9OIFRSSUJVVEFSSUExGjAYBgNVBAsMEVNBVC1JRVMgQXV0aG9yaXR5MSgwJgYJKoZIhvcNAQkBFhlvc2Nhci5tYXJ0aW5lekBzYXQuZ29iLm14MR0wGwYDVQQJDBQzcmEgY2VycmFkYSBkZSBjYWxpejEOMAwGA1UEEQwFMDYzNzAxCzAJBgNVBAYTAk1YMRkwFwYDVQQIDBBDSVVEQUQgREUgTUVYSUNPMREwDwYDVQQHDAhDT1lPQUNBTjERMA8GA1UELRMIMi41LjQuNDUxJTAjBgkqhkiG9w0BCQITFnJlc3BvbnNhYmxlOiBBQ0RNQS1TQVQwHhcNMjMwNTA5MTg0MTQ2WhcNMjcwNTA4MTg0MTQ2WjCBtzEYMBYGA1UEAxMPWEFJTUUgV0VJUiBST0pPMRgwFgYDVQQpEw9YQUlNRSBXRUlSIFJPSk8xGDAWBgNVBAoTD1hBSU1FIFdFSVIgUk9KTzELMAkGA1UEBhMCTVgxJTAjBgkqhkiG9w0BCQEWFnBydWViYXNAcHJ1ZWJhcy5nb2IubXgxFjAUBgNVBC0TDVdFUlg2MzEwMTZTMzAxGzAZBgNVBAUTEldFUlg2MzEwMTZISkNSSk0wODCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANQ6usxEBIGi1fPryfKMR3guOUBJ1QTBeZMPia9iPX2AuD3Geg2Pa9pBU5Vt+9Ko97aDr29ZU7ALinHEHBmvqkJ9uEToV8NIGR20D7bw1y/t9CgA+vAzTATpptwja4miEhkD+faGpWuspd8uTwL50WNK5ht8Gx1g93EtG3MXdD7hYwoXW3Pnry91Ev4nV0GYvyEwlaiexH6KbnGQToUtbuTmuo+fEZIaEVx7AyI5Ze95EAqsq/mz3iVrN9TL9xWdcIKd/kmpF6ypEkZq+ruaujFsQLJyKz1NgE52LpiHqz/IcH31z8atj9/Q7GV4TL8A/CucQGRNj6uEfxUELjtJiP8CAwEAAaNPME0wDAYDVR0TAQH/BAIwADALBgNVHQ8EBAMCA9gwEQYJYIZIAYb4QgEBBAQDAgWgMB0GA1UdJQQWMBQGCCsGAQUFBwMEBggrBgEFBQcDAjANBgkqhkiG9w0BAQsFAAOCAgEAKmfSG6k/EfhyCcFHIzinWfxf+fdA7XJZHCMxwHpapxFNSk9dR5GMp0KElMyeUGthNBv2gD269Mt8bz5+k61jnyd7NYQ39WbKIDw18j8hv1kEEvkR/oZMoZe3cTJk8tDPLSQ9fxIrjg2bC+Xbu5JW1Q7Bij9Hefg4aw0FrLToSKSDWB2vkxozepUZohddHTmzne/v8yA2Ux9zI0TP/JajtdIy6I3+iNlWRaFnBaqqjrtyaZ7s3FNT4F9NbN91IYr7Za2sc0zqO73v0eZ4/f3wlJ2UcSJm/A5yjnlY/oQ6OPkJHCUBnxT1CtDBrSEAcE99oM8C5nc8wRE0PgKTX0mmE8Vq7yR2GGxeyaMw1QjWeJW5atHvq+jf5F3URmyQvUjNAPehih/vHz18mGYjzxxDZT2dPGcTjQu/LTreXKIafUSxMgoc0hf2pGfxwwCHMp3vzhvDvGEgiVPmv7MNCpXXiKeV1EBe0zPjBUaES5/MPlhaa3Th8SHSS7l7C8+7+pZXQAToo9G6BFTAmt6cGa6aaDPgMDMd3A/ZkSAheM3PCKXuyK/HrbgV+awNP86eWNIIFv7JuhWDBUOgFAP6I24holxFFixK0lvtj+vl3jx/IutgXOCEOJiZ8GRWHI8QJwkjO5F6QSoxKAWxHE5ccdecZrBd3XOoTyK873ssjuofLk0=")
        }
    }
    
    func testDigestValue() {
        if let certUtils, let data = "Testing Digest Value".data(using: .utf8) {
            let digest = certUtils.getDigestValue(for: data)
            XCTAssertEqual(digest, "Tal/hq7AmAOZg4rRhz0x0ZJw4E4=")
        }
    }
    
    func testSignatureValue() throws {
        if let certUtils, let data = "Testing Signature Value".data(using: .utf8) {
            let signature = try certUtils.sign(with: data).base64EncodedString()
            XCTAssertEqual(signature, "LXITeTCS72bZdJ5hQiL1uOwPBhbSIIJbe01Le8ITpDFshn/YSe+Y7C8sqf1bW9rYeVR+ikxg7zAXs7Rtyz0jwt5lfVHIE1JW7gGU4J5m61cs0xGHPjFBINNagWZN2GnKt0kD+JbpMea9lFCLZ7m2HFltcNCdUUGTcbAnuzpfAXyw/LTXkHpQbnXOqtvyGhqKhTPS+jMtmnJVmcbJasJ7ZACcIEIKyv4blB8qGPAdq12QpmQ6pyBxxpXeTfBSqbdLfSvZ1bTniDHKSWq9NyTsc32EyfnFXXZWgeBZ0i5Kzl1IDnycY2imut145AcpJi19kUmbWgNhklBpTn2pepQ16A==")
        }
    }

}
