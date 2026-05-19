//
//  Utils.swift
//  DescargaMasivaKit
//
//  Created by Pedro Ivan Salas Peña on 02/09/25.
//

import XCTest

@testable import DescargaMasivaSATKit

struct CryptoServiceMock: Cryptobable {

  let accessGroup = "mx.com.yabd.KeychainItems"

  func createPrivateKey(with data: Data) throws -> SecKey {
    var parameters = SecItemImportExportKeyParameters(
      version: UInt32(SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION),
      flags: [],
      passphrase: Unmanaged.passUnretained("12345678a" as CFString),
      alertTitle: nil,
      alertPrompt: nil,
      accessRef: nil,
      keyUsage: nil,
      keyAttributes: nil
    )
    var format: SecExternalFormat = .formatWrappedPKCS8
    var type: SecExternalItemType = .itemTypePrivateKey
    var rawItems: CFArray?
    let status = SecItemImport(
      data as CFData,
      nil,
      &format,
      &type,
      SecItemImportExportFlags(rawValue: 0),
      &parameters,
      nil,
      &rawItems
    )

    guard status == errSecSuccess else {
      let message = SecCopyErrorMessageString(status, nil) as? String ?? ""

      if status == errSecUserCanceled {
        throw CryptoServiceError.userCanceled
      }

      if status == errSecInvalidData {
        throw CryptoServiceError.invalidPassword
      }

      if status == errSecUnknownFormat {
        throw CryptoServiceError.unkownKeyFormat
      }

      throw CryptoServiceError.unhandledError(message: message)
    }

    let items = rawItems as! [SecKeychainItem]
    for item in items {
      let itemType = CFGetTypeID(item as CFTypeRef)

      if itemType == SecKeyGetTypeID() {
        return (item as! SecKey)
      }
    }

    throw CryptoServiceError.keyCreationFailed
  }
}

final class CertUtilsTest: XCTestCase {

  func testCertError() async throws {
    if let certUrl = Bundle(for: CertUtilsTest.self).url(
      forResource: "certificate",
      withExtension: ".pem"
    ),
      let keyUrl = Bundle(for: CertUtilsTest.self).url(
        forResource: "privkey",
        withExtension: ".key"
      )
    {
      let certData = try Data(contentsOf: certUrl)
      let keyData = try Data(contentsOf: keyUrl)
      await XCTAssertThrowsErrorAsync(
        try await CertUtils(
          certData: certData,
          keyData: keyData,
          service: CryptoServiceMock()
        )
      )
    }
  }

  func testKeyError() async throws {
    if let certUrl = Bundle(for: CertUtilsTest.self).url(
      forResource: "certificate",
      withExtension: ".cer"
    ),
      let keyUrl = Bundle(for: CertUtilsTest.self).url(
        forResource: "privkeyError",
        withExtension: ".key"
      )
    {
      let certData = try Data(contentsOf: certUrl)
      let keyData = try Data(contentsOf: keyUrl)
      await XCTAssertThrowsErrorAsync(
        try await CertUtils(
          certData: certData,
          keyData: keyData,
          service: CryptoServiceMock()
        )
      )
    }
  }

  func testInitWitData() async throws {
    let certUrl = Bundle(for: CertUtilsTest.self).url(
      forResource: "certificate",
      withExtension: ".cer"
    )!
    let keyUrl = Bundle(for: CertUtilsTest.self).url(
      forResource: "privkey",
      withExtension: ".key"
    )!
    let certData = try Data(contentsOf: certUrl)
    let keyData = try Data(contentsOf: keyUrl)
    let certutils = try await CertUtils(
      certData: certData,
      keyData: keyData,
      service: CryptoServiceMock()
    )
    XCTAssertNotNil(certutils)
  }

  func testInitWithRFC() async throws {
    let certUrl = Bundle(for: CertUtilsTest.self).url(
      forResource: "certificate",
      withExtension: ".cer"
    )!
    let keyUrl = Bundle(for: CertUtilsTest.self).url(
      forResource: "privkey",
      withExtension: ".key"
    )!
    let certData = try Data(contentsOf: certUrl)
    let keyData = try Data(contentsOf: keyUrl)
    _ = try await CertUtils(
      certData: certData,
      keyData: keyData,
      service: CryptoServiceMock()
    )
    let certUtils = try await CertUtils(
      rfc: "WERX631016S30",
      fullName: "XAIME WEIR ROJO"
    )
    XCTAssertNotNil(certUtils)
  }

  func testInitWithRFCNoIdentity() async {
    let cryptoService = CryptoService()
    if let privateKey = await cryptoService.getPrivateKey(for: "WERX631016S30") {
      let status = await cryptoService.removeItem(for: privateKey)
      if status != errSecSuccess {
        print(SecCopyErrorMessageString(status, nil) ?? "")
      }
    }

    if let certificate = await cryptoService.getCertificate(
      for: "XAIME WEIR ROJO"
    ) {
      let status = await cryptoService.removeItem(for: certificate)
      if status != errSecSuccess {
        print(SecCopyErrorMessageString(status, nil) ?? "")
      }
    }

    await XCTAssertThrowsErrorAsync(
      try await CertUtils(
        rfc: "WERX631016S30",
        fullName: "XAIME WEIR ROJO",
      )
    )
  }

  func testRemoveKey() async {
    let cryptoService = CryptoService()
    if let key = await cryptoService.getPrivateKey(for: "WERX631016S30") {
      let status = await cryptoService.removeItem(for: key)
      guard status == errSecSuccess else {
        print(SecCopyErrorMessageString(status, nil) ?? "")
        return
      }
      let result = await cryptoService.getPrivateKey(for: "WERX631016S30")
      XCTAssertNil(result)
    }
  }

