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

public struct TokenData: Sendable, Equatable {
    var created: Date
    var expires: Date
    var token: String
}

enum AuthenticationManagerError: Error {
    case noCertUtils
    case authenticationBodyFailed
    case dataConversionFailed
    
}

public class AuthenticationManager {
    private var certUtils: CertUtils?
    private var tokens: [String: TokenData] = [:]
    
    public static let shared = AuthenticationManager()
    
    private init() {}
    
    public func addCertData(_ certData: Data, _ keyData: Data) throws {
        self.certUtils = try CertUtils(certData: certData, keyData: keyData)
    }
    
    public func addCertUtils(_ certUtils: CertUtils) {
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
    
    public func getToken(isRetention: Bool = false) async throws -> TokenData {
        if isRetention {
            return try await getRetenAuthenticationToken()
        }else {
            return try await getCFDIAuthenticationToken()
        }
    }
    
    private func getCFDIAuthenticationToken() async throws -> TokenData {
        if let tokenData = tokens["CFDI"] {
            if Date.now < tokenData.expires {
                return tokenData
            }else {
                let token = try await createTokenData()
                tokens["CFDI"]  = token
                return token
            }
        } else {
            let token = try await createTokenData()
            tokens["CFDI"]  = token
            return token
        }
    }
    
    private func getRetenAuthenticationToken() async throws -> TokenData {
        if let tokenData = tokens["Retencion"] {
            if Date.now < tokenData.expires {
                return tokenData
            }else {
                let token = try await createTokenData(isRetention: true)
                tokens["Retencion"] = token
                return token
            }
        }else {
            let token = try await createTokenData(isRetention: true)
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
        let digestValue = certUtils.getDigestValue(for: timestampData)
        
        let signInfo = "<SignedInfo xmlns=\"http://www.w3.org/2000/09/xmldsig#\"><CanonicalizationMethod Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"></CanonicalizationMethod><SignatureMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha1\"></SignatureMethod><Reference URI=\"#_0\"><Transforms><Transform Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"></Transform></Transforms><DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha1\"></DigestMethod><DigestValue>\(digestValue)</DigestValue></Reference></SignedInfo>"
        guard let signInfoData = signInfo.data(using: .utf8) else {
            throw AuthenticationManagerError.dataConversionFailed
        }
        
        let signature = try certUtils.sign(with: signInfoData)
        
    
        return "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:u=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd\"><s:Header><o:Security s:mustUnderstand=\"1\" xmlns:o=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd\"><u:Timestamp u:Id=\"_0\"><u:Created>\(created)</u:Created></u:Timestamp><o:BinarySecurityToken u:Id=\"uuid-\(uuid.uuidString.lowercased())-1\" ValueType=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509v3\" EncodingType=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary\">\(certUtils.getCert())</o:BinarySecurityToken><Signature xmlns=\"http://www.w3.org/2000/09/xmldsig#\"><SignedInfo><CanonicalizationMethod Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"></CanonicalizationMethod><SignatureMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha1\"></SignatureMethod><Reference URI=\"#_0\"><Transforms><Transform Algorithm=\"http://www.w3.org/2001/10/xml-exc-c14n#\"></Transform></Transforms><DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha1\"></DigestMethod><DigestValue>\(digestValue)</DigestValue></Reference></SignedInfo><SignatureValue>\(signature.base64EncodedString())</SignatureValue><KeyInfo><o:SecurityTokenReference><o:Reference ValueType=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509v3\" URI=\"#uuid-\(uuid.uuidString.lowercased())-1\"></o:Reference></o:SecurityTokenReference></KeyInfo></Signature></o:Security></s:Header><s:Body><Autentica xmlns=\"http://DescargaMasivaTerceros.gob.mx\"></Autentica></s:Body></s:Envelope>"
    }
    
    private func createTokenData(isRetention: Bool = false) async throws -> TokenData {
        let body = try createAuthenticationBody()
        
        guard let url = URL(string: "https://\(isRetention ? "reten" : "cfdi")descargamasivasolicitud.clouda.sat.gob.mx/Autenticacion/Autenticacion.svc") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url,timeoutInterval: .infinity)
        request.addValue("http://DescargaMasivaTerceros.gob.mx/IAutenticacion/Autentica", forHTTPHeaderField: "SOAPAction")
        request.addValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
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
