//
//  CertUtils.swift
//  Fidadces
//
//  Created by Pedro Ivan Salas Peña on 06/05/24.
//

import CryptoKit
import Foundation

extension Data {
    var hexString : String {
        self.map { String(format: "%02x", $0) }.joined()
    }
}

struct CertUtilsError: Error {
    private enum Code {
        case certificateCreationFailed
        case notSupportedAlgorithm
        case noRFC
        case noIssuerName
    }

    private let code: Code

    static var certificateCreationFailed: Self { .init(code: .certificateCreationFailed) }
    static var notSupportedAlgorithm: Self { .init(code: .notSupportedAlgorithm) }
    static var noRFC: Self { .init(code: .noRFC) }
    static var noIssuerName: Self { .init(code: .noIssuerName) }

    var localizedDescription: String {
        switch code {
        case .certificateCreationFailed:
            return "Certificate creation failed"
        case .notSupportedAlgorithm:
            return "Not supported algorithm"
        case .noRFC:
            return "No RFC"
        case .noIssuerName:
            return "No IssuerName"
        }
    }
}

/// Utility methods for your **e.firma**.
public struct CertUtils {
    private var certificate: SecCertificate
    private var key: SecKey

    /// Creates an utils instance with the provided **e.firma** data (Certificate, Private key).
    ///
    /// The certificate can be converter to the require file using the terminal with the following command
    /// ```bash
    /// openssl x509 -in /path/to/yourcertificate.cer -outformat DER -out certificate.key
    /// ```
    /// The private key can be converter to the require file using the terminal with the following command
    ///
    /// ```bash
    ///  openssl rsa -in /path/to/yourprivatekey.key -outformat DER -out privkey.key -traditional
    /// ```
    ///
    /// - Parameters:
    ///   - certData: the certificate data of your **e.firma** in DER format.
    ///   - keyData: the private key data of your **e.firma** in DER format without password.
    /// - Throws: `certificateCreationFailed` error if the certificate is in the wrong format or an `errSecKey...` error from the [Security Framework Result Codes](https://developer.apple.com/documentation/security/security-framework-result-codes)  if the private key has an issue
    public init(certData: Data, keyData: Data) throws {
        guard let certificate = SecCertificateCreateWithData(nil, certData as CFData) else {
            throw CertUtilsError.certificateCreationFailed
        }
        let options = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
        ] as CFDictionary
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(keyData as CFData,options,&error) else {
            throw error!.takeRetainedValue() as Error
        }
        self.certificate = certificate
        self.key = key
    }

    private func getLabel(from oid: String) -> String {
        if oid == "2.5.4.3" {
            return "CN"
        }
        if oid == "2.5.4.10" {
            return "O"
        }
        if oid == "2.5.4.11" {
            return "OU"
        }
        if oid == "2.5.4.9" {
            return "STREET"
        }
        if oid == "2.5.4.17" {
            return "PostalCode"
        }
        if oid == "2.5.4.6" {
            return "C"
        }
        if oid == "2.5.4.8" {
            return "S"
        }
        if oid == "2.5.4.7" {
            return "L"
        }
        if oid == "1.2.840.113549.1.9.1" {
            return "E"
        }

        return "OID.\(oid)"
    }

    /// Returns the issuer name of the certificate.
    /// - Returns: the issuer name of the certificate.
    /// - Throws: an  error from the [Security Framework Result Codes](https://developer.apple.com/documentation/security/security-framework-result-codes)  if the there is something wrong with the certificate
    public func getIssuerName() throws -> String {
        var error: Unmanaged<CFError>?
        guard let dict = SecCertificateCopyValues(certificate, [kSecOIDX509V1IssuerName] as CFArray, &error)
        else {
            throw error!.takeRetainedValue() as Error
        }
        let nsdict = dict as NSDictionary
        if let issuerDict = nsdict[kSecOIDX509V1IssuerName] as? NSDictionary,
           let issuerArray = issuerDict[kSecPropertyKeyValue] as? [NSDictionary] {
            let pairs = issuerArray.map { element in
                if let label = element[kSecPropertyKeyLabel] as? String,
                   let value = element[kSecPropertyKeyValue] as? String {
                    return "\(getLabel(from: label))=\(value)"
                }
                return ""
            }
            return pairs.joined(separator: ", ")
        }
        throw CertUtilsError.noIssuerName
    }

    /// Returns the hexString of the serial number of the certificate
    /// - Returns: the hexString of the serial number of the certificate
    /// - Throws: an  error from the [Security Framework Result Codes](https://developer.apple.com/documentation/security/security-framework-result-codes)  if the there is something wrong with the certificate
    public func getSerialNumber() throws -> String {
        var error: Unmanaged<CFError>?

        guard let serialNumber = SecCertificateCopySerialNumberData(certificate, &error) as Data?
        else {
            throw error!.takeRetainedValue() as Error
        }

        return serialNumber.hexString
    }

    /// Returns the subject name of the certificate
    ///
    /// For the **e.firma** the subject is the RFC
    ///
    /// - Returns: the subject name of the certificate
    public func getSubjectName() throws -> String {
        var error: Unmanaged<CFError>?
        guard let dict = SecCertificateCopyValues(certificate, [kSecOIDX509V1SubjectName] as CFArray, &error)
        else {
            throw error!.takeRetainedValue() as Error
        }

        let nsdict = dict as NSDictionary

        if let subjectDict = nsdict[kSecOIDX509V1SubjectName] as? NSDictionary, let subjectArray = subjectDict[kSecPropertyKeyValue] as? [NSDictionary] {
            for item in subjectArray {
                if let label = item[kSecPropertyKeyLabel] as? String, let value = item[kSecPropertyKeyValue] as? String, label == "2.5.4.45" {
                    return value
                }
            }
        }

        throw CertUtilsError.noRFC
    }

    /// Creates the signature of the information using the private key
    /// - Parameter info: the information that has to be signed with the private key
    /// - Returns: the [base64EncodedString](https://developer.apple.com/documentation/foundation/data/base64encodedstring(options:)) of the signature of the information using the private key
    /// - Throws: an `notSupportedAlgorithm` error if the private key does not support RSA-SHA1 signature for messages
    public func createSignature(for info: Data) throws -> String {
        let algorithm: SecKeyAlgorithm = .rsaSignatureMessagePKCS1v15SHA1
        guard SecKeyIsAlgorithmSupported(key, .sign, algorithm) else {
            throw CertUtilsError.notSupportedAlgorithm
        }
        var error: Unmanaged<CFError>?
        guard
            let signature = SecKeyCreateSignature(
                key,
                algorithm,
                info as CFData,
                &error) as Data?
        else {
            throw error!.takeRetainedValue() as Error
        }
        return signature.base64EncodedString()
    }

    /// Returns the [base64EncodedString](https://developer.apple.com/documentation/foundation/data/base64encodedstring(options:)) SHA1 hash of the data provided
    /// - Parameter data: the data information that needs to be hashed
    /// - Returns: the [base64EncodedString](https://developer.apple.com/documentation/foundation/data/base64encodedstring(options:)) SHA1 hash of the data provided
    public func getSHA1Hash(for data: Data) -> String {
        let digest = Insecure.SHA1.hash(data: data)
        return Data(digest).base64EncodedString()
    }

    /// Returns the [base64EncodedString](https://developer.apple.com/documentation/foundation/data/base64encodedstring(options:)) of the certData
    /// - Returns: the [base64EncodedString](https://developer.apple.com/documentation/foundation/data/base64encodedstring(options:)) of the certData
    public func getBase64StringCert() -> String {
        let certData = SecCertificateCopyData(certificate) as Data
        return certData.base64EncodedString()
    }
    
}
