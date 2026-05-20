//
//  CertUtils.swift
//  Fidadces
//
//  Created by Pedro Ivan Salas Peña on 06/05/24.
//

import CryptoKit
import Foundation

extension Data {
  var hexString: String {
    self.map { String(format: "%02x", $0) }.joined()
  }
}

struct CertUtilsError: Error, Equatable {
  private enum Code {
    case invalidDate
    case invalidPrivateKey
    case noIdentity
  }

  private let code: Code

  static var invalidDate: Self { .init(code: .invalidDate) }

  static var invalidPrivateKey: Self { .init(code: .invalidPrivateKey) }

  static var noIdentity: Self { .init(code: .noIdentity) }

  var localizedDescription: String {
    switch code {
    case .invalidDate:
      return "Current date is out of the valid period of the certificate"
    case .invalidPrivateKey:
      return "The private key doesn't match with the certificate"
    case .noIdentity:
      return "No certificate or private key in Keychain"
    }
  }
}

/// Utility methods for your **e.firma**.
public struct CertUtils {
  private let certificate: SecCertificate
  private let key: SecKey
  private let cryptoService: Cryptobable

  /// Creates an utils instance with the provided information (RFC, Full name), it will look for the appropiate certificate and private key in the Keychain.
  ///
  ///
  /// - Parameters:
  ///   - rfc: the subject unique identifier of the **e.firma**
  ///   - fullName: the full name of the **e.firma**
  ///
  /// - Throws: `noIdentity` error if the certificate or private key are not in the Keychain
  public init(rfc: String, fullName: String) async throws {
    let service = CryptoService()
    guard
      let (certificate, key) = await service.getIdentity(
        for: rfc,
        commonName: fullName
      )
    else {
      throw CertUtilsError.noIdentity
    }

    self.certificate = certificate
    self.key = key
    self.cryptoService = service
  }

  /// Creates an utils instance with the provided **e.firma** data (Certificate, Private key).
  ///
  /// The certificate can be converter to the require file using the terminal with the following command
  /// ```bash
  /// openssl x509 -in /path/to/yourcertificate.cer -outform DER -out certificate.cer
  /// ```
  ///
  /// The resulting certificate and private key will be store in the Keychain
  ///
  /// - Parameters:
  ///   - certData: the certificate data of your **e.firma** in DER format.
  ///   - keyData: the private key data of your **e.firma** in pkcs8 format with a password
  /// - Throws: `certificateCreationFailed` error if the certificate is in the wrong format or an `errSecKey...` error from the [Security Framework Result Codes](https://developer.apple.com/documentation/security/security-framework-result-codes)  if the private key has an issue
  public init(certData: Data, keyData: Data) async throws {
    try await self.init(
      certData: certData,
      keyData: keyData,
      service: CryptoService()
    )
  }

  init(certData: Data, keyData: Data, service: Cryptobable = CryptoService())
    async throws
  {

    let certificate = try service.createCertificate(with: certData)

    guard try service.checkPeriodValidity(of: certificate) else {
      throw CertUtilsError.invalidDate
    }

    // Importing the private key using SecItemImport as the key is password protected
    let key = try service.createPrivateKey(with: keyData)

    guard try service.testMatching(certificate: certificate, key: key) else {
      throw CertUtilsError.invalidPrivateKey
    }

    try await service.addToKeychain(certificate, key)

    self.certificate = certificate
    self.key = key
    self.cryptoService = service
  }

  /// Returns the issuer name of the certificate.
  /// - Returns: the issuer name of the certificate.
  /// - Throws: an  error from the [Security Framework Result Codes](https://developer.apple.com/documentation/security/security-framework-result-codes)  if the there is something wrong with the certificate
  public func getIssuerName() throws -> String {
    try cryptoService.getIssuerName(from: certificate)
  }

  /// Returns the hexString of the serial number of the certificate
  /// - Returns: the hexString of the serial number of the certificate
  /// - Throws: an  error from the [Security Framework Result Codes](https://developer.apple.com/documentation/security/security-framework-result-codes)  if the there is something wrong with the certificate
  public func getSerialNumber() throws -> String {
    try cryptoService.getSerialNumber(from: certificate)
  }

  /// Returns the subject unique identifier name of the certificate
  ///
  /// For the **e.firma** the subject unique identifier is the RFC
  ///
  /// - Returns: the subject unique identifier name of the certificate
  public func getSubjectUniqueIdentifier() throws -> String {
    try cryptoService.getSubjectUniqueIdentifier(from: certificate)
  }

  /// Returns the common name of the certificate
  ///
  /// For the **e.firma** the common name is the full name
  ///
  /// - Returns: the common name of the certificate
  public func getCommonName() throws -> String {
    try cryptoService.getCommonName(from: certificate)
  }

  /// Creates the signature of the information using the private key
  /// - Parameter info: the information that has to be signed with the private key
  /// - Returns: the [base64EncodedString](https://developer.apple.com/documentation/foundation/data/base64encodedstring(options:)) of the signature of the information using the private key
  /// - Throws: an `notSupportedAlgorithm` error if the private key does not support RSA-SHA1 signature for messages
  public func createSignature(for info: Data) throws -> String {
    try cryptoService.createSignature(with: key, data: info)
  }

  /// Returns the [base64EncodedString](https://developer.apple.com/documentation/foundation/data/base64encodedstring(options:)) SHA1 hash of the data provided
  /// - Parameter data: the data information that needs to be hashed
  /// - Returns: the [base64EncodedString](https://developer.apple.com/documentation/foundation/data/base64encodedstring(options:)) SHA1 hash of the data provided
  public func getSHA1Hash(for data: Data) -> String {
    cryptoService.getSHA1Hash(for: data)
  }

  /// Returns the [base64EncodedString](https://developer.apple.com/documentation/foundation/data/base64encodedstring(options:)) of the certData
  /// - Returns: the [base64EncodedString](https://developer.apple.com/documentation/foundation/data/base64encodedstring(options:)) of the certData
  public func getBase64StringCert() -> String {
    cryptoService.getBase64String(of: certificate)
  }

}
