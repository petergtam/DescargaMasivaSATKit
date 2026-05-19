//
//  CryptoService.swift
//  DescargaMasivaSATKit
//
//  Created by Pedro Ivan Salas Peña on 16/05/26.
//

import CryptoKit
import Foundation

enum CryptoServiceError: Error, Equatable {
  case certificateCreationFailed
  case userCanceled
  case invalidPassword
  case unkownKeyFormat
  case unhandledError(message: String)
  case keyCreationFailed
  case noPublicKey
  case noIssuerName
  case noRFC
  case notSupportedAlgorithm
  case unableToAddItem(message: String)
  case unableToCreateIdentity(message: String)
}

protocol Cryptobable {

  var accessGroup: String { get }

  func getIdentity(for rfc: String, commonName: String) async -> (
    SecCertificate, SecKey
  )?
  func createPrivateKey(with: Data) throws -> SecKey
  func getIssuerName(from certificate: SecCertificate) throws -> String
  func getSerialNumber(from certificate: SecCertificate) throws -> String
  func getSubjectUniqueIdentifier(from certificate: SecCertificate) throws
    -> String
  func createSignature(with key: SecKey, data: Data) throws -> String
  func getSHA1Hash(for data: Data) -> String
  func createCertificate(with data: Data) throws -> SecCertificate
  func checkPeriodValidity(of certificate: SecCertificate) throws -> Bool
  func testMatching(certificate: SecCertificate, key: SecKey) throws -> Bool
  func addToKeychain(_ certificate: SecCertificate, _ key: SecKey) async throws

}

extension Cryptobable {

  private func searchPrivateKey(rfc: String) async -> SecKey? {
    await withCheckedContinuation { continuation in
      searchPrivateKey(rfc: rfc) { status, items in
        guard status == errSecSuccess else {
          let message = SecCopyErrorMessageString(status, nil)
          print(message ?? "")
          continuation.resume(returning: nil)
          return
        }
        let arrayResult = items as! [[String: Any]]
        for item in arrayResult {
          var isValid = false
          if let label = item[kSecAttrLabel as String] as? String,
            label.contains(rfc)
          {
            isValid = true
          }
          if !isValid {
            if let applicationTag = item[kSecAttrApplicationTag as String]
              as? String,
              applicationTag
                .contains(rfc)
            {
              isValid = true
            }
          }
          guard isValid else {
            continue
          }
          if let keyValue = item[kSecValueRef as String] {
            let key = keyValue as! SecKey
            continuation.resume(returning: key)
            return
          }
        }
        continuation.resume(returning: nil)
      }
    }
  }

