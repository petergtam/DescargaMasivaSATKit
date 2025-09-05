//
//  Query.swift
//  Fidadces
//
//  Created by Pedro Ivan Salas Peña on 03/05/24.
//

import Foundation

enum QueryError: Error {
    case dataConversionFailed
}


public struct Query {
    private var params: InvoiceParams
    private var endPoint: String
    
    public init(params: InvoiceParams) {
        self.params = params
        
        if params.invoiceId != "" {
            self.endPoint = "SolicitaDescargaFolio"
        } else {
            if params.operation == .emitidas {
                self.endPoint = "SolicitaDescargaEmitidos"
            } else {
                self.endPoint = "SolicitaDescargaRecibidos"
            }
        }
    }
    
    private func createSolicitaDescargaBody() throws -> String {
        let certUtils = try AuthenticationManager.shared.getCertUtils()
        let nodoSolicitud = try generateNodoSolicitud()
        let digestInfo = "<\(endPoint) xmlns=\"http://DescargaMasivaTerceros.sat.gob.mx\">\(nodoSolicitud)</\(endPoint)>"
        guard let digestInfoData = digestInfo.data(using: .utf8) else {
            throw QueryError.dataConversionFailed
        }
        
        let digestValue = certUtils.getDigestValue(for: digestInfoData)
        
        let signInfo = "<SignedInfo xmlns=\"http://www.w3.org/2000/09/xmldsig#\"><CanonicalizationMethod Algorithm=\"http://www.w3.org/TR/2001/REC-xml-c14n-20010315\"></CanonicalizationMethod><SignatureMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha1\"></SignatureMethod><Reference URI=\"\"><Transforms><Transform Algorithm=\"http://www.w3.org/2000/09/xmldsig#enveloped-signature\"></Transform></Transforms><DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha1\"></DigestMethod><DigestValue>\(digestValue)</DigestValue></Reference></SignedInfo>"
        guard let signInfoData = signInfo.data(using: .utf8) else {
            throw QueryError.dataConversionFailed
        }
        
        let signature = try certUtils.sign(with: signInfoData)
        
        let issuerName = try certUtils.getIssuerName()
        
        let serialNumber = try certUtils.getSerialNumber()
        
        return "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Header></s:Header><s:Body xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><\(endPoint) xmlns=\"http://DescargaMasivaTerceros.sat.gob.mx\">\(nodoSolicitud.replacingOccurrences(of: "</solicitud>", with: ""))<Signature xmlns=\"http://www.w3.org/2000/09/xmldsig#\"><SignedInfo><CanonicalizationMethod Algorithm=\"http://www.w3.org/TR/2001/REC-xml-c14n-20010315\"/><SignatureMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha1\"/><Reference URI=\"\"><Transforms><Transform Algorithm=\"http://www.w3.org/2000/09/xmldsig#enveloped-signature\"/></Transforms><DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha1\"/><DigestValue>\(digestValue)</DigestValue></Reference></SignedInfo><SignatureValue>\(signature.base64EncodedString())</SignatureValue><KeyInfo><X509Data><X509IssuerSerial><X509IssuerName>\(issuerName)</X509IssuerName><X509SerialNumber>\(serialNumber)</X509SerialNumber></X509IssuerSerial><X509Certificate>\(certUtils.getCert())</X509Certificate></X509Data></KeyInfo></Signature></solicitud></\(endPoint)></s:Body></s:Envelope>"
    }
    
    private func generateNodoSolicitud() throws -> String {
        let certUtils = try AuthenticationManager.shared.getCertUtils()
        let rfc = try certUtils.getRFC()
        var nodo = "<solicitud"
        if let status = params.receiptStatus {
            nodo +=  " EstadoComprobante=\"\(status.name)\""
        }
        if params.invoiceId != "" {
            nodo += " Folio=\"\(params.invoiceId)\""
            nodo += " RfcSolicitante=\"\(rfc)\""
        }else {
            let calendar = Calendar.current
            let initialDate = calendar.startOfDay(for: params.startDate)
            nodo += " FechaInicial=\"\(initialDate.utc)\""
            if let endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: params.endDate){
                nodo += " FechaFinal=\"\(endDate.utc)\""
            }
            nodo += params.operation == .recibidas ? " RfcReceptor=\"\(rfc)\"" : ""
            nodo += params.operation == .emitidas ? " RfcEmisor=\"\(rfc)\"" : ""
            nodo += " RfcSolicitante=\"\(rfc)\""
        }
        if let comprobante = params.receiptType {
            nodo += " TipoComprobante=\"\(comprobante.rawValue)\""
        }
        nodo += " TipoSolicitud=\"\(params.queryType.rawValue)\""
        nodo += "></solicitud>"
        return nodo
    }
    
    public func request() async throws -> [String: String] {
        let tokenData = try await AuthenticationManager.shared.getToken(isRetention: params.isRetention)
        let body = try createSolicitaDescargaBody()
        guard let url = URL(string: "https://\(params.isRetention ? "reten": "cfdi")descargamasivasolicitud.clouda.sat.gob.mx/SolicitaDescargaService.svc") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url,timeoutInterval: .infinity)
        request.addValue("http://DescargaMasivaTerceros.sat.gob.mx/ISolicitaDescargaService/\(endPoint)", forHTTPHeaderField: "SOAPAction")
        request.addValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.addValue("WRAP access_token=\"\(tokenData.token)\"", forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        return await withCheckedContinuation { continuation in
            let reqResult = QueryResult(data: data, response: response){ result, error in
                if let error {
                    continuation.resume(throwing: error as! Never)
                    return
                }
                if let result {
                    continuation.resume(returning: result)
                }
            }
            reqResult.parse()
        }
        
    }
    
}
