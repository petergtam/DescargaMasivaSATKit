//
//  Authentication.swift
//  Fidadces
//
//  Created by Pedro Ivan Salas Peña on 23/04/24.
//

import CryptoKit
import Foundation


extension Date {
    var utc: String {
        self.formatted(.iso8601.year().month().day().timeZone(separator: .omitted).time(includingFractionalSeconds: true).timeSeparator(.colon))
    }
}

/// A type with the token information
public struct TokenData: Sendable, Equatable {
    var created: Date
    var expires: Date
    var token: String
}

struct AuthenticationManagerError: Error {
    private enum Code {
        case noCertUtils
        case authenticationBodyFailed
        case dataConversionFailed
    }
    
    private let code: Code
    
    static var noCertUtils: AuthenticationManagerError { .init(code: .noCertUtils) }
    static var authenticationBodyFailed: AuthenticationManagerError { .init(code: .authenticationBodyFailed) }
    static var dataConversionFailed: AuthenticationManagerError { .init(code: .dataConversionFailed) }
    
    var localizedDescription: String {
        switch code {
        case .noCertUtils:
            return "No CertUtils provided."
        case .authenticationBodyFailed:
            return "Authentication body failed."
        case .dataConversionFailed:
            return "Data conversion failed."
        }
    }
    
    
}

/// A token manager for the authentication of the API.
public class AuthenticationManager {
    private var certUtils: CertUtils?
    private var tokens: [String: TokenData] = [:]
    
    /// The shared token manager object.
    ///
    /// Use the shared instance to add the e.firma and the tokens for the authentication
    public static let shared = AuthenticationManager()
    
    private init() {}
    
    func reset() {
        certUtils = nil
        tokens = [:]
    }

    /// Creates the certUtils object for the manager.
    /// - Parameters:
    ///   - certData: the certificate data of your **e.firma** in DER format.
    ///   - keyData: the private key data of your **e.firma** in DER format without password.
    /// - SeeAlso: For the requirements of the data and throwing see: ``CertUtils/init(certData:keyData:)``.
    public func add(certData: Data, keyData: Data) throws {
        self.certUtils = try CertUtils(certData: certData, keyData: keyData)
    }
    
    /// Provides the certUtils object for the manager.
    /// - Parameter certUtils: the certUtils need it for the API calls.
    public func add(certUtils: CertUtils) {
        self.certUtils = certUtils
    }
    
    func getTokens() -> [String: TokenData] {
        return self.tokens
    }
    
    func getCertUtils() throws -> CertUtils {
        guard let certUtils else {
            throw AuthenticationManagerError.noCertUtils
        }
        return certUtils
    }
    
    /// Returns a TokenData object with the information of the current token.
    /// - Parameter isRetention: a Bool value to know whether we are using the CFDI or the Retencion API.
    /// - Returns: a TokenData object with the information of the current token.
    /// - Throws: a `noCertUtils` error if there is no certUtils object for the manager. That is ``add(certUtils:)`` or ``add(certData:keyData:)`` has not been called yet.
    public func getToken(isRetention: Bool = false) async throws -> TokenData {
        try await getToken(URLSession.shared, Date.now, isRetention: isRetention)
    }
    
    func getToken(_ sharedSession: SharedSession = URLSession.shared, _ now: Date = Date.now , isRetention: Bool = false) async throws -> TokenData {
        if isRetention {
            return try await getRetenAuthenticationToken(sharedSession, now)
        }else {
            return try await getCFDIAuthenticationToken(sharedSession, now)
        }
    }
    
    private func getCFDIAuthenticationToken(_ sharedSession: SharedSession = URLSession.shared, _ now: Date = Date.now) async throws -> TokenData {
        if let tokenData = tokens["CFDI"] {
            if now < tokenData.expires {
                return tokenData
            }else {
                let token = try await createTokenData(sharedSession)
                tokens["CFDI"]  = token
                return token
            }
        } else {
            let token = try await createTokenData(sharedSession)
            tokens["CFDI"]  = token
            return token
        }
    }
    
