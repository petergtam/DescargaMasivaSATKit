//
//  DownloadEndpoint.swift
//  Fidadces
//
//  Created by Pedro Ivan Salas Peña on 10/05/24.
//

import Foundation

struct DownloadEndpointError: Error {
    private enum Code {
        case dataConversionFailed
    }
    
    private let code: Code

    static var dataConversionFailed: DownloadEndpointError { .init(code: .dataConversionFailed) }
    
    var localizedDescription: String {
        switch code {
        case .dataConversionFailed:
            return "Data conversion failed."
        }
    }
    
}

/// An object to handle requests to the Download SOAP Endpoint of the API
///
/// - SeeAlso: [SAT Download Documentation](https://ampocdevbuk01a.s3.us-east-1.amazonaws.com/3_WS_Descarga_de_Solicitudes_Exitosas_V1_5_VF_74f66e46ec.pdf)
///
public struct DownloadEndpoint {
    private var packageId: String
    private var isRetention: Bool
    
    /// Creates an instance of the DownloadEndpoint object
    /// - Parameters:
    ///   - packageId: Package id to be requested for download
    ///   - isRetention: Whether we are using the CFDI API or the Retencion API. Defaults to the CFDI API (false)
    public init(packageId: String, isRetention: Bool = false){
        self.packageId = packageId
        self.isRetention = isRetention
    }

    private func createDescargaBody() throws -> String {
        let certUtils = try AuthenticationManager.shared.getCertUtils()
        let rfc = try certUtils.getSubjectName()

        let nodoSolicitud =
            "<des:peticionDescarga IdPaquete=\"\(packageId)\" RfcSolicitante=\"\(rfc)\"></des:peticionDescarga>"

        let digestInfo =
            "<des:PeticionDescargaMasivaTercerosEntrada xmlns:des=\"http://DescargaMasivaTerceros.sat.gob.mx\">\(nodoSolicitud)</des:PeticionDescargaMasivaTercerosEntrada>"
        guard let digestInfoData = digestInfo.data(using: .utf8) else {
            throw DownloadEndpointError.dataConversionFailed
        }
        
        let digestValue = certUtils.getSHA1Hash(for: digestInfoData)
        
        let signInfo =
            "<SignedInfo xmlns=\"http://www.w3.org/2000/09/xmldsig#\"><CanonicalizationMethod Algorithm=\"http://www.w3.org/TR/2001/REC-xml-c14n-20010315\"></CanonicalizationMethod><SignatureMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha1\"></SignatureMethod><Reference URI=\"\"><Transforms><Transform Algorithm=\"http://www.w3.org/2000/09/xmldsig#enveloped-signature\"></Transform></Transforms><DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha1\"></DigestMethod><DigestValue>\(digestValue)</DigestValue></Reference></SignedInfo>"

        guard let signInfoData = signInfo.data(using: .utf8) else {
            throw DownloadEndpointError.dataConversionFailed
        }
        
        let signature = try certUtils.createSignature(for: signInfoData)

        let issuerName = try certUtils.getIssuerName()

        let serialNumber = try certUtils.getSerialNumber()
        
        return
            "<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:des=\"http://DescargaMasivaTerceros.sat.gob.mx\" xmlns:xd=\"http://www.w3.org/2000/09/xmldsig#\"><soapenv:Header/><soapenv:Body><des:PeticionDescargaMasivaTercerosEntrada>\(nodoSolicitud.replacingOccurrences(of: "</des:peticionDescarga>", with: ""))<Signature xmlns=\"http://www.w3.org/2000/09/xmldsig#\"><SignedInfo><CanonicalizationMethod Algorithm=\"http://www.w3.org/TR/2001/REC-xml-c14n-20010315\"/><SignatureMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha1\"/><Reference URI=\"\"><Transforms><Transform Algorithm=\"http://www.w3.org/2000/09/xmldsig#enveloped-signature\"/></Transforms><DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha1\"/><DigestValue>\(digestValue)</DigestValue></Reference></SignedInfo><SignatureValue>\(signature)</SignatureValue><KeyInfo><X509Data><X509IssuerSerial><X509IssuerName>\(issuerName)</X509IssuerName><X509SerialNumber>\(serialNumber)</X509SerialNumber></X509IssuerSerial><X509Certificate>\(certUtils.getBase64StringCert())</X509Certificate></X509Data></KeyInfo></Signature></des:peticionDescarga></des:PeticionDescargaMasivaTercerosEntrada></soapenv:Body></soapenv:Envelope>"
    }
    
    
    /// Requests the content of the package to download
    /// - Returns: a json string representation of the result and the contents of the package to download
    /// - Throws: a `noCertUtils` error if there is no certUtils object for the manager. That is ``AuthenticationManager/add(certUtils:)`` or ``AuthenticationManager/add(certData:keyData:)`` has not been called yet.
    public func request() async throws -> String {
        let tokenData = try await AuthenticationManager.shared.getToken(isRetention: isRetention)
        
        let body = try createDescargaBody()
        
        guard let url = URL(string: "https://\(isRetention ? "reten" : "cfdi")descargamasiva.clouda.sat.gob.mx/DescargaMasivaService.svc") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url, timeoutInterval: .infinity)
        request.addValue("http://DescargaMasivaTerceros.sat.gob.mx/IDescargaMasivaTercerosService/Descargar", forHTTPHeaderField: "SOAPAction")
        request.addValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.addValue("WRAP access_token=\"\(tokenData.token)\"", forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        return await withCheckedContinuation { continuation in
            let downResult = DownloadEndpointResult(data: data, response: response){ result, error in
                if let error {
                    continuation.resume(throwing: error as! Never)
                }
                if let result {
                    continuation.resume(returning: result)
                }
            }
            downResult.parse()
        }
    }
}
