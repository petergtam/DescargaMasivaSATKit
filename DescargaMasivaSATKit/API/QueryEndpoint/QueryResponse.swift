//
//  QueryResponse.swift
//  DescargaMasivaSATKit
//
//  Created by Pedro Ivan Salas Peña on 09/09/25.
//

import Foundation

/// A type to store the response of the Query SOAP API
public struct QueryResponse: Codable {
    public var result: QueryResult
}

/// A type with the result information from the Query SOAP API
public struct QueryResult: Codable {
    public var CodEstatus: Int
    public var IdSolicitud: String?
    public var Mensaje: String
    public var RfcSolicitante: String?
}
