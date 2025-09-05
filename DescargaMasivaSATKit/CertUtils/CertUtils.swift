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

enum CertUtilsError: Error {
    case certificateCreationFailed
    case notSupportedAlgorithm
    case noRFC
    case noIssuerName
}

public struct CertUtils {
    private var certificate: SecCertificate
    private var key: SecKey
    
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

    public func getSerialNumber() throws -> String {
        var error: Unmanaged<CFError>?

        guard let serialNumber = SecCertificateCopySerialNumberData(certificate, &error) as Data?
        else {
            throw error!.takeRetainedValue() as Error
        }

        return serialNumber.hexString
    }

    public func getRFC() throws -> String {
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

    public func sign(with info: Data) throws -> Data {
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
        return signature
    }

    public func getDigestValue(for node: Data) -> String {
        let digest = Insecure.SHA1.hash(data: node)
        return Data(digest).base64EncodedString()
    }

    public func getCert() -> String {
        let certData = SecCertificateCopyData(certificate) as Data
        return certData.base64EncodedString()
    }

}
