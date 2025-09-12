//
//  VerificationEndpoint.swift
//  Fidadces
//
//  Created by Pedro Ivan Salas Peña on 08/05/24.
//

import Foundation

struct VerificationEndpointError: Error {
    private enum Code {
        case dataConversionFailed
    }
    
    private let code: Code
    
    static var dataConversionFailed: VerificationEndpointError {
        .init(code: .dataConversionFailed)
    }
    
    var localizedDescription: String {
        switch code {
        case .dataConversionFailed:
            return "Data conversion failed."
        }
    }
}

/// An object to handle requests to the Verification SOAP Endpoint of the API
///
/// - SeeAlso: [SAT Verification Documentation](https://ampocdevbuk01a.s3.us-east-1.amazonaws.com/2_WS_Verificacion_de_Descarga_Masiva_V1_5_VF_5e53cc2bb5.pdf)
///
public struct VerificationEndpoint {
    private var queryId: String
    private var isRetention: Bool
    
    /// Creates an instance of the VerificationEndpoint object
    /// - Parameters:
    ///   - queryId: Query id to verify
    ///   - isRetention: Whether we are using the CFDI API or the Retencion API. Defaults to the CFDI API (false)
    public init(queryId: String, isRetention: Bool = false){
        self.queryId = queryId
        self.isRetention = isRetention
    }
    
    private func createVerificaSolicitudDescargaBody() throws -> String {
        let certUtils = try AuthenticationManager.shared.getCertUtils()
        let rfc = try certUtils.getSubjectName()
        
        let nodoSolicitud = "<des:solicitud IdSolicitud=\"\(queryId)\" RfcSolicitante=\"\(rfc)\"></des:solicitud>"

        let digestInfo = "<des:VerificaSolicitudDescarga xmlns:des=\"http://DescargaMasivaTerceros.sat.gob.mx\">\(nodoSolicitud)</des:VerificaSolicitudDescarga>"
        guard let digestInfoData = digestInfo.data(using: .utf8)  else {
            throw VerificationEndpointError.dataConversionFailed
        }
        
        let digestValue = certUtils.getSHA1Hash(for: digestInfoData)
        
        let signInfo = "<SignedInfo xmlns=\"http://www.w3.org/2000/09/xmldsig#\"><CanonicalizationMethod Algorithm=\"http://www.w3.org/TR/2001/REC-xml-c14n-20010315\"></CanonicalizationMethod><SignatureMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha1\"></SignatureMethod><Reference URI=\"\"><Transforms><Transform Algorithm=\"http://www.w3.org/2000/09/xmldsig#enveloped-signature\"></Transform></Transforms><DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha1\"></DigestMethod><DigestValue>\(digestValue)</DigestValue></Reference></SignedInfo>"

        guard let signInfoData = signInfo.data(using: .utf8)  else {
            throw VerificationEndpointError.dataConversionFailed
        }
        
        let signature = try certUtils.createSignature(for: signInfoData)
        
        let issuerName = try certUtils.getIssuerName()
        
        let serialNumber = try certUtils.getSerialNumber()
        
        return "<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:des=\"http://DescargaMasivaTerceros.sat.gob.mx\" xmlns:xd=\"http://www.w3.org/2000/09/xmldsig#\"><soapenv:Header/><soapenv:Body><des:VerificaSolicitudDescarga>\(nodoSolicitud.replacingOccurrences(of: "</des:solicitud>", with: ""))<Signature xmlns=\"http://www.w3.org/2000/09/xmldsig#\"><SignedInfo><CanonicalizationMethod Algorithm=\"http://www.w3.org/TR/2001/REC-xml-c14n-20010315\"/><SignatureMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha1\"/><Reference URI=\"\"><Transforms><Transform Algorithm=\"http://www.w3.org/2000/09/xmldsig#enveloped-signature\"/></Transforms><DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha1\"/><DigestValue>\(digestValue)</DigestValue></Reference></SignedInfo><SignatureValue>\(signature)</SignatureValue><KeyInfo><X509Data><X509IssuerSerial><X509IssuerName>\(issuerName)</X509IssuerName><X509SerialNumber>\(serialNumber)</X509SerialNumber></X509IssuerSerial><X509Certificate>\(certUtils.getBase64StringCert())</X509Certificate></X509Data></KeyInfo></Signature></des:solicitud></des:VerificaSolicitudDescarga></soapenv:Body></soapenv:Envelope>"
    }
    
    /// Requests the verification of the given query id
    /// - Returns: a json string representation of the result of the verification and the contents of the packages to download if the verification is successful
    /// - Throws: a `noCertUtils` error if there is no certUtils object for the manager. That is ``AuthenticationManager/add(certUtils:)`` or ``AuthenticationManager/add(certData:keyData:)`` has not been called yet.
    public func request() async throws -> String {
        try await request(URLSession.shared)
    }
    
    func request(_ sharedSession: SharedSession = URLSession.shared) async throws -> String {
        let tokenData = try await AuthenticationManager.shared.getToken(isRetention: isRetention)
        let body = try createVerificaSolicitudDescargaBody()
        
        guard let url = URL(string:"https://\(isRetention ? "reten" : "cfdi")descargamasivasolicitud.clouda.sat.gob.mx/VerificaSolicitudDescargaService.svc") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url, timeoutInterval: .infinity)
        request.addValue("http://DescargaMasivaTerceros.sat.gob.mx/IVerificaSolicitudDescargaService/VerificaSolicitudDescarga", forHTTPHeaderField: "SOAPAction")
        request.addValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.addValue("WRAP access_token=\"\(tokenData.token)\"", forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) =  try await sharedSession.data(for: request)
        
        return try await withCheckedThrowingContinuation { continuation in
            let verResult = VerificationEndpointResult(data: data, response: response){ result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let result {
                    continuation.resume(returning: result)
                }
            }
            verResult.parse()
        }
    }
}