    private func getRetenAuthenticationToken(_ sharedSession: SharedSession = URLSession.shared, _ now: Date = Date.now) async throws -> TokenData {
        if let tokenData = tokens["Retencion"] {
            if now < tokenData.expires {
                return tokenData
            }else {
                let token = try await createTokenData(sharedSession, isRetention: true)
                tokens["Retencion"] = token
                return token
            }
        }else {
            let token = try await createTokenData(sharedSession, isRetention: true)
            tokens["Retencion"] = token
            return token
        }
    }
    
    private func createAuthenticationBody() throws -> String {
        guard let certUtils else {
            throw AuthenticationManagerError.noCertUtils
        }
        let uuid = UUID()
        let now = Date.now
        let created = now.utc
        let timestamp = "<u:Timestamp xmlns:u=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd\" u:Id=\"_0\"><u:Created>\(created)</u:Created></u:Timestamp>"
        guard let timestampData = timestamp.data(using: .utf8) else {
            throw AuthenticationManagerError.dataConversionFailed
        }
        let digestValue = certUtils.getSHA1Hash(for: timestampData)
        
        let signInfo = "<SignedInfo xmlns=\"http://www.w3.org/2000/09/xmldsig#\"><CanonicalizationMethod Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"></CanonicalizationMethod><SignatureMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha1\"></SignatureMethod><Reference URI=\"#_0\"><Transforms><Transform Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"></Transform></Transforms><DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha1\"></DigestMethod><DigestValue>\(digestValue)</DigestValue></Reference></SignedInfo>"
        guard let signInfoData = signInfo.data(using: .utf8) else {
            throw AuthenticationManagerError.dataConversionFailed
        }
        
        let signature = try certUtils.createSignature(for: signInfoData)
        
    
        return "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:u=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd\"><s:Header><o:Security s:mustUnderstand=\"1\" xmlns:o=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd\"><u:Timestamp u:Id=\"_0\"><u:Created>\(created)</u:Created></u:Timestamp><o:BinarySecurityToken u:Id=\"uuid-\(uuid.uuidString.lowercased())-1\" ValueType=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509v3\" EncodingType=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary\">\(certUtils.getBase64StringCert())</o:BinarySecurityToken><Signature xmlns=\"http://www.w3.org/2000/09/xmldsig#\"><SignedInfo><CanonicalizationMethod Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"></CanonicalizationMethod><SignatureMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha1\"></SignatureMethod><Reference URI=\"#_0\"><Transforms><Transform Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"></Transform></Transforms><DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha1\"></DigestMethod><DigestValue>\(digestValue)</DigestValue></Reference></SignedInfo><SignatureValue>\(signature)</SignatureValue><KeyInfo><o:SecurityTokenReference><o:Reference ValueType=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509v3\" URI=\"#uuid-\(uuid.uuidString.lowercased())-1\"></o:Reference></o:SecurityTokenReference></KeyInfo></Signature></o:Security></s:Header><s:Body><Autentica xmlns=\"http://DescargaMasivaTerceros.gob.mx\"></Autentica></s:Body></s:Envelope>"
    }
    
    private func createTokenData(_ sharedSession: SharedSession = URLSession.shared, isRetention: Bool = false) async throws -> TokenData {
        let body = try createAuthenticationBody()
        
        guard let url = URL(string: "https://\(isRetention ? "reten" : "cfdi")descargamasivasolicitud.clouda.sat.gob.mx/Autenticacion/Autenticacion.svc") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url,timeoutInterval: .infinity)
        request.addValue("http://DescargaMasivaTerceros.gob.mx/IAutenticacion/Autentica", forHTTPHeaderField: "SOAPAction")
        request.addValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await sharedSession.data(for: request)
        
        print(String(data: data, encoding: .utf8)!, response.debugDescription)
        
        return await withCheckedContinuation { continuation in
            let autResult = AuthenticationResult(data: data, response: response){ (created, expires, token, error) in
                if let error {
                    continuation.resume(throwing: error as! Never)
                }
                if let created, let expires, let token {
                    continuation.resume(returning: TokenData(created: created, expires: expires, token: token))
                }
            }
            
            autResult.parse()
        }
    }
    
}