  private func searchPrivateKey(
    rfc: String,
    completionHandler: @escaping (OSStatus, CFTypeRef?) -> Void
  ) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrAccessGroup as String: accessGroup,
      kSecAttrLabel as String: rfc,
      kSecAttrApplicationTag as String: "mx.com.yabd.DescargaMasivaKit.\(rfc)",
      kSecMatchLimit as String: kSecMatchLimitAll,
      kSecReturnAttributes as String: kCFBooleanTrue!,
      kSecReturnRef as String: kCFBooleanTrue!,
    ]
    DispatchQueue.global(qos: .background).asyncAndWait {
      var items: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &items)
      completionHandler(status, items)
    }
  }

  func getPrivateKey(for rfc: String) async -> SecKey? {
    await searchPrivateKey(rfc: rfc)
  }

  private func searchCertificate(commonName: String) async -> SecCertificate? {
    await withCheckedContinuation { continuation in
      searchCertificate(commonName: commonName) { status, items in
        guard status == errSecSuccess else {
          let message = SecCopyErrorMessageString(status, nil)
          print(message ?? "")
          continuation.resume(returning: nil)
          return
        }
        let arrayResult = items as! [[String: Any]]
        for item in arrayResult {
          guard let label = item[kSecAttrLabel as String] as? String,
            label == commonName
          else {
            continue
          }
          if let value = item[kSecValueRef as String] {
            let cert = value as! SecCertificate
            continuation.resume(returning: cert)
            return
          }
        }
        continuation.resume(returning: nil)
      }
    }
  }

  private func searchCertificate(
    commonName: String,
    completionHandler: @escaping (OSStatus, CFTypeRef?) -> Void
  ) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassCertificate,
      kSecAttrAccessGroup as String: accessGroup,
      kSecAttrLabel as String: commonName,
      kSecMatchLimit as String: kSecMatchLimitAll,
      kSecReturnAttributes as String: kCFBooleanTrue!,
      kSecReturnRef as String: kCFBooleanTrue!,
    ]
    DispatchQueue.global(qos: .background).async {
      var items: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &items)
      completionHandler(status, items)
    }
  }

  func getCertificate(for commonName: String) async -> SecCertificate? {
    await searchCertificate(commonName: commonName)
  }

  func getIdentity(for rfc: String, commonName: String) async -> (
    SecCertificate, SecKey
  )? {
    guard let key = await getPrivateKey(for: rfc) else {
      return nil
    }
    guard let certificate = await getCertificate(for: commonName) else {
      return nil
    }
    return (certificate, key)
  }

  func createPrivateKey(with data: Data) throws -> SecKey {
    var parameters = SecItemImportExportKeyParameters(
      version: UInt32(SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION),
      flags: .securePassphrase,
      passphrase: nil,
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

  private func getLabel(from oid: String) -> String {
    if oid == kSecOIDCommonName as String {
      return "CN"
    }
    if oid == kSecOIDOrganizationName as String {
      return "O"
    }
    if oid == kSecOIDOrganizationalUnitName as String {
      return "OU"
    }
    if oid == kSecOIDStreetAddress as String {
      return "STREET"
    }
    if oid == "2.5.4.17" {
      return "PostalCode"
    }
    if oid == kSecOIDCountryName as String {
      return "C"
    }
    if oid == kSecOIDStateProvinceName as String {
      return "S"
    }
    if oid == kSecOIDLocalityName as String {
      return "L"
    }
    if oid == kSecOIDEmailAddress as String {
      return "E"
    }

    return "OID.\(oid)"
  }

  func getIssuerName(from certificate: SecCertificate) throws -> String {
    var error: Unmanaged<CFError>?
    guard
      let dict = SecCertificateCopyValues(
        certificate,
        [kSecOIDX509V1IssuerName] as CFArray,
        &error
      )
    else {
      throw error!.takeRetainedValue() as Error
    }
    let nsdict = dict as NSDictionary
    if let issuerDict = nsdict[kSecOIDX509V1IssuerName] as? NSDictionary,
      let issuerArray = issuerDict[kSecPropertyKeyValue] as? [NSDictionary]
    {
      let pairs = issuerArray.map { element in
        if let label = element[kSecPropertyKeyLabel] as? String,
          let value = element[kSecPropertyKeyValue] as? String
        {
          return "\(getLabel(from: label))=\(value)"
        }
        return ""
      }
      return pairs.joined(separator: ", ")
    }

    throw CryptoServiceError.noIssuerName
  }

  func getSerialNumber(from certificate: SecCertificate) throws -> String {
    var error: Unmanaged<CFError>?

    guard
      let serialNumber = SecCertificateCopySerialNumberData(certificate, &error)
        as Data?
    else {
      throw error!.takeRetainedValue() as Error
    }

    return serialNumber.hexString
  }

  func getSubjectUniqueIdentifier(from certificate: SecCertificate) throws
    -> String
  {
    var error: Unmanaged<CFError>?
    guard
      let dict = SecCertificateCopyValues(
        certificate,
        [kSecOIDX509V1SubjectName] as CFArray,
        &error
      )
    else {
      throw error!.takeRetainedValue() as Error
    }

    let nsdict = dict as NSDictionary

    if let subjectDict = nsdict[kSecOIDX509V1SubjectName] as? NSDictionary,
      let subjectArray = subjectDict[kSecPropertyKeyValue] as? [NSDictionary]
    {
      for item in subjectArray {
        if let label = item[kSecPropertyKeyLabel] as? String,
          let value = item[kSecPropertyKeyValue] as? String,
          label == "2.5.4.45" as String
        {
          return value
        }
      }
    }

    throw CryptoServiceError.noRFC
  }

  func getCommonName(from certificate: SecCertificate) throws -> String {
    var commonName: CFString?
    let status = SecCertificateCopyCommonName(certificate, &commonName)
    guard status == errSecSuccess else {
      let message = SecCopyErrorMessageString(status, nil) as? String ?? ""
      throw CryptoServiceError.unhandledError(message: message)
    }

    return commonName! as String
  }

  func createSignature(with key: SecKey, data: Data) throws -> String {
    let algorithm: SecKeyAlgorithm = .rsaSignatureMessagePKCS1v15SHA1
    guard SecKeyIsAlgorithmSupported(key, .sign, algorithm) else {
      throw CryptoServiceError.notSupportedAlgorithm
    }
    var error: Unmanaged<CFError>?
    guard
      let signature = SecKeyCreateSignature(
        key,
        algorithm,
        data as CFData,
        &error
      ) as Data?
    else {
      throw error!.takeRetainedValue() as Error
    }
    return signature.base64EncodedString()
  }

  func getSHA1Hash(for data: Data) -> String {
    let digest = Insecure.SHA1.hash(data: data)
    return Data(digest).base64EncodedString()
  }

  func getBase64String(of certficate: SecCertificate) -> String {
    let certData = SecCertificateCopyData(certficate) as Data
    return certData.base64EncodedString()
  }

  func createCertificate(with data: Data) throws -> SecCertificate {
    guard
      let certificate = SecCertificateCreateWithData(nil, data as CFData)
    else {
      throw CryptoServiceError.certificateCreationFailed
    }

    return certificate
  }

  func checkPeriodValidity(of certificate: SecCertificate) throws -> Bool {
    var error: Unmanaged<CFError>?
    guard
      let certDict = SecCertificateCopyValues(
        certificate,
        [kSecOIDX509V1ValidityNotAfter, kSecOIDX509V1ValidityNotBefore]
          as CFArray,
        &error
      ) as? [String: [String: Any]]
    else {
      throw error!.takeRetainedValue() as Error
    }

    guard
      let notValidBeforeDict = certDict[
        kSecOIDX509V1ValidityNotBefore as String
      ],
      let notValidBeforeValue = notValidBeforeDict[
        kSecPropertyKeyValue as String
      ] as? TimeInterval,
      let notValidAfterDict = certDict[kSecOIDX509V1ValidityNotAfter as String],
      let notValidAfterValue = notValidAfterDict[kSecPropertyKeyValue as String]
        as? TimeInterval
    else {
      return false
    }

    let now = Date.timeIntervalSinceReferenceDate

    if now < notValidBeforeValue || now > notValidAfterValue {
      return false
    }

    return true
  }

  func testMatching(certificate: SecCertificate, key: SecKey) throws -> Bool {
    var error: Unmanaged<CFError>?
    guard
      let secKey = SecCertificateCopyKey(
        certificate
      ),
      let certPublicKeyData = SecKeyCopyExternalRepresentation(secKey, &error)
        as? Data
    else {
      if let error {
        throw error.takeRetainedValue() as Error
      }
      throw CryptoServiceError.noPublicKey
    }
    guard let secKey = SecKeyCopyPublicKey(key),
      let keyPublicKeyData =
        SecKeyCopyExternalRepresentation(secKey, &error) as? Data
    else {
      if let error {
        throw error.takeRetainedValue() as Error
      }
      throw CryptoServiceError.noPublicKey
    }

    return certPublicKeyData == keyPublicKeyData
  }

  func addToKeychain(_ certificate: SecCertificate, _ key: SecKey) async throws {
    let rfc = try getSubjectUniqueIdentifier(from: certificate)
    let commonName = try getCommonName(from: certificate)

    if await getIdentity(for: rfc, commonName: commonName) != nil {
      return
    }

    let addKeyQuery: [String: Any] = [
      kSecAttrAccessGroup as String: accessGroup,
      kSecClass as String: kSecClassKey,
      kSecAttrLabel as String: rfc,
      kSecAttrApplicationTag as String: "mx.com.yabd.DescargaMasivaKit.\(rfc)",
      kSecValueRef as String: key,
    ]

    let addKeyStatus = SecItemAdd(addKeyQuery as CFDictionary, nil)

    guard addKeyStatus == errSecSuccess || addKeyStatus == errSecDuplicateItem
    else {
      let message =
        SecCopyErrorMessageString(addKeyStatus, nil) as? String ?? ""
      throw CryptoServiceError.unableToAddItem(message: message)
    }

    let addCertificateQuery: [String: Any] = [
      kSecAttrAccessGroup as String: accessGroup,
      kSecClass as String: kSecClassCertificate,
      kSecValueRef as String: certificate,
      kSecAttrLabel as String: commonName,
    ]

    let addCertificateStatus = SecItemAdd(
      addCertificateQuery as CFDictionary,
      nil
    )

    guard
      addCertificateStatus == errSecSuccess
        || addCertificateStatus == errSecDuplicateItem
    else {
      let message =
        SecCopyErrorMessageString(addCertificateStatus, nil) as? String ?? ""
      throw CryptoServiceError.unableToAddItem(message: message)
    }

  }

}

struct CryptoService: Cryptobable {

  let accessGroup = "mx.com.yabd.KeychainItems"

  func removeItem(for key: SecKey) async -> OSStatus {
    await withCheckedContinuation { continuation in
      removeItem(for: key) { status in
        continuation.resume(returning: status)
      }
    }
  }

  func removeItem(
    for key: SecKey,
    completionHandler: @escaping (OSStatus) -> Void
  ) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrAccessGroup as String: accessGroup,
      kSecMatchItemList as String: [key] as CFArray,
    ]

    DispatchQueue.global(qos: .background).async {
      let result = SecItemDelete(query as CFDictionary)
      completionHandler(result)
    }
  }

  func removeItem(for certificate: SecCertificate) async -> OSStatus {
    await withCheckedContinuation { continuation in
      removeItem(for: certificate) { status in
        continuation.resume(returning: status)
      }
    }
  }

  func removeItem(
    for certificate: SecCertificate,
    completionHandler: @escaping (OSStatus) -> Void
  ) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassCertificate,
      kSecAttrAccessGroup as String: accessGroup,
      kSecMatchItemList as String: [certificate] as CFArray,
    ]

    DispatchQueue.global(qos: .background).async {
      let result = SecItemDelete(query as CFDictionary)
      completionHandler(result)
    }
  }

}
