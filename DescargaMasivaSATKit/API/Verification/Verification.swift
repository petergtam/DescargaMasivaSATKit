//
//  Verification.swift
//  Fidadces
//
//  Created by Pedro Ivan Salas Peña on 08/05/24.
//

import Foundation

enum VerificationError: Error {
    case dataConversionFailed
    
}

public struct Verification {
    private var idSolicitud: String
    private var isRetention: Bool
    
    public init(idSolicitud: String, isRetention: Bool = false){
        self.idSolicitud = idSolicitud
        self.isRetention = isRetention
    }

    private func createVerificaSolicitudDescargaBody() throws -> String {
        let certUtils = try AuthenticationManager.shared.getCertUtils()
        let rfc = try certUtils.getRFC()

        let nodoSolicitud =
            "<des:solicitud IdSolicitud=\"\(idSolicitud)\" RfcSolicitante=\"\(rfc)\"></des:solicitud>"

        let digestInfo =
            "<des:VerificaSolicitudDescarga xmlns:des=\"http://DescargaMasivaTerceros.sat.gob.mx\">\(nodoSolicitud)</des:VerificaSolicitudDescarga>"
        guard let digestInfoData = digestInfo.data(using: .utf8)  else {
            throw VerificationError.dataConversionFailed
        }
        
        let digestValue = certUtils.getDigestValue(for: digestInfoData)
        
        let signInfo =
            "<SignedInfo xmlns=\"http://www.w3.org/2000/09/xmldsig#\"><CanonicalizationMethod Algorithm=\"http://www.w3.org/TR/2001/REC-xml-c14n-20010315\"></CanonicalizationMethod><SignatureMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha1\"></SignatureMethod><Reference URI=\"\"><Transforms><Transform Algorithm=\"http://www.w3.org/2000/09/xmldsig#enveloped-signature\"></Transform></Transforms><DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha1\"></DigestMethod><DigestValue>\(digestValue)</DigestValue></Reference></SignedInfo>"
        
        guard let signInfoData = signInfo.data(using: .utf8)  else {
            throw VerificationError.dataConversionFailed
        }

        let signature = try certUtils.sign(with: signInfoData)

        let issuerName = try certUtils.getIssuerName()

        let serialNumber = try certUtils.getSerialNumber()
        
        return
            "<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:des=\"http://DescargaMasivaTerceros.sat.gob.mx\" xmlns:xd=\"http://www.w3.org/2000/09/xmldsig#\"><soapenv:Header/><soapenv:Body><des:VerificaSolicitudDescarga>\(nodoSolicitud.replacingOccurrences(of: "</des:solicitud>", with: ""))<Signature xmlns=\"http://www.w3.org/2000/09/xmldsig#\"><SignedInfo><CanonicalizationMethod Algorithm=\"http://www.w3.org/TR/2001/REC-xml-c14n-20010315\"/><SignatureMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha1\"/><Reference URI=\"\"><Transforms><Transform Algorithm=\"http://www.w3.org/2000/09/xmldsig#enveloped-signature\"/></Transforms><DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha1\"/><DigestValue>\(digestValue)</DigestValue></Reference></SignedInfo><SignatureValue>\(signature.base64EncodedString())</SignatureValue><KeyInfo><X509Data><X509IssuerSerial><X509IssuerName>\(issuerName)</X509IssuerName><X509SerialNumber>\(serialNumber)</X509SerialNumber></X509IssuerSerial><X509Certificate>\(certUtils.getCert())</X509Certificate></X509Data></KeyInfo></Signature></des:solicitud></des:VerificaSolicitudDescarga></soapenv:Body></soapenv:Envelope>"
    }

    public func request() async throws -> ([String: String], [String]?) {
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
        
        let (data, response) =  try await URLSession.shared.data(for: request)
        
        return await withCheckedContinuation { continuation in
            let verResult = VerificationResult(data: data, response: response){ result, contents, error in
                if let error {
                    continuation.resume(throwing: error as! Never)
                    return
                }
                if let result {
                    if let contents {
                        continuation.resume(returning: (result, contents))
                    }else {
                        continuation.resume(returning: (result,nil))
                    }
                }
            }
            verResult.parse()
        }
    }
}
