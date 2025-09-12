//
//  QueryEndpoint.swift
//  Fidadces
//
//  Created by Pedro Ivan Salas Peña on 03/05/24.
//

import Foundation

struct QueryEndpointError: Error {
    private enum Code {
        case dataConversionFailed
    }
    
    private let code: Code
    
    static var dataConversionFailed: QueryEndpointError {
        .init(code: .dataConversionFailed)
    }
    
    var localizedDescription: String {
        switch code {
        case .dataConversionFailed:
            return "Data conversion failed."
        }
    }
}


/// An object to handle requests to the Query SOAP Endpoint of the API
///
/// - SeeAlso: [SAT Query Documentation](https://ampocdevbuk01a.s3.us-east-1.amazonaws.com/1_WS_Solicitud_Descarga_Masiva_V1_5_VF_89183c42e9.pdf)
///
public struct QueryEndpoint {
    private var params: InvoiceParams
    private var endPoint: String
    
    /// Creates an instance of the QueryEndpoint object
    /// - Parameter params: the parameters for the endpoint
    /// - SeeAlso: The ``InvoiceParams`` and the [documentation](https://ampocdevbuk01a.s3.us-east-1.amazonaws.com/1_WS_Solicitud_Descarga_Masiva_V1_5_VF_89183c42e9.pdf) for the endpoint
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
            throw QueryEndpointError.dataConversionFailed
        }
        
        let digestValue = certUtils.getSHA1Hash(for: digestInfoData)
        
        let signInfo = "<SignedInfo xmlns=\"http://www.w3.org/2000/09/xmldsig#\"><CanonicalizationMethod Algorithm=\"http://www.w3.org/TR/2001/REC-xml-c14n-20010315\"></CanonicalizationMethod><SignatureMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha1\"></SignatureMethod><Reference URI=\"\"><Transforms><Transform Algorithm=\"http://www.w3.org/2000/09/xmldsig#enveloped-signature\"></Transform></Transforms><DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha1\"></DigestMethod><DigestValue>\(digestValue)</DigestValue></Reference></SignedInfo>"
        guard let signInfoData = signInfo.data(using: .utf8) else {
            throw QueryEndpointError.dataConversionFailed
        }
        
        let signature = try certUtils.createSignature(for: signInfoData)
        
        let issuerName = try certUtils.getIssuerName()
        
        let serialNumber = try certUtils.getSerialNumber()
        
        return "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Header></s:Header><s:Body xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><\(endPoint) xmlns=\"http://DescargaMasivaTerceros.sat.gob.mx\">\(nodoSolicitud.replacingOccurrences(of: "</solicitud>", with: ""))<Signature xmlns=\"http://www.w3.org/2000/09/xmldsig#\"><SignedInfo><CanonicalizationMethod Algorithm=\"http://www.w3.org/TR/2001/REC-xml-c14n-20010315\"/><SignatureMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#rsa-sha1\"/><Reference URI=\"\"><Transforms><Transform Algorithm=\"http://www.w3.org/2000/09/xmldsig#enveloped-signature\"/></Transforms><DigestMethod Algorithm=\"http://www.w3.org/2000/09/xmldsig#sha1\"/><DigestValue>\(digestValue)</DigestValue></Reference></SignedInfo><SignatureValue>\(signature)</SignatureValue><KeyInfo><X509Data><X509IssuerSerial><X509IssuerName>\(issuerName)</X509IssuerName><X509SerialNumber>\(serialNumber)</X509SerialNumber></X509IssuerSerial><X509Certificate>\(certUtils.getBase64StringCert())</X509Certificate></X509Data></KeyInfo></Signature></solicitud></\(endPoint)></s:Body></s:Envelope>"
    }
    
    private func generateNodoSolicitud() throws -> String {
        let certUtils = try AuthenticationManager.shared.getCertUtils()
        let rfc = try certUtils.getSubjectName()
        var nodo = "<solicitud"
        nodo +=  " EstadoComprobante=\"\(params.receiptStatus.name)\""
        if params.invoiceId != "" {
            nodo += " Folio=\"\(params.invoiceId)\""
        }else {
            let calendar = Calendar.current
            let initialDate = calendar.startOfDay(for: params.startDate)
            nodo += " FechaInicial=\"\(initialDate.utc)\""
            if let endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: params.endDate){
                nodo += " FechaFinal=\"\(endDate.utc)\""
            }
            nodo += params.operation == .recibidas ? " RfcReceptor=\"\(rfc)\"" : ""
            nodo += params.operation == .emitidas ? " RfcEmisor=\"\(rfc)\"" : ""
        }
        if let comprobante = params.receiptType {
            nodo += " TipoComprobante=\"\(comprobante.rawValue)\""
        }
        nodo += " TipoSolicitud=\"\(params.queryType.rawValue)\""
        nodo += "></solicitud>"
        return nodo
    }
    
    /// Requests the invoices for the given params
    /// - Returns: a json string representation of the result of the request
    /// - Throws: a `noCertUtils` error if there is no certUtils object for the manager. That is ``AuthenticationManager/add(certUtils:)`` or ``AuthenticationManager/add(certData:keyData:)`` has not been called yet.
    public func request() async throws -> String {
        try await request(URLSession.shared)
    }
    
    func request(_ sharedSession: SharedSession = URLSession.shared) async throws -> String {
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
        
        let (data, response) = try await sharedSession.data(for: request)
        
        return try await withCheckedThrowingContinuation { continuation in
            let reqResult = QueryEndpointResult(data: data, response: response){ result, error in
                if let error {
                    continuation.resume(throwing: error)
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
