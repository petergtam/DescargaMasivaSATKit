//
//  InvoiceParams.swift
//  DescargaMasivaKit
//
//  Created by Pedro Ivan Salas Peña on 02/09/25.
//

import Foundation

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

public enum EndPoint: String, CaseIterable, Identifiable {
    case facturas
    case retenciones

    public var id: String {
        rawValue
    }
}

public struct InvoiceParams {
    public var operation: OperationType = .emitidas
    public var startDate: Date
    public var endDate: Date
    public var queryType: QueryType = .cfdi
    public var receiptType: ReceiptType? = nil
    public var receiptStatus: ReceiptStatus? = nil
    public var invoiceId: String = ""
    public var endPoint: EndPoint = .facturas

    public var isRetention: Bool {
        endPoint == .retenciones
    }

    public init() {
        let calendar = Calendar.current
        let today = Date()
        startDate = today
        endDate = today
        if let final = calendar.date(byAdding: .month, value: -1, to: today){
            startDate = final
        }
        if let initial = calendar.date(byAdding: .month, value: -1, to: today){
            endDate = initial
        }
    }

}