  func testGetIssuerName() async throws {
    let certUrl = Bundle(for: CertUtilsTest.self).url(
      forResource: "certificate",
      withExtension: ".cer"
    )!
    let keyUrl = Bundle(for: CertUtilsTest.self).url(
      forResource: "privkey",
      withExtension: ".key"
    )!
    let certData = try Data(contentsOf: certUrl)
    let keyData = try Data(contentsOf: keyUrl)
    let certUtils = try await CertUtils(
      certData: certData,
      keyData: keyData,
      service: CryptoServiceMock()
    )

    let issuerName = try certUtils.getIssuerName()
    XCTAssertEqual(
      issuerName,
      "CN=AC UAT, O=SERVICIO DE ADMINISTRACION TRIBUTARIA, OU=SAT-IES Authority, E=oscar.martinez@sat.gob.mx, STREET=3ra cerrada de caliz, PostalCode=06370, C=MX, S=CIUDAD DE MEXICO, L=COYOACAN, OID.2.5.4.45=2.5.4.45, OID.1.2.840.113549.1.9.2=responsable: ACDMA-SAT"
    )
  }

  func testGetSerialNumber() async throws {
    let certUrl = Bundle(for: CertUtilsTest.self).url(
      forResource: "certificate",
      withExtension: ".cer"
    )!
    let keyUrl = Bundle(for: CertUtilsTest.self).url(
      forResource: "privkey",
      withExtension: ".key"
    )!
    let certData = try Data(contentsOf: certUrl)
    let keyData = try Data(contentsOf: keyUrl)
    let certUtils = try await CertUtils(
      certData: certData,
      keyData: keyData,
      service: CryptoServiceMock()
    )
    let serialNumber = try certUtils.getSerialNumber()
    XCTAssertEqual(serialNumber, "3330303031303030303030353030303033323939")

  }

  func testGetRFC() async throws {
    let certUrl = Bundle(for: CertUtilsTest.self).url(
      forResource: "certificate",
      withExtension: ".cer"
    )!
    let keyUrl = Bundle(for: CertUtilsTest.self).url(
      forResource: "privkey",
      withExtension: ".key"
    )!
    let certData = try Data(contentsOf: certUrl)
    let keyData = try Data(contentsOf: keyUrl)
    let certUtils = try await CertUtils(
      certData: certData,
      keyData: keyData,
      service: CryptoServiceMock()
    )
    let rfc = try certUtils.getSubjectUniqueIdentifier()
    XCTAssertEqual(rfc, "WERX631016S30")

  }

  func testGetCert() async throws {
    let certUrl = Bundle(for: CertUtilsTest.self).url(
      forResource: "certificate",
      withExtension: ".cer"
    )!
    let keyUrl = Bundle(for: CertUtilsTest.self).url(
      forResource: "privkey",
      withExtension: ".key"
    )!
    let certData = try Data(contentsOf: certUrl)
    let keyData = try Data(contentsOf: keyUrl)
    let certUtils = try await CertUtils(
      certData: certData,
      keyData: keyData,
      service: CryptoServiceMock()
    )
    let expectedCertData = certUtils.getBase64StringCert()
    XCTAssertEqual(
      expectedCertData,
      certData.base64EncodedString()
    )
  }

  func testDigestValue() async throws {
    let certUrl = Bundle(for: CertUtilsTest.self).url(
      forResource: "certificate",
      withExtension: ".cer"
    )!
    let keyUrl = Bundle(for: CertUtilsTest.self).url(
      forResource: "privkey",
      withExtension: ".key"
    )!
    let certData = try Data(contentsOf: certUrl)
    let keyData = try Data(contentsOf: keyUrl)
    let certUtils = try await CertUtils(
      certData: certData,
      keyData: keyData,
      service: CryptoServiceMock()
    )
    let data = "Testing Digest Value".data(using: .utf8)!
    let digest = certUtils.getSHA1Hash(for: data)
    XCTAssertEqual(digest, "Tal/hq7AmAOZg4rRhz0x0ZJw4E4=")
  }

  func testSignatureValue() async throws {
    let certUrl = Bundle(for: CertUtilsTest.self).url(
      forResource: "certificate",
      withExtension: ".cer"
    )!
    let keyUrl = Bundle(for: CertUtilsTest.self).url(
      forResource: "privkey",
      withExtension: ".key"
    )!
    let certData = try Data(contentsOf: certUrl)
    let keyData = try Data(contentsOf: keyUrl)
    let certUtils = try await CertUtils(
      certData: certData,
      keyData: keyData,
      service: CryptoServiceMock()
    )
    let data = "Testing Signature Value".data(using: .utf8)!
    let signature = try certUtils.createSignature(for: data)
    XCTAssertEqual(
      signature,
      "LXITeTCS72bZdJ5hQiL1uOwPBhbSIIJbe01Le8ITpDFshn/YSe+Y7C8sqf1bW9rYeVR+ikxg7zAXs7Rtyz0jwt5lfVHIE1JW7gGU4J5m61cs0xGHPjFBINNagWZN2GnKt0kD+JbpMea9lFCLZ7m2HFltcNCdUUGTcbAnuzpfAXyw/LTXkHpQbnXOqtvyGhqKhTPS+jMtmnJVmcbJasJ7ZACcIEIKyv4blB8qGPAdq12QpmQ6pyBxxpXeTfBSqbdLfSvZ1bTniDHKSWq9NyTsc32EyfnFXXZWgeBZ0i5Kzl1IDnycY2imut145AcpJi19kUmbWgNhklBpTn2pepQ16A=="
    )
  }

}
