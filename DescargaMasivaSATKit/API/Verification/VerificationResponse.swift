//
//  VerificationResponse.swift
//  DescargaMasivaSATKit
//
//  Created by Pedro Ivan Salas Peña on 09/09/25.
//

import Foundation

/// A type to store the response of the Verification SOAP API
public struct VerificationResponse: Codable {
    public var result: VerificationResult
    public var contents: [String]?
}

/// A type with the result information from the Verification SOAP API
public struct VerificationResult: Codable {
    public var CodEstatus: Int
    public var CodigoEstadoSolicitud: Int?
    public var EstadoSolicitud: Int
    public var IdsPaquetes: [String]?
    public var Mensaje: String
    public var NumeroCFDIs: Int
}
