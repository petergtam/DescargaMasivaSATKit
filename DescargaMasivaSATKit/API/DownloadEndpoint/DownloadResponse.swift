//
//  DownloadResponse.swift
//  DescargaMasivaSATKit
//
//  Created by Pedro Ivan Salas Peña on 09/09/25.
//

import Foundation

/// A type to store the response of the Download SOAP API
public struct DownloadResponse: Codable {
    public var result: DownloadResult
    public var contents: [String]?
}

/// A type with the result information from the Download SOAP API
public struct DownloadResult: Codable {
    public var CodEstatus: Int
    public var Mensaje: String
}
