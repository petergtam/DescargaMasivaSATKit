//
//  InvoiceParams.swift
//  DescargaMasivaKit
//
//  Created by Pedro Ivan Salas Peña on 02/09/25.
//

import Foundation

/// Options for the query type
///
/// It matches `TipoSolicitud` from the api [documentation](https://ampocdevbuk01a.s3.us-east-1.amazonaws.com/1_WS_Solicitud_Descarga_Masiva_V1_5_VF_89183c42e9.pdf)
public enum QueryType: String, CaseIterable, Identifiable {
    case metadata = "Metadata"
    case cfdi = "CFDI"
    case pdf = "PDF"
    case pdfcocema = "PDFCOCEMA"
    case txt = "TXTUUIDMASIVA"

    public var id: String {
        rawValue
    }
}

/// Options for the receipt type
///
/// It matches `TipoComprobante` from the api [documentation](https://ampocdevbuk01a.s3.us-east-1.amazonaws.com/1_WS_Solicitud_Descarga_Masiva_V1_5_VF_89183c42e9.pdf)
public enum ReceiptType: String, CaseIterable, Identifiable {
    case ingreso = "I"
    case egreso = "E"
    case traslado = "T"
    case nomina = "N"
    case pago = "P"

    public var id: String {
        rawValue
    }
}

/// Options for the receipt status
///
/// It matches `EstadoComprobante` from the api [documentation](https://ampocdevbuk01a.s3.us-east-1.amazonaws.com/1_WS_Solicitud_Descarga_Masiva_V1_5_VF_89183c42e9.pdf)
public enum ReceiptStatus: String, CaseIterable, Identifiable {
    case todos
    case cancelado
    case vigente
    
    public var name: String {
        rawValue.capitalized
    }

    public var id: String {
        name
    }
}

/// Options for the operation type, it could be either `emitidas` or `recibidas`
public enum OperationType: String, CaseIterable, Identifiable {
    case emitidas
    case recibidas

    public var name: String {
        rawValue.capitalized
    }

    public var id: String {
        name
    }
}

/// Options for the endpoint url, it could be either `facturas` or `retenciones`
public enum EndPoint: String, CaseIterable, Identifiable {
    case facturas
    case retenciones

    public var id: String {
        rawValue
    }
}

/// Params object for the query endpoint
public struct InvoiceParams {
    /// Variable for the operation type. It defaults to `emitidas`.
    public var operation: OperationType = .emitidas
    /// Required variable for the startDate. It defaults to the month before today.
    public var startDate: Date
    /// Required variable for the endDate. It defaults to yesterday.
    public var endDate: Date
    /// Required variable for the query type. It defaults to `cfdi`.
    public var queryType: QueryType = .cfdi
    /// Optional variable for the receipt type.
    public var receiptType: ReceiptType? = nil
    /// Required variable for the receipt status.
    public var receiptStatus: ReceiptStatus = .vigente
    /// Required variable for the invoiceId.
    ///
    ///If this is provided then ``startDate``, ``endDate``,  ``operation`` are not required.
    ///
    public var invoiceId: String = ""
    /// Variable for the endpoint.
    public var endPoint: EndPoint = .facturas
    
    /// Variable to verify if we are working with the retention endpoint or not.
    public var isRetention: Bool {
        endPoint == .retenciones
    }

    public init() {
        let calendar = Calendar.current
        let today = Date()
        startDate = today
        endDate = today
        if let initial = calendar.date(byAdding: .month, value: -1, to: today){
            startDate = initial
        }
        if let final = calendar.date(byAdding: .day, value: -1, to: today){
            endDate = final
        }
    }

}
